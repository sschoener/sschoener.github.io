---
layout: post
title: A sort of sorts - parallel sorting with sample sort
excerpt: 
tags: [programming]
---

At work, I recently had the pleasure of looking into the performance of our sorting code. The original goal was to speed up a specific sorting problem, but I ended up writing a new generic parallel comparison-based sort as one of the optimizations. Since Unity has its own job systems with a few idiosyncracies, it made sense to write a new sort instead of using a parallel version of `std::sort` (I'm also making a few more assumptions than `std::sort`).

I'd like to discuss what I did before writing this new sort and then discuss the implementation in some detail.

## Do you really need to implement a new sort?
When you have a very specific sorting problem that you need to get solved faster, the first step should definitely *not* be to try to implement a generic parallel sorting algorithm. Far from it. Solving a specific problem will be at most as hard as solving the generic case, so by going to the generic case you're almost guaranteed to make things harder for yourself.

What can you do instead? Here are some ideas:
 * Have you looked at the specific case in which your sort is slow? Is that the common case? A special case? What is the distribution of the data? A helpful way to get a feeling for the distribution is to dump out some data at runtime and then visualize it. For sorting specifically, I ended up looking at which index each element from the input ends up at, e.g. the first item might end up at index 15 so you'd record the tuple `0, 15` etc. and then plot it for all items. Are there any patterns you could exploit?
 * Does the sorting happen repeatedly (e.g. every frame)? Does the data change inbetween or can you skip the sorting? Can you incrementally insert new items instead of resorting everything?
 * Where does the data come from? If you control the data source, can you generate the data pre-sorted?
 * If your sort is comparison-based: Have you profiled it carefully and tried to optimize the comparison function? Can you maybe get rid of the comparison function by encoding the relevant data into an integer (a *sort key*) and sort that instead? Integer sorting can be done very efficiently with radix sort.
 * Do you need a specific sort, or just *any* canonical order of elements? If the latter is the case, you could look at using a generalized radix sort (be careful with padding bits in structs!).

This list is non exhaustive. I actually already got a nice 1.6x speed-up in my case by just reorganizing some data for the comparison function (which took an hour to implement and some more to test - compared to almost a week to create a parallel sort and validate it across different platforms).

## Parallel sorting
After all of the above, I concluded that one of my best shots at optimizing this further actually was to parallelize the sorting. I am happy with the following constraints:
 - the algorithm does not have to be in-place,
 - it will still be comparison-based,
 - it only needs to work on ranges given by pairs of pointers (honestly, when did you last have to sort anything but an array?),
 - it does not need to support move-only types (in a C++ sense).
On that last point in particular, note that there is no such thing as a byte that you cannot copy. If you deal with move-only types, that is a self-imposed pain and entirely your fault. I'd suggest not doing it :)

I ended up implementing an algorithm called *Sample Sort*, but that wasn't actually my starting point. Before we get to sample sort, let me introduce two other ways to implement parallel sorting that I have tried:
 * Parallel quicksort. Quicksort recursively splits the problem into two independent sub-problems. Basically, whenever you recurse you can give one part of the array to another thread to sort. This has two downsides: First, there is a significant period in the beginning of the sort where you are only using a single thread. The difficult part about quicksort is splitting the data at a pivot, and before you can parallelize any work you have to do this splitting at least once. It takes even more time before you can use *all* threads on your machine. Second, this approach requires non-trivial communication between threads. This has some overhead and essentially comes down to a multiple-producer-multiple-consumer setup with a shared data structure for communication. The upside of parallel quicksort is that it is rather simple to implement and in-place, modulo the data structure for inter-thread communication (which you could forgo entirely at the cost of load balancing).
 * Parallel mergesort. More precisely, I have tried a version I dubbed *segment sort* that was used in another part of the code base. The idea of segment sort is to first split the input into *segments* (of a fixed size, or one per thread) and then sort these segments in parallel. Then you merge all segments by repeatedly picking the minimum item from the segments. This approach is somewhat complementary to quicksort: You get to use all your threads at the beginning of the execution but have a long tail where you are only using a single thread for the merging.

I bring these two up because I used ideas from both for my sample sort implementation. Sample sort is best understood as a sort-of `n`-way quicksort: Quicksort splits the input array into 2 *buckets* (containing the elements smaller than the pivot and those bigger than the pivot). These two buckets can be independently sorted in parallel and there is nothing to be done to join them together - you merely need to concatenate them. Sample sort aims to do the same thing, but with `n` buckets and without recursing (because you can sort the buckets in serial and that's a solved problem).

As with quicksort, the interesting part of the implementation is `how do elements efficiently get into the right bucket in the first place?` - after that you can use your favorite serial sorting algorithm to sort the buckets. Typical quicksort implementations put all of their intelligent thoughts into pivot selection and splitting. A good pivot ensures that the buckets are both of roughly equal size. The same is true for sample sort: Ideally, all of the buckets are of equal size, because we want to have each thread sort one bucket.

Sample sort, as the name implies, solves the pivot selection problem by _sampling_ elements from the input data to be sorted. If you have `n` threads, you want `n` buckets and hence need `n-1` pivot elements between them. Ideally, you'd select the `n-1` elements that split the input exactly into `n` equally sized buckets, but that's hard to do without first sorting the entire input. Instead, we can randomly select `n * k` many elements from the input (where `k` is some constant of your choosing, called the _oversampling factor_). This sample can be assumed to be generally representative of the full input but is much smaller. We can hence quickly sort those few elements we sampled and select pivot elements from them. They should be a good estimate for the best splitting points of the input data itself.

This yields the following algorithm for sample sort:
1. Randomly sample `n * k` many elements from the input.
2. Sort the samples and select the `k`-th, `2*k`-th etc. elements as pivots.
3. _Somehow_ split the input data up into the buckets defined by these pivots (see below).
4. Sort the buckets in parallel.

The splitting step is notoriously annoying to implement. There is an example [on wikipedia](https://en.wikipedia.org/wiki/Samplesort) which like so many places considers the toy example of just sorting integers (booo!). I ended up using a conceptually simple approach to splitting that uses additional memory. It stemmed from the observation that segment sort was suprisingly fast at sorting the segments. So here is how I implemented the splitting:

1. Split the input into segments of a fixed size (or one segment per thread).
2. Sort the segments in parallel.
3. Then, in parallel, go through each segment and figure out the bucket borders in each segment using a linear scan. This is simple because the segment is sorted and we have a sorted array of the pivots as well. Note down the number of elements per bucket in each segment.
4. Sum up the number of elements per bucket across segments. Allocate a buffer of the size of the input. Compute a prefix sum over the number of elements per bucket to get the bucket indices in that buffer.
5. In parallel for each bucket, copy the elements for that bucket from each segment into the bucket.

The downside of this approach is that you need more memory: You allocate a copy of the input buffer, plus `numBuckets * numSegments * sizeof(int)` many bytes for computing the bucket sizes. This also means that you need to copy the sorted buckets back into the original array.

Usually, at this point I would present you with a bunch of benchmarks - but I'm writing this with my new born daughter on my laps and priorities are shifting rapidly :) Instead, have some closing thoughts:
 * In my testing, this algorithm handily beats all parallel variants of `std::sort` on MSVC from VS2019. Similarly, it blows parallel quicksort and segment sort out of the water.
 * In my testing, this algorithm scales very nicely even to high number of threads. You however probably want to limit the number of threads and buckets using a minimum bucket size.
 * Is this optimal? Surely not. But it is a good starting point for any parallel sorting adventures.
 * I have tried out merging the bucket contents from the various segments (using a fixed sized heap) instead of copying them to the bucket and then sorting them. This turned out to be much slower, presumably because with many segments you end up jumping around in memory a lot to do this merging. However, it still feels like there should be an efficient way to use this presorting.