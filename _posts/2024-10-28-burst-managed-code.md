---
layout: post
title: Unity Burst - Interacting with managed code
excerpt:
tags: [Unity]
---

_Hey! You can find me on [Mastodon](https://mastodon.gamedev.place/@sschoener) and [Bluesky](https://bsky.app/profile/sschoener.bsky.social)!_

In the context of Unity, Burst often provides huge speed-ups compared to Mono at the cost of placing more restrictions on the code you can actually write. Burst has a leg up on Mono because Burst actually makes a good effort to optimize your code whereas Mono is more about getting the code running in the first place.

You can often get good runtime CPU performance wins by moving your code to Burst, assuming that you are (a) happy to eat the compilation cost in the editor and (b) you can move your code to Burst in the first place. Burst generally can't touch anything that is "managed", i.e. anything of `class` type, which unfortunately still excludes large parts of Unity's API surface. Sometimes single pieces of managed data can stop you from using Burst for entire systems, and this is the case I want to discuss here. The goal is to pipe some managed data into some managed leaf function without having to rewrite the entire system.

My suggestions here apply when you need to cover the last 10% between "managed" and "fully unmanaged." I am not suggesting that using these approaches you can just convert everything blindly. I have done some checking that these aren't performance footguns, and these techniques are used in Unity's code itself as well.

## Referencing Unity objects

If you need to store a reference to a `UnityEngine.Object` derived type, you can consider using an instance ID instead. This is relatively situational, but assuming you have a reference to the object, you can retrieve its instance id using `int id = obj.GetInstanceID();` to retrieve an unmanaged handle to the object, and then use `UnityEngine.Resources.InstanceIDToObject` ([Unity docs](https://docs.unity3d.com/ScriptReference/Resources.InstanceIDToObject.html)) to get the object again. There is also a [batched version](https://docs.unity3d.com/ScriptReference/Resources.InstanceIDToObjectList.html) of that function.

There are some subtleties here depending on whether the object you refer to is already loaded into memory, but for a lot of cases (e.g. objects you created in a scene) that does not matter. You should also make sure that something holds a regular reference to the object you use this with: The editor for example streams out assets that are not in use anymore. So either keep them visibly alive, or check that the result you get from the `InstanceIDToObject` is not null.

This pattern is implemented in Unity's Entities package. You can use the `UnityObjectRef` for this ([docs](https://docs.unity3d.com/Packages/com.unity.entities@1.3/api/Unity.Entities.UnityObjectRef-1.html)). The upside of this type is that it is fully supported for serializaing subscenes and stops the editor from unloading objects.

## Referencing arbitrary managed data

More generally, you can retrieve an unmanaged handle to any managed piece of data by using the `GCHandle` type ([MSDN docs](https://learn.microsoft.com/en-us/dotnet/api/system.runtime.interopservices.gchandle.alloc?view=netstandard-2.0)). The `GCHandle` will ensure that whatever you refer to is kept alive and not Garbage collected, and it is an unmanaged struct. You need to manually free it because otherwise you leak memory (and probably incur some overhead for whatever is managing GC handles). You can use this to pass managed data around:

```csharp
GCHandle unmanagedHandle = GCHandle.Alloc(myObject);

// ...

// use object
MyClassType obj = (MyClassType)unmanagedHandle.Target;

// ...

// free handle again so the object isn't kept alive indefinitely
unmanagedHandle.Free();
```

## Calling managed methods

Passing managed data around is especially useful when there is some leaf function somewhere that is managed and hard to extract. How would we call this function from Burst? The goal is to merely call this function from Burst at runtime, but it will _not_ be compiled by Burst.

Conceptually, the idea is quite simple: Burst is very happy to call function pointers, so let's get a function pointer to a managed function and call it. We can get a function pointer via a delegate object, but then also have to ensure that the delegate object is not GC'd. Then we need to put the function pointer somewhere where Burst can see it, e.g. into a `SharedStatic`.

All of this may sound cursed, but is used within the Entities package, for example (look for the `GenerateBurstMonoInterop` attribute). It is also not a "get out of jail free" card: Burst fundamentally does not support exception handling, for example, so when you call a managed function and it ends up throwing, well, all bets are off.

In practice, this is what this looks like:

```csharp
using Burst;
using System;

static class ManagedStuff
{
    // Keeps track of whether we already have initialized the static data here.
    public static bool _isInitialized = false;

    // The delegate type representing the managed code we want to call.
    public delegate void _dlg_YourManagedCode();

    // A reference to the delegate object we will create. Having this here will prevent it from getting GC'd while
    // we try to call it.
    public static object _gcDefeat_YourMangedCode;

    // Add a new type to index the Burst shared static
    struct TagType_YourManagedCode {};
    public static readonly SharedStatic<IntPtr> _bfp_YourManagedCode = SharedStatic<IntPtr>.GetOrCreate<TagType_YourManagedCode>();

    public static void Init()
    {
        if (_isInitialized) {
            return;
        }

        // Construct the delegate object, keep a reference alive, and get a function pointer.
        _dlg_YourManagedCode delegateObj = func_YourManagedCode;
        _gcDefeat_YourMangedCode = delegateObj;
        _bfp_YourManagedCode.Data = System.Runtime.InteropServices.Marshal.GetFunctionPointerForDelegate(delegateObj);

        _isInitialized = true;
    }

    // This is your managed code that will be called from unmanaged code. It needs this MonoPInvokeCallback attribute
    // to indicate that it will be called from unmanaged code. This is required for IL2CPP.
    [AOT.MonoPInvokeCallback(typeof(_dlg_YourManagedCode))]
    private static void func_YourManagedCode()
    {
        // create something that is most definitely managed
        object garbage = new object();
    }

    // This is how you invoke your managed code from Burst.
    public static void YourManagedCodeFromBurst()
    {
        var fp = new FunctionPointer<_dlg_YourManagedCode>(_bfp_YourManagedCode.Data);
        fp.Invoke();
    }
}
```

To use this, make sure to call `ManagedStuff.Init` and then call `ManagedStuff.YourManagedCodeFromBurst` from Burst to invoke the managed function from Burst. You can of course pass through all the arguments you need, e.g. a `GCHandle`.

The aforementioned attribute in Entities is an internal mechanism to generate the above code automatically. That codegen is a little bit cleverer still: It detects whether `YourManagedCodeFromBurst` is called from Mono, and if it is, then we just call the function directly instead of going through the function pointer. You can check whether you are running in Burst using this construct:

```csharp
// If this is called from Burst, it doesn't do anything. It's just stripped out.
[BurstDiscard]
private static void CheckIsRunningBurst(ref bool isRunningBurst)
{
    isRunningBurst = false;
}

private static bool IsRunningBurst()
{
    bool result = true;
    CheckIsRunningBurst(ref result);
    return result;
}
```

Next time we are going to look at taking things much further still and "unmanage" a whole bunch of Unity things in Unity 6.
