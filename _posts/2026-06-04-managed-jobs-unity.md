---
layout: post
title: Managed jobs in Unity
excerpt:
tags: []
---

In Unity's job system, you write jobs as structs like this:

```csharp
struct MyJob : IJob {
    public void Execute() {
        // your code here
    }
}
```

One of the restrictions of Unity's job system is that these job structs must be entirely unmanaged, meaning that you many not put any managed data on such structs (e.g. no fields of class type). This is unfortunate, because sometimes you really want to have access to manageed data in a job.

There are good reasons *not* to have access to managed data in jobs: Unity's job debugger cannot reason about what data you might access when you go through a managed object. It is hence entirely on you to ensure that there are no data races.

There is an escape hatch to get managed data into a job: `GCHandle`. A `GCHandle` is an unmanaged struct that contains a reference to arbitrary managed data (in a way that the garbage collector is aware of it). You can use it like this:

```csharp
struct MyJob : IJob {
    public GCHandle MyHandle;
    public void Execute() {
        MyClassType obj = (MyClassType)MyHandle.Target;
    }
}
```
This obviously only works when `MyJob` does not have the `[BurstCompile]` attribute on it, because otherwise Burst will complain because it cannot compile code that references managed data like this.

To schedule such a job, you have to first allocate a `GCHandle` and later free it (when you no longer need it):
```csharp
GCHandle unmanagedHandle = GCHandle.Alloc(myObject);

// schedule job and wait for the job to finish

// free handle again so the object isn't kept alive indefinitely
unmanagedHandle.Free();
```

Some words of caution:
 * I would not suggest that you use this excessively. Allocating a `GCHandle` is presumably not free, and most runtimes likely assume that you have a few `GCHandles`, not millions.
 * Do not get into the habit of writing regular GC-allocation-happy code in jobs. Allocating GC-visible memory on Unity's runtimes takes a lock and doing this on multiple threads in parallel will just lead to contention. (Ideally you don't allocate at all, obviously.)
 * Use this when you absolutely need to, or while you are migrating to a completely unmanaged setup.

If you want to learn more about the twilight zone between managed and unmanaged code in Unity, I have written about that before [here]({% post_url 2024-10-28-burst-managed-code %}) and [here]({% post_url 2024-11-02-unmanaging-unity %}).