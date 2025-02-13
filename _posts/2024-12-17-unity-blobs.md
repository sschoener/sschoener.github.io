---
layout: post
title: Unity's blob assets break your debugger
tags: [unity]
---



Wow, another post just one day after the last one? Well, I have things to say today, apparently.

Unity's Entities package has a concept of so called "blob assets" ([documentation](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/blob-assets-concept.html)). Blob assets are read-only and relocatable by memcpy. You may thus only store blittable value-types in there, which requires extra care when you want to store arrays, strings, or generally references to other pieces of data. These references in blobs are implemented as offsets-to-this, as relative pointers. You need to use relative pointers if you want things to be relocatable by memcpy. In code, it looks like this:

```csharp
public unsafe struct BlobArray<T> where T : struct
{
    internal int m_OffsetPtr;
    internal int m_Length;

    public void* GetUnsafePtr()
    {
        // for an unallocated array this will return an invalid pointer which is ok since it
        // should never be accessed as Length will be 0
        fixed (int* thisPtr = &m_OffsetPtr)
        {
            return (byte*) thisPtr + m_OffsetPtr;
        }
    }
}
```

A nasty problem then comes up when you copy part of a blob asset: the address of the `BlobArray` changes, so `thisPtr + m_OffsetPtr` changes, but the data that it *should* be pointing to is still in the old place. Now you have a pointer to essentially random memory. This copying can happen all of the time, e.g. when you refer to any `BlobArray` or `BlobString` or `BlobPtr` by value instead of by reference. Unity has a custom Roslyn analyzer to detect that case and stop you from doing that.

However, not all code that is executing is _your_ code. During a hackweek at Unity some years ago I decided to not hack on something new (because there were already so many things that didn't work about the things we already shipped) but to fix things instead, and one of these things was that you could not effectively debug blob assets: they would not show anything meaningful in the debugger. What I realized is that C# debuggers freely copy structs around: structs are value-types, they are supposed to be copyable, and there is no such thing as "non-copyable structs" in C#. As such, C# debuggers completely mangle anything with relative pointers and make it impossible to get useful information out of blobs. That's an understatement, because "debugger shows non-sense values" is the happy path: the not-so-happy path is the debugger (or Unity) crashing while inspecting data, teaching you to distrust your debugger and only use `printf` debugging.

Back then I "solved" this by adding custom `DebuggerDisplay` attributes to `BlobArray` and friends, so that the debugger display tells you to not look at the sub-parts of the blob but only inspect the top-most `BlobAssetReference`, which got a custom debugger proxy type that resolved all of these issues. It's a terrible workflow, because now you need to always figure out where that particular reference to a `BlobArray` you want to inspect comes from, but at least it doesn't crash. Unity's documentation has [a paragraph](https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/blob-assets-create.html#debugging-blob-asset-contents) about this problem, which contains what look like "famous last words" about copying blob strings:

> this is easy to avoid in your own code

For all I know, _I_ probably wrote those words: I did not put blob assets into C#, but I am surely willing to take my fair share of blame for them, as with anything else Entities. Years ago, I certainly considered blob assets them one of the less-broken parts of Unity. And then it turned out to be "not so easy" to avoid copying in your own code, and it required a custom compiler analysis pass to raise the problem automatically, everywhere.

Unfortunately, not displaying `BlobString` and `BlobArray` is not a solution. Not because "it is a bad workflow", but because it is insufficient. When you create blob assets, you do so by using your own structs, which you then fill in using a `BlobBuilder`. Imagine something like this:
```csharp
struct GameItem
{
  BlobString m_Name;
  BlobString m_Namespace;

  public override string ToString() => FullName;
  // NB The "ToString" here is not redundant
  public string FullName => $"{m_Namespace.ToString()}.{m_Name.ToString()}";
}
```

This thing is a landmine that I have found the other day. Do you know what a C# debugger does when you don't have a custom `DebuggerDisplay`? It calls `ToString()`, sometimes, which in this case is akin to playing russian roulette, because somewhere in the depth of the debugger that struct was copied. Debuggers will also often evaluate properties and display their values automatically, which in this case is just as unadvisable.

![Debugger view](/assets/img/2024-12-17-unity-blobs/debugger-view.png)

I say that it calls `ToString()` only "sometimes" because I noticed that Rider's debugger in particular will make educated guesses about what to show. For example, for this example to run into problems you apparently need to have two `BlobString` members, not just one. This makes the problem even more obtuse.

Rider has a setting to disable implicit evaluation and function calls (`Settings -> Debugger -> Allow property evaluations and other implicit function calls`) so that you no longer crash automatically, but you can now crash "on-demand" when you inadvisably click on something to view its value. (To be clear, I place no blame on Rider, at all.)

![Debugger settings](/assets/img/2024-12-17-unity-blobs/debugger-settings.png)

I am not opposed to features that require care to be used correctly. I am probably more open to them than most other people. However, "central type in your ecosystem is going to make your debugger crash if _someone_ was careless _somewhere_" is something else, because the debugger is just about the only thing that **must must must** be reliable.

Unity's selling point is around making things easy and safe, which is why it offers C# scripting (and memory tracking and warnings and safety systems and a static race condition detection system and ...). Blob assets are useful. I don't dispute that. I am however disputing that it is a good idea to put them into an ecosystem (C#) that definitely does not support them. There is no point in pretending that things are all safe and nice if in reality _they are not_, and you would be better off writing C, or another language that at least has imprinted on its users to be careful everywhere, and their debuggers assume the worst.

Blob assets in C# were an experiment, and it failed.

You may argue that this is a debugger problem. But is it? Changing the rules until a tool does not work anymore is not the tool's fault. Changing the debugger is certainly a way to fix this problem, but unless you are then going to tell me that your next step is to _actually fix the debugger_, please don't tell me that this is a debugger problem. The lesson here is "unless you have a proven history of owning and fixing the entire stack, maybe do not attempt to change the semantics of the language."

