---
layout: post
title: How to speed up random memory accesses
excerpt:
tags: []
---

At some point when optimizing software, you are left with a soup of pointers that you just have to dereference, even though you know that you are going to suffer a cache miss for every single read. Common knowledge suggests that you just should not read from random pointers in the first place and instead go over data linearly, then that all the data is prefetched for you. Unfortunately, "memory is only linear in one direction" as my friend Peter Andreasen is fond of saying, so you will at some point still need to deal with random access.

How do you make random memory access faster?

Let's make this more concrete. This is the function we are trying to optimize:
```c
double DoThing(int** ptrs) {
    double total = 0;
    for (int i = 0; i < 1024; i++) {
        int x = *ptrs[i];
        total += sin(x);
    }
}
```
The call to `sin` here is just a proxy for your real sins, the more interesting, expensive work: in the real world, we don't read an `int`, and we don't call `sin`. We instead read a small struct and then process it with some branchy code.

If you profile this code, you will likely find that the majority of the time in this case is *not* spend on `sin`, but on fetching `x` from memory, because the addressed pointed to by `ptrs[i]` is most likely not in cache. (If you benchmark this code a bunch of time, you of course need to make sure that you do not accidentally have all the data cached after the first run.)

If you are like me, your first thought is going to be "oh, let's use a prefetch intrinsic!" The idea is to prefetch the value `ptr[i + 10]` while you are still running iteration `i`, so that by the time you get to `i + 10` you do not need to wait for the result of the load from memory.

The main issue with this in practice is that you do not know when *exactly* you should start prefetching. Should you do that 10 iterations before? 20? 5? Realistically, the only way I have found to arrive at a reasonable number here is experimentation. And then someone changes the code (or codegen changes, or you run it on a different machine) and you can start from scratch. This can be very brittle! In my case, I get the best results by prefetching about 16 iterations in advance for this code. Proper prefetching makes this code 2x faster.

Here is a neat alternative version that makes perfect sense in retrospect but took me a long while to come up with (and that probably has a name because generations of programmers have likely found it before me):
```c
double DoThing(int** ptrs) {
    double total = 0;
    int cache[1024];
    for (int i = 0; i < 1024; i++)
        cache[i] = *ptrs[i];
    for (int i = 0; i < 1024; i++) {
        int x = cache[i];
        total += sin(x);
    }
}
```
On my machine, it is just ever so slightly slower than what I get with prefetching. This might be counter-intuitive: are we not doing more work here? Yes, we are! But it all makes sense, if you think about it briefly. In the original version we were doing this: Execute one load, then execute a lot of instructions to compute `sin`. We likely don't benefit much from instruction level parallelism, because `sin` depends on the value we load, and `sin` is so much work that the processor can't start on the next load yet. So all work happens completely serially.

In the new version however, the first loop is very short and we end up issuing many loads in parallel: they are all independent and there aren't a thousand instructions between the loads, so they can execute in parallel. The loads still miss cache, but we can now wait for multiple loads at a time.

Some further notes:
 * The actual savings depend on the number of pointers you read from. I get good savings from roughly 100 pointers and upwards (which is true for prefetching as well).
 * This also works when you don't know the number of elements to process. I have even found it worthwhile to allocate the cache dynamically, assuming you have a very cheap allocator (e.g. bump allocator).
 * It's still a good idea to measure. While you don't have to get the number of iterations to start a prefetch right anymore, you still need to convince yourself that your original loop does not already issue multiple loads in parallel. For example, replace `total += sin(x)` with the much simpler `total += x` and note that the local cache then doesn't help anymore at all.

On a personal note, this experiment has been quite enlightening. When designing an API, I have learned to prefer batched APIs: Where there is one, there are many. Yet in some cases, you must eventually depart from doing everything in batches: not everything just fits into SIMD instructions, so you will have to loop over your batch at some point. That point is ideally chosen so you can make use of instruction level parallelism, and in the case of loads it might just be that you need to keep the batch all the way to single line loops.

You can find Windows x64 code for some of my experiments [on GitHub](https://github.com/sschoener/random-access-experiments).