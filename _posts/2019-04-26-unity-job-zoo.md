---
layout: post
title: Job Types in the Unity Job System
excerpt: 
tags: [programming, unity, c#]
---

* TOC
{:toc}

---

I found it quite hard to find all the information I needed to get started with using the various kinds of jobs in Unity in one place, so this is my attempt to compile the necessary information for Unity 2019.1, the `jobs` package `preview.10 - 0.0.7`, and the `collections` package `preview.17 - 0.0.9`. I will hopefully have a short write-up about the ECS-specific jobs soon as well.

I am going to assume that you have already read the [official documentation](https://docs.unity3d.com/Manual/JobSystem.html). It's quite good at explaining all the concepts required (safety checking, race conditions, dependencies) and I am trying to add value beyond that. Also, here is a special shout-out to their [troubleshooting section](https://docs.unity3d.com/Manual/JobSystemTroubleshooting.html) which is worth reading even if you already feel comfortable with everything else and to the [documentation](https://docs.unity3d.com/Packages/com.unity.jobs@0.0/manual/scheduling_a_job_from_a_job.html) of the `jobs` package that answers some more questions. For more of a guided tour you can rely on this [nice guide](https://jacksondunstan.com/articles/4796) by Jackson Dunstan.

# Job Types
These are the kinds of jobs available:
 * `IJob` ([documentation](https://docs.unity3d.com/ScriptReference/Unity.Jobs.IJob.html)) - your standard job,
 * `IJobParallelFor` ([documentation](https://docs.unity3d.com/Manual/JobSystemParallelForJobs.html)) - a job that uniformly applies a kernel to each element in an array,
 * `IJobParallelForTransform` ([documentation](https://docs.unity3d.com/ScriptReference/Jobs.IJobParallelForTransform.html)) - a job that uniformly applies a kernel to each transform in an array
 * `IJobParallelForBatch` (`jobs` package) - a job that uniformly applies a kernel to consecutive slices of an array,
 * `IJobParallelForFilter` (`jobs` package, [documentation](https://docs.unity3d.com/Packages/com.unity.jobs@0.0/api/Unity.Jobs.IJobParallelForFilter.html)) - a job that filters a list of indices,
 * `IJobNativeMultiHashMapVisitKeyValue<TKey, TValue>` ([documentation](https://docs.unity3d.com/Packages/com.unity.collections@0.0/api/Unity.Collections.IJobNativeMultiHashMapVisitKeyValue-2.html)) and `IJobNativeMultiHashMapVisitKeyMutableValue<TKey, TValue>` ([documentation](https://docs.unity3d.com/Packages/com.unity.collections@0.0/api/Unity.Collections.IJobNativeMultiHashMapVisitKeyMutableValue-2.html), `collections` package) -  visits all entries in a multi hash map,
 * `IJobNativeMultiHashMapMergedSharedKeyIndices` ([documentation](https://docs.unity3d.com/Packages/com.unity.collections@0.0/api/Unity.Collections.IJobNativeMultiHashMapMergedSharedKeyIndices.html), `collections` package) - a specialized job for traversing the values of a `NativeMultiHashMap<int, int>`,
 * managed jobs executing arbitrary code - these are easy to implement, see below.

Note that the job types are all given as interfaces that a struct consisting of blittable types (think of types that can be mem-copied) and native containers must implement. Scheduling a job is then handled via an extension method with a name similar to `Schedule(...)`. An important implication of this is that there might be multiple ways to interact with a job type given by multiple methods for scheduling them. This is the main reason for writing this: Collecting all of the important things in one place.

Also note that some of the job types are implemented in pure C# on top of the primitive job types (e.g. the hashtable jobs are implemented as `IJobParallelFor`). This means that you can just get the respective package and look at their implementation to add custom job types (more info available [here](https://docs.unity3d.com/Packages/com.unity.jobs@0.0/manual/custom_job_types.html) and [here](https://jacksondunstan.com/articles/4857)) or understand the existing ones (looking at the tests for them is a good start).

## `IJob`
This is the basic job that just allows you to do whatever you need to do on a single thread. The [Unity documentation](https://docs.unity3d.com/ScriptReference/Unity.Jobs.IJob.html) for this covers pretty much everything. For completeness, here are [the](https://docs.unity3d.com/Manual/JobSystemCreatingJobs.html) [two](https://docs.unity3d.com/Manual/JobSystemSchedulingJobs.html) sections from the general job system documentation that are most important.

## `IJobParallelFor`
This job type is for running the same operation (_kernel_) on many elements, potentially in parallel. Here are the [relevant sections](https://docs.unity3d.com/ScriptReference/Unity.Jobs.IJobParallelFor.html) from the [docs](https://docs.unity3d.com/Manual/JobSystemParallelForJobs.html) and a usage example:
```csharp
[BurstCompile]
struct ParallelAddJob : IJobParallelFor
{
    [DeallocateOnJobCompletion]
    [ReadOnly]
    public NativeArray<int> A;
    [DeallocateOnJobCompletion]
    [ReadOnly]
    public NativeArray<int> B;

    // Usually you would not immediately de-allocate the result array.
    [DeallocateOnJobCompletion]
    [WriteOnly]
    public NativeArray<int> C;
    
    public void Execute(int index)
    {
        // The job safety system actually ensures that this kernel only writes
        // to the index that was passed in for each array used by the job.
        // You can however read from arbitrary positions.
        C[index] = A[index] + B[index];
    }
}

JobHandle CreateParallelAddJob(int n)
{
    var a = new NativeArray<int>(n, Allocator.TempJob);
    var b = new NativeArray<int>(n, Allocator.TempJob);
    var c = new NativeArray<int>(n, Allocator.TempJob);
    var job =  new ParallelAddJob {
        A = a,
        B = b,
        C = c
    };
    // Schedule the job with the length of the array and the size of a batch
    job.Schedule(n, 32);
}
```
What is worth noticing is that the job safety system will prevent you from writing to arbitrary indices from within the job's kernel. This is not explicitly spelled out the documentation, but will trigger a runtime error. You can disable this check using `NativeDisableParallelForRestriction`, see further below.

There is another way to schedule `IJobParallelFor` jobs if you also have the `collections` package, which provides the `NativeList<T>` type (see below for some more thoughts on that type). The `NativeList<T>` type is essentially the same as `List<T>` or `std::vector<T>` and if you want to use one job to fill a list and another one to consume that list, you might not now before hand what the size of that list will be. For this reason, there is another overload for `Schedule` available that takes a list instead of the size of an array. Here is an example that also shows how to use the `AsDeferredJobArray` function of `NativeList<T>`:
```csharp
struct DeferredListJob : IJobParallelFor
{
    // You could also use a NativeList<int> here, but it is slightly slower to access
    // and I am not sure whether and how it interferes with aliasing analysis. 
    [ReadOnly]
    public NativeArray<int> Data;
    [WriteOnly]
    public NativeArray<int> Output;
    public void Execute(int index)
    {
        Assert.AreEqual(Data[index], index);
        Assert.AreEqual(Output.Length, Data.Length);
        // copy the data over so we have something to test for.
        Output[index ] = Data[index];
    }
}

struct ListFiller : IJob 
{
    [WriteOnly]
    public NativeList<int> List;
    public int N;
    public void Execute()
    {
        for (int i = 0; i < N; i++)
            List.Add(i);
    }
}

[Test]
public void DeferredList([Values(0,1,2,3,16,32,1023,1024)] int n)
{
    var list = new NativeList<int>(Allocator.TempJob);
    var testOutput = new NativeArray<int>(n, Allocator.TempJob);
    
    // Create a job that needs data from a list
    var deferredJob = new DeferredListJob{
        // Note that at this point the list is not yet completely filled, so the
        // underlying storage could still be re-allocated. This here is still safe,
        // because the array is only properly set when the list is finished.
        Data = list.AsDeferredJobArray(),
        Output = testOutput
    };

    // Create the job that fills the required list and schedules it.
    var fillerJob = new ListFiller {
        List = list,
        N = n
    }.Schedule();

    // Only now schedule the original job. It's a Parallel-For job, so we need to tell
    // it how many iterations it will need to execute. We want it to run for every item
    // in the list and can pass in the list as a first parameter to indicate that, even
    // if the size of the list still changes until the job starts.
    deferredJob.Schedule(list, 32, fillerJob).Complete();

    // Just to prove that all of this worked, we can check that every item was indeed
    // copied over to the output.
    Assert.AreEqual(n, list.Length);
    for (int i = 0; i < n; i++)
        Assert.AreEqual(list[i], testOutput[i]);

    testOutput.Dispose();
    list.Dispose();
}
```

## `IJobParallelForTransform`
This works similarly to a parallel for job, but also allows you to access transforms. The [documentation](https://docs.unity3d.com/Manual/JobSystemParallelForTransformJobs.html) for this job type is entirely unhelpful, but it is not hard to understand:
```csharp
private JobHandle CreateMoveForwardJob(Transform[] transformData)
{
    // create an transform access array that wraps around the given transforms.
    var transformsAccess = new TransformAccessArray(transformData);
    // you could also manually set up the array here using
    //    transformsAccess[index] = ....
    return new TransformJob {
        DeltaTime = Time.deltaTime
    }.Schedule(transformsAccess);
}

[BurstCompile]
struct MoveForwardJob : IJobParallelForTransform
{
    public float DeltaTime;

    public void Execute(int index, TransformAccess transform)
    {
        // move the given transforms forward in their local coordinate system
        transform.localPosition += transform.localRotation * math.float3(0, 0, 1);
    }
}
```
The additional types involved are documented [here](https://docs.unity3d.com/ScriptReference/Jobs.TransformAccess.html) and [here](https://docs.unity3d.com/ScriptReference/Jobs.TransformAccessArray.html).

## `IJobParallelForBatch`
This one is from the `jobs` package, which unfortunately doesn't contain explicit documentation for this job type. You can get a good idea by just looking at the interface itself or reading the first few paragraphs of the [documentation](https://docs.unity3d.com/Packages/com.unity.jobs@0.0/manual/custom_job_types.html) about custom job types. Here is a usage example:

```csharp
[BurstCompile]
struct ParallelBatchAddJob : IJobParallelForBatch
{
    [DeallocateOnJobCompletion]
    [ReadOnly]
    public NativeArray<int> A;
    [DeallocateOnJobCompletion]
    [ReadOnly]
    public NativeArray<int> B;

    [DeallocateOnJobCompletion]
    [WriteOnly]
    public NativeArray<int> C;

    public void Execute(int startIndex, int count)
    {
        int end = startIndex + count;
        for (int i = startIndex; i < end; i++)
        {
            C[i] = A[i] + B[i];
        }
    }
}

JobHandle CreateParallelBatchAddJob(int n)
{
    var a = new NativeArray<int>(n, Allocator.TempJob);
    var b = new NativeArray<int>(n, Allocator.TempJob);
    var c = new NativeArray<int>(n, Allocator.TempJob);
    var job = new ParallelBatchAddJob {
        A = a,
        B = b,
        C = c
    };
    // The first parameter specifies the total number of indices, the second one the
    // size of a batch. The Execute function specified in the job will be called with
    // a count of that number, usually, unless you are in the last batch.
    job.ScheduleBatch(n, 32);
}
```

## `IJobParallelForFilter`
This is a job type that lets you filter indices in parallel. Its main function has the signature `bool Execute(int index)`, with the understanding that returning `true` means that the indx passes the filter. There are two different ways in which this job type can be scheduled:
 * `ScheduleFilter` - takes a list of integers (the indices that are going to be passed into the filter) and removes all entries that do not pass the filter.
    ```csharp
    struct FilterJob : IJobParallelForFilter
    {
        public bool Execute(int index)
        { 
            return index % 8 == 0;
        }
    }

    [Test]
    void Filter([Values(0, 1, 2, 3, 4, 16, 32, 1023, 1024)] int n) 
    {
        // Create a list to filter and fill it with some numbers
        var list = new NativeList<int>(Allocator.TempJob);
        list.ResizeUninitialized(n);
        for (int i = 0; i < n; i++)
            list[i] = 4 * i;
        
        // schedule the job with the list and the batch size
        new FilterJob().ScheduleFilter(list, 128).Complete();

        // Observe that only the elements that are evenly divisble by 8
        // are still in the list
        Assert.AreEqual((n+1)/2, list.Length);
        for (int i = 0; i < list.Length; i++)
            Assert.AreEqual(list[i], 8 * i);
        list.Dispose();
    }
    ```
 * `ScheduleAppend` - takes a list of integers and an upper limit. It will execute the filter for all integers from 0 up until the limit and add each one that passes the filter to the list.
    ```csharp
    struct AppendJob : IJobParallelForFilter
    {
        public bool Execute(int index)
        { 
            return index % 2 == 0;
        }
    }

    [Test]
    void FilterAppend([Values(0, 1, 2, 3, 4, 16, 32, 1023, 1024)] int n) 
    {
        // Allocate a list to hold all of the results
        var list = new NativeList<int>(Allocator.TempJob);

        // Schedule the job, it will be called with the indices
        //  0, ..., n-1
        // in batches of 32.
        new AppendJob().ScheduleAppend(list, n, 128).Complete();

        // Observe that the list now contains all numbers that passed the filter, i.e.
        // the even numbers.
        Assert.AreEqual(list.Length, (n+1)/2);
        for (int i = 0; i < list.Length; i++)
            Assert.AreEqual(list[i], 2 * i);
        list.Dispose();
    }
    ```
As of writing, this job is not _actually_ run in parallel, but that will probably change some time in the future. 

## `IJobNativeMultiHashMapVisitKeyValue<TKey, TValue>` and `IJobNativeMultiHashMapVisitKeyMutableValue<TKey, TValue>`
This job type is quite straight forward. It allows you to walk a hash map from a job. The scheduling function takes a `NativeMultiHashMap<K,V>` and a batch size.
```csharp
struct HashMapJob : IJobNativeMultiHashMapVisitKeyValue<K, V>
{
    public void ExecuteNext(K key, V value)
    {
        // do what you need to do here
    }
}

struct MutableHashMapJob : IJobNativeMultiHashMapVisitKeyMutableValue<K, V>
{
    public void ExecuteNext(K key, ref V value)
    {
        // do what you need to do here
    }
}
```

## `IJobNativeMultiHashMapMergedSharedKeyIndices` 
This is a quite specialised job that takes `NativeMultiHashMap<int, int>` plus a batch size and visits all values associated to a key, without telling you which key the currently processed values are associated with. It's an efficient way to iterate all the values in said hashmap that might be useful in certain cases. The name is a bit of a misnomer because it does not need to be about indices at all; it could just as well work for `NativeMultiHashMap<int, V>`. The interface looks like this:
```csharp
struct HasMapJob : IJobNativeMultiHashMapMergedSharedKeyIndices
{
    public void ExecuteFirst(int index)
    {
        // This is called for the first value associated to each key. E.g. when you have the values [5,2,4]
        // all associated to the key 1, it will be called with index = 5 once.
    }

    public void ExecuteNext(int firstIndex, int index)
    {
        // This is called for all other values associated to each key. E.g. when you have the values [5,2,4]
        // all associated to the key 1, it will be called with index = 2, 4 and firstIndex = 5.
        // As far as I can tell, there is no guarantee that ExecuteFirst has been called for the
        // specified firstIndex before this function is called.
    }
}
```

## Managed Jobs
Jobs can only contain blittable types and native collections, which means that you cannot just pass arbitrary object to a job. There are however ways to use the job system to execute arbitrary jobs for you (without Burst compilation, of course). [CoffeBrainGames](https://coffeebraingames.wordpress.com/2019/03/17/run-managed-code-in-unitys-job-system/) have a nice write-up on this topic and there is this [helpful thread](https://forum.unity.com/threads/solved-c-job-system-vs-managed-threaded-code.545360/) on the Unity forums.


# Useful Native Containers
The `collections` package contains a few handy data structures for use in jobs. Here is a quick overview:
 * `NativeList<T>` ([documentation](https://docs.unity3d.com/Packages/com.unity.collections@0.0/api/Unity.Collections.NativeList-1.html)) - basically a `std::vector<T>`; is to `NativeArray<T>` what `List<T>` is to `T[]`. You can use this to build up lists via filtering and get some more dynamicism with `IJobParallelFor` (see there). As of the time of writing, this type does not support concurrent writing. 
 * `NativeQueue<T>` ([documentation](https://docs.unity3d.com/Packages/com.unity.collections@0.0/api/Unity.Collections.NativeQueue-1.html)) - a queue for use in jobs. Use the method `ToConcurrent()` on a queue to get an adapter that you can use for concurrent writing. Note that _concurrent writing_ in case of the job system is still only allowed within a single job (but that job might be split across multiple threads). The safety system will still complain if you use the same `NativeQueue<T>.Concurrent` in multiple jobs at once.
 The proper usage in a job looks like this:
   ```csharp
   struct QueueJob : IJobParallelFor 
   {
       [WriteOnly]
       public NativeQueue<T>.Concurrent Queue;
       public void Execute(int index) {}
   }
   ```
 * `NativeHashMap<K,V>` ([documentation](https://docs.unity3d.com/Packages/com.unity.collections@0.0/api/Unity.Collections.NativeHashMap-2.html)) and `NativeMultiHashMap<K,V>` ([documentation](https://docs.unity3d.com/Packages/com.unity.collections@0.0/api/Unity.Collections.NativeMultiHashMap-2.html)) - a hash map for use in jobs. Use the method `ToConcurrent()` on both of the types to get an adapter that you can use for concurrent writing (the same restrictions as for the concurrent queue above apply).
 * `ResizableArray64Byte<T>` ([documentation](https://docs.unity3d.com/Packages/com.unity.collections@0.0/api/Unity.Collections.ResizableArray64Byte-1.html)) - a 64 byte buffer that is stack allocated and allows you to place multiple values of type `T` in it. The `Resizable` part does not mean that it will automatically switch to a heap-allocated array if you try to add more elements than it can hold but merely that it keeps track of how many items you have actually placed in its storage using its `Add` method.

If you want to define your own abstractions, you can find plenty of examples [here](https://github.com/jacksondunstan/NativeCollections) and a nicely written introduction [in the docs](https://docs.unity3d.com/Packages/com.unity.jobs@0.0/manual/custom_job_types.html#custom-nativecontainers).

# Useful Attributes
There are a bunch of useful attributes that you can use in conjunction with jobs. They are all in Unity 2019.1, no packages required, except for the `BurstCompile`/`NoAlias` attributes which require the [Burst package](https://docs.unity3d.com/Packages/com.unity.burst@1.0/manual/index.html). I'm skipping attributes that are only required to implement native containers. You can find those and more information on that [here](https://docs.unity3d.com/ScriptReference/Unity.Collections.LowLevel.Unsafe.NativeContainerAttribute.html).

Useful attributes:
 * `[Unity.Collections.DeallocateOnJobCompletion]` ([documentation](https://docs.unity3d.com/ScriptReference/Unity.Collections.DeallocateOnJobCompletionAttribute.html)). You can apply this to a native containers in a job to deallocate the container once the job is done:
    ```csharp
    struct MyJob : IJob {
        // Will be automatically
        [DeallocateOnJobCompletion]
        public NativeArray<int> Data;
        public void Execute() {}
    }
    ```
 * `[Unity.Collections.NativeDisableParallelForRestriction]` ([documentation](https://docs.unity3d.com/ScriptReference/Unity.Collections.NativeDisableParallelForRestrictionAttribute.html)). You can apply this to a native array to disable some safety cehcks for `IJobParallelFor` and `IJobParallelForBatch`. These will ensure that for *any* array your job is using, you are only writing to the current index (or an index within the batch range for the batched version). You can still read from them.
    ```csharp
    struct MyJob : IJobParallelFor {
        [NativeDisableParallelForRestriction]
        public NativeArray<int> Data;

        public void Execute(int i) {
            // Without the attribute above, we would get a runtime error from the safety checks
            Data[0] = 0;
        }
    }
    ```
 * `[Unity.Collections.ReadOnly]` ([documentation](https://docs.unity3d.com/ScriptReference/Unity.Collections.ReadOnlyAttribute.html)). Use on container fields of a job to communicate to the job safety system that this job is only using this container to read from it (this is actually enforced) and it is hence safe to schedule multiple jobs reading this container at the same time without a dependency.
    ```csharp
    struct MyJob : IJob {
        [ReadOnly]
        public NAtiveArray<int> Data;

        public void Execute() {}
    }
    ```
 * `[Unity.Collections.WriteOnly]` ([documentation](https://docs.unity3d.com/ScriptReference/Unity.Collections.WriteOnlyAttribute.html)). Works the same as the `ReadOnly` version.
 * `[Unity.Collections.LowLevel.Unsafe.NativeDisableContainerSafetyRestriction]` ([documentation](https://docs.unity3d.com/ScriptReference/Unity.Collections.LowLevel.Unsafe.NativeDisableContainerSafetyRestrictionAttribute.html)). Disables the job safety system for a container contained as a field in a job `struct`. For when you absolutely want to manually guarantee that there are no races.
 * `[Unity.Collections.LowLevel.Unsafe.NativeDisableUnsafePtrRestrictionAttribute]` ([documentation](https://docs.unity3d.com/ScriptReference/Unity.Collections.LowLevel.Unsafe.NativeDisableUnsafePtrRestrictionAttribute.html)). Use on unsafe pointer fields of a job `struct` to avoid the job safety system emitting a warning for them. It cannot guarantee anything for raw pointers, so they are disallowed by default. This attribute lifts that restriction.
 * `[Unity.Collections.LowLevel.Unsafe.NativeSetClassTypeToNullOnScheduleAttribute]` ([documentation](https://docs.unity3d.com/ScriptReference/Unity.Collections.LowLevel.Unsafe.NativeSetClassTypeToNullOnScheduleAttribute.html)). Use on class-type fields to instruct the job system to set that field to `null` before scheduling the job.
 * `[Unity.Collections.LowLevel.Unsafe.NativeSetThreadIndexAttribute]` ([documentation](https://docs.unity3d.com/ScriptReference/Unity.Collections.LowLevel.Unsafe.NativeSetThreadIndexAttribute.html)). This attribute allows you to inject the index of the thread that is executing in a job. This is sometimes useful when dealing with data structures that allow concurrent write access. Usage:
    ```csharp
    struct MyJob : IJobParallelFor {

        [NativeSetThreadIndex]
        public int ThreadIndex;

        public void Execute(int i) {
            Debug.Log("Executing on Thread " + ThreadIndex);
        }
    }
    ```
 * `[Unity.Burst.BurstCompile]` ([documentation](https://docs.unity3d.com/Packages/com.unity.burst@1.0/api/Unity.Burst.BurstCompileAttribute.html)). Use it on a job of any kind to request compilation via the Burst compiler. Note that the [Burst documentation](https://docs.unity3d.com/Packages/com.unity.burst@1.0/manual/index.html) clearly tells you what you can and can not do within such a job's kernel. Did you know that you can use `System.Threading.Interlocked` with Burst? No? Read [the docs](https://docs.unity3d.com/Packages/com.unity.burst@1.0/manual/index.html#cnet-language-support), they are well written and helpful. Also, take note that this attribute takes parameters that allow you to tweak the way floating point numbers are treated and whether compilation will be blocking. [The docs, read them.](https://docs.unity3d.com/Packages/com.unity.burst@1.0/api/Unity.Burst.BurstCompileAttribute.html). Usage:
    ```csharp
    // Will try to Burst-compile this job when enabled in the editor
    [BurstCompile]
    struct MyJob : IJob {
        public void Execute() {}
    }
    ```
 * `[Unity.Burst.BurstDiscard]` ([documentation](https://docs.unity3d.com/ScriptReference/Unity.Burst.BurstDiscardAttribute.html)). Tag a method in a job with this attribute to just completely discard it when the job is compiled with Burst (helpful for logging when you are want to investigate your job). You obviously can't use this when you depend on some value passed out of that method. Usage:
    ```csharp
    [BurstCompile]
    struct MyJob : IJob {
        [BurstDiscard]
        private void DebugInfo() {
            // this operation is not supported by Burst:
            Debug.Log("Helpful debug info from MyJob");
        }

        public void Execute() {
            // this call will be dropped!
            DebugInfo();
        }
    }
    ```
 * `[Unity.Burst.NoAlias]` ([documentation](https://docs.unity3d.com/Packages/com.unity.burst@1.0/api/Unity.Burst.NoAliasAttribute.html)). This is more bonus-content than actually helpful, since you can only apply this to parameters of a function. If you take a close look at the Burst package, you might have noticed that Burst has a non-exposed interface for compiling delegates; it probably ties into that :)
