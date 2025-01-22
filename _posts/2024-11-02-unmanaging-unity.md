---
layout: post
title: Unmanaging Unity
excerpt:
tags: [Unity]
---

_Hey! You can find me on [Mastodon](https://mastodon.gamedev.place/@sschoener) and [Bluesky](https://bsky.app/profile/sschoener.bsky.social)!_

Unity has recently undergone some drastic management changes that affect the entire technology stack, and I have some ideas for how to best take advantage of that. The management in question here is of course _memory management_, and by recent changes I mean that Unity 6 included some low profile changes in how native code interacts with managed memory (for the most part).

Naively, you might expect that Unity has always been a native core with a nice C-like interface that C# binds against, but that is not actually the case. For the longest time, Unity has been using a mechanism known as "internal calls" where some C# functions are "just" implemented as native code. This is an interesting inversion, where the native code suddenly pokes at managed memory instead of the other way around. As far as I can tell, Unity 6 changed that in almost all places, but not quite everywhere yet. Moving towards CoreCLR probably requires such a change in full.

This is great news, because it means that Unity now behaves more like "isolated core with C# wrappers around it" -- which means we can now use the core directly without going through anything managed in a lot of cases. What this allows you to do:

- You can call functions that take `T[]` and instead give them a `Span<T>`, assuming `T` is blittable
- You can call functions that return `T[]` and avoid copies and managed memory, assuming `T` is blittable
- You can sidestep the managed data and code required to call into most of Unity's core and do it via unmanaged code, which makes things Burst compatible.

In short, my goal here is to look at how much of Unity's API I can operate on while avoiding managed objects. This would help make more code Burst-compatible, which would hopefully improve performance.

Where can one learn such powers? Oh, you've come to just the right place. My goal here is to outline the general approach, give some examples, and just generally point in the right direction. There is some leg-work required to make this nice and apply it all over Unity's API, but this work should mostly be mechanical. I have no concrete application for that at the moment, but my lived experience suggests that if I put this information out here, the internet will do the rest.

**CAUTION**: Everything outlined here depends on Unity implementation details. They are easy to find using what is publicly available, but still implementation details. All of the things this depends on could change. There are probably many edge cases. There will be crashes. I might just be wrong about some things! Make your own informed choices.

You can find the code for this tomfoolery at the end of the page.

## Unity's bindings

Looking at some of Unity's core types in [Unity's reference source](https://github.com/Unity-Technologies/UnityCsReference) for the C# side of things, you will find that there isn't much there. For example, let's take a look at the definition of `UnityEngine.Object` in [UnityEngineObject.bindings.cs](https://github.com/Unity-Technologies/UnityCsReference/blob/master/Runtime/Export/Scripting/UnityEngineObject.bindings.cs). I have abbreviated it to the relevant bits:

```csharp
public partial class Object
{
    IntPtr   m_CachedPtr;
    int      m_InstanceID;
    // ....
}
```

Note in particular that things like the object's name or other properties are not stored in the C# object. All of this lives on the native side. There are a bunch of calls into native code, shown in the reference source like this:

```csharp
[FreeFunction("UnityEngineObjectBindings::IsPersistent")]
internal extern static bool IsPersistent([NotNull] Object obj);
```

However, I would rather see the actual compiled output of this instead of using the reference source. You can take a look at this using the excellent [dotPeek](https://www.jetbrains.com/decompiler/) (it's free). If you open up `UnityEngine.dll` and look for `UnityEngine.Object`, you can find this here:

```csharp
[MethodImpl(MethodImplOptions.InternalCall)]
private static extern bool IsPersistent_Injected(IntPtr obj);

[FreeFunction("UnityEngineObjectBindings::IsPersistent")]
internal static bool IsPersistent([NotNull] Object obj)
{
    if ((object) obj == null)
        ThrowHelper.ThrowArgumentNullException((object) obj, nameof (obj));
    IntPtr num = Object.MarshalledUnityObject.MarshalNotNull<Object>(obj);
    if (num == IntPtr.Zero)
        ThrowHelper.ThrowArgumentNullException((object) obj, nameof (obj));
    return Object.IsPersistent_Injected(num);
}
```

For completeness, this is what this same thing looks like in dotPeek in Unity 2022.3 LTS:

```csharp
[FreeFunction("UnityEngineObjectBindings::IsPersistent")]
[MethodImpl(MethodImplOptions.InternalCall)]
internal static extern bool IsPersistent([NotNull("NullExceptionObject")] Object obj);
```

It's an internal call that takes the managed object itself. That is the major difference in Unity 6: there we only pass in an `IntPtr`.

The new signature provides an unmanaged interface: It just takes an `IntPtr` and returns a bool. For all I can see, the `IntPtr` is a pointer to the actual native object. We can work with that. Let's make a note that we can get an `IntPtr` via `Object.MarshalledUnityObject.Marshal<T>`. You can find this in [the reference source](https://github.com/Unity-Technologies/UnityCsReference/blob/ee2e94e3ca16e0dbbb4a19814856da04a8e2a2a7/Runtime/Export/Scripting/UnityEngineObject.bindings.cs#L679). The type is `internal`, but we can access it via reflection to get an `IntPtr` for Unity Objects whenever we need to.

### Instance IDs and lifetimes

This is incidentally also where the `m_InstanceID` and `m_CachedPtr` fields come into play: The instance ID is used to look an object up in the marshalling function mentioned above. We only perform this lookup if the `m_CachedPtr` is null. There are some slight differences between editor code and player code for this: the player doesn't rely on the instance ID at all. Lifetimes in the editor are just more complicated: Unity will for example replace native objects when you make changes to them, but the instance ID stays stable and the managed wrapper stays in-tact.

Note that there is no code on the managed side that invalidates the `m_CachedPtr` (- or I did not find it). This suggests that while the interface itself has changed, Unity's native side is still resetting that `m_CachedPtr` when objects are destroyed. This poses a small conundrum for someone that wants to keep an unmanaged handle to all of this: You could either store an instance ID and look it up everytime we access it or you could store the raw pointer and only use it when you are absolutely sure about lifetimes.

I have decided to implement a hybrid solution for educational reasons: In the editor, where things are likely to change, we _always_ use an instance ID. In the player, we always use a raw pointer and accept hard crashes when people access things that have been destroyed. That way at least both codepaths have been implemented and you can pick and choose what you want, or implement different paths etc.

There is a slight complication here for the editor: resolving instance IDs to the internal `IntPtr` requires usage of `typeof(T)` in the inner most API (`Object.GetPtrFromInstanceID`, that is one of the cases where the Unity API still uses managed things), which doesn't fly in Burst. For that case, we are going to use that little trick I mentioned [last time]({% post_url 2024-10-28-burst-managed-code %}) to call into a managed method from Burst.

This post is only going to show the pointer side of the story; please take a look at the accompanying source for the rest.

## Using unmanaged handles

With these pieces, we can attempt to build an unmanaged handle for, say, a `UnityEngine.Texture`, and then use that to query the number of mipmaps. That is normally a property (`Texture.mipmapCount`), and it is exposed via `int Texture.get_mipmapCount_Injected(IntPtr _unity_self)`:

```csharp
public struct TextureHandle
{
    public IntPtr Pointer;
}

public static class TextureHelper
{
    static MethodInfo s_Marshal;
    static MethodInfo s_MarshalTexture;

    public static void Init()
    {
        // Find UnityEngine.Object.MarshalledUnityObject
        BindingFlags bindingFlags = BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Static;
        Type objectType = typeof(UnityEngine.Object);
        Type marshalledUnityObject = objectType.GetNestedType("MarshalledUnityObject", bindingFlags);

        // Get the MethodInfo for the generic Marshal method
        s_Marshal = marshalledUnityObject.GetMethod("Marshal", bindingFlags);

        // Specify the type argument for the generic method
        s_MarshalTexture = s_Marshal.MakeGenericMethod(typeof(UnityEngine.Texture));
    }

    public static TextureHandle GetTextureHandle(Texture texture)
    {
        return new TextureHandle
        {
            Pointer = (IntPtr)s_MarshalTexture.Invoke(null, new object[] { texture })
        };
    }

    public static int GetMipmapCount(TextureHandle texture)
    {
        // Note, this DOES NOT COMPILE
        return UnityEngine.Texture.get_mipmapCount_Injected(texture.Pointer);
    }
}
```

Unfortunately, `GetMipmapCount(TextureHandle)` in its current form does not compile: `Texture.get_mipmapCount_Injected` is private, and we cannot access it. We could use reflection to invoke the function regardless, but this would defeat the entire point: `MethodInfo` is a managed type, and invoking this would involve an extra allocation to specify the parameter array `object[]`. It would be inefficient and also not be Burst compatible. We will have to take a short detour to fix this problem. But once we have fixed the problem, we can write code like this here:

```csharp
[BurstCompile]
public class BurstTextureMipsExample : MonoBehaviour
{
    public Texture Texture;
    public void Start()
    {
        TextureHelper.Init();

        // Access
        //  Texture.mipmapCount
        // but in Burst:
        TextureHandle handle = TextureHelper.GetTextureHandle(Texture);
        int mips = GetMipMapCount(handle);
        Debug.Log($"Mip count: {mips}");
    }

    [BurstCompile]
    public static int GetMipMapCount(TextureHandle texture)
    {
        // This compiles with Burst and just works!
        return TextureHelper.GetMipmapCount(texture);
    }
}
```

## Calling `Texture.get_mipmapCount_Injected`

Luckily, C# access modifiers are more what you call "guidelines" than actual rules for the runtime. If we were to code in raw IL (the Intermediate Language that C# compiles to), we could call this function just fine. What we are going to hence do is write the following code, but in IL:

```csharp
namespace UnityExposed
{
    public class Texture
    {
        public int get_mipmapCount_Injected(IntPtr self)
        {
            // This call needs to be written in IL:
            return UnityEngine.Texture.get_mipmapCount_Injected(self);
        }
    }
}
```

Alternatively, we could change Unity's assemblies themselves to just make everything public. But I reckon this would cause a good bunch of confusion, and my goal here is to do everything without changing Unity itself.

Writing the above code in IL is very easy to do using [Mono.Cecil](https://github.com/jbevain/cecil). Unfortunately, everything else about this setup is terrible. I have tried to write out an assembly using Cecil that references the right dependencies, but somehow always ended up with a bastardized assembly that references both .NET Standard 2.0 and .NET Framework 4.5... or at least something to that end, and my rough understanding is that this is bad. Unity did not like it either.

Needless to say, that is not how I want to spend my time. I instead opted to let Unity compile an assembly for me and then I modify that one. That way the compiled assembly already has all of the references set up correctly and I do not need to deal with this headache. I am sure someone else has a short solution to that problem that cuts out this detour.

For this setup, we are going to have two Unity projects: One that is empty and only serves the purpose of compiling an (initially) empty assembly `UnityExposed.dll` for us, and then the project that actually uses said assembly as an external DLL. Here is the full thing that I do:

1. Create a new empty Unity project.
2. Create a new assembly called `UnityExposed` in that project. Add an empty internal `Dummy` script to that assembly.
3. Let Unity compile this assembly. That happens automatically.
4. Grab the assembly from Unity's `Library/ScriptAssemblies` folder and run it through a script that adds the call to `get_mipmapCount_Injected`.
5. Save the assembly out and put it into the Unity project where I actually want to use it.

You can find the full C# script that I am using for all of this at the end of this post, but here is a version that just handles `get_mipmapCount_Injected`.

```csharp
using Mono.Cecil;
using Mono.Cecil.Cil;

class Program
{
    static void Main()
    {
        // We need to find both the UnityEngine.CoreModule.dll assembly and the assembly we compiled.
        const string UnityAssemblyPath = @"F:\UnityEditors\6000.0.24f1\Editor\Data\Managed\UnityEngine\UnityEngine.CoreModule.dll";
        const string ExposedAssemblyPath = @"D:\local-repositories\Empty\Library\ScriptAssemblies\UnityExposed.dll";

        // Load the original assembly containing the functions we want to expose, and locate them.
        var unityAssembly = AssemblyDefinition.ReadAssembly(UnityAssemblyPath);

        // Now create our proxy
        var assembly = AssemblyDefinition.ReadAssembly(ExposedAssemblyPath);
        var publicType = new TypeDefinition("UnityExposed", "Texture", TypeAttributes.Public | TypeAttributes.Class, assembly.MainModule.TypeSystem.Object);
        assembly.MainModule.Types.Add(publicType);

        // Define a public method in the new assembly to forward calls to the private function
        var publicMethod = new MethodDefinition(
            "get_mipmapCount_Injected",
            MethodAttributes.Public | MethodAttributes.Static,
            assembly.MainModule.TypeSystem.Int32);

        // Add parameters to the public method that match the private function signature
        publicMethod.Parameters.Add(new ParameterDefinition("_unity_self", ParameterAttributes.None, assembly.MainModule.TypeSystem.IntPtr));

        // Generate the IL code to forward the call to the function method
        var ilProcessor = publicMethod.Body.GetILProcessor();
        ilProcessor.Emit(OpCodes.Ldarg_0);  // Load the IntPtr parameter
        {
            var privateType = unityAssembly.MainModule.GetType("UnityEngine.Texture");
            var privateMethod = privateType.Methods.First(m => m.Name == "get_mipmapCount_Injected");
            ilProcessor.Emit(OpCodes.Call, assembly.MainModule.ImportReference(privateMethod));  // Call the private method
        }
        ilProcessor.Emit(OpCodes.Ret);      // Return the result of the private method call

        // Add the public method to the public type
        publicType.Methods.Add(publicMethod);

        // Save the new assembly
        assembly.Write("UnityExposed.dll");

        Console.WriteLine("Exported assembly created successfully.");
    }
}
```

With all of this done, we can now fill the gap we had above and do this:

```csharp
public static class TextureHelper
{
    // ...

    public static int GetMipmapCount(TextureHandle texture)
    {
        return UnityExposed.Texture.get_mipmapCount_Injected(texture.Pointer);
    }
}
```

## Dealing with arrays and strings

For functions that take arrays or strings, we have to do a bit of extra work to take care of the buffers involved. Here is for example how `UnityEngine.Object.GetName` is implemented:

```csharp
    [FreeFunction("UnityEngineObjectBindings::GetName", HasExplicitThis = true)]
    private string GetName()
    {
        ManagedSpanWrapper ret;
        string stringAndDispose;
        try
        {
            IntPtr _unity_self = Object.MarshalledUnityObject.MarshalNotNull<Object>(this);
            if (_unity_self == IntPtr.Zero)
                ThrowHelper.ThrowNullReferenceException((object) this);
            Object.GetName_Injected(_unity_self, out ret);
        }
        finally
        {
            stringAndDispose = OutStringMarshaller.GetStringAndDispose(ret);
        }
        return stringAndDispose;
    }

    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern void GetName_Injected(IntPtr _unity_self, out ManagedSpanWrapper ret);
```

Note the `ManagedSpanWrapper` and the call to `OutStringMarshaller.GetStringAndDispose`. The [source code for the span wrapper](https://github.com/Unity-Technologies/UnityCsReference/blob/ee2e94e3ca16e0dbbb4a19814856da04a8e2a2a7/Runtime/Scripting/Marshalling/ManagedSpanWrapper.cs#L13) is straight forward. The only difficulty is that it is again an internal, inaccessible type.

The gist is that when we deal with strings and arrays, we need to check who owns them, maybe copy data, and maybe free the allocation holding the marshalled value. There is a separate allocator for this, the [bindings allocator](https://github.com/Unity-Technologies/UnityCsReference/blob/ee2e94e3ca16e0dbbb4a19814856da04a8e2a2a7/Runtime/Scripting/Marshalling/BindingsHelpers.bindings.cs#L10), which we also need access to without reflection. It luckily just consists of two functions that are easily exposed.

Let's go through some concrete cases and show what there is to do.

### String and array parameters

String and (blittable) array parameters both go through `ManagedSpanWrapper`. Non-blittable array parameters still seem to be passed into native code as managed objects. Here is an example:

```csharp
class Object
{
    [MethodImpl(MethodImplOptions.InternalCall)]
    private static extern void SetName_Injected(IntPtr _unity_self, ref ManagedSpanWrapper name);
}
```

This should be very simple: Construct the `ManagedSpanWrapper`, fill in base pointer and length, and then call the function. However, `ManagedSpanWrapper` is not public. We are going to work around this as follows:

1. We are going to copy the definition of `ManagedSpanWrapper` into the `UnityExposed` assembly source in our empty Unity project. Let's call that type `UnityExposed.Bindings.ManagedSpanWrapper` and make it public.
2. We are going to expose a wrapper around `SetName_Injected` that takes an `IntPtr` and an instance of the new type we just added.
3. Within our `SetName_Injected` wrapper, we are going to construct an instance of the original `ManagedSpanWrapper` and fill it with the data from our copy.
4. Then we call the original `SetName_Injected`.

The biggest chunk of work here is to update our Cecil code. I've added this:

```csharp
var origSpanWrapper = unityAssembly.MainModule.GetType("UnityEngine.Bindings.ManagedSpanWrapper");
var newSpanWrapper = assembly.MainModule.GetType("UnityExposed.Bindings.ManagedSpanWrapper");

var objectType = new TypeDefinition("UnityExposed", "Object",
    TypeAttributes.Public | TypeAttributes.Class,
    assembly.MainModule.TypeSystem.Object
);
assembly.MainModule.Types.Add(objectType);

var nameSetter = new MethodDefinition(
    "SetName_Injected",
    MethodAttributes.Public | MethodAttributes.Static,
    assembly.MainModule.TypeSystem.Void);
nameSetter.Parameters.Add(new ParameterDefinition("_unity_self",
    ParameterAttributes.None, assembly.MainModule.TypeSystem.IntPtr));
nameSetter.Parameters.Add(new ParameterDefinition("name",
    ParameterAttributes.None, newSpanWrapper));

// Generate IL for the wrapper method
var il = nameSetter.Body.GetILProcessor();

// Define a local variable of type ManagedSpanWrapper
var originalStructVar = new VariableDefinition(assembly.MainModule.ImportReference(origSpanWrapper));
nameSetter.Body.Variables.Add(originalStructVar);
nameSetter.Body.InitLocals = false;

// Construct the local ManagedSpanWrapper
il.Emit(OpCodes.Ldloca_S, originalStructVar);
il.Emit(OpCodes.Ldarg_1);                 // Load the PublicManagedSpanWrapper parameter
il.Emit(OpCodes.Ldfld, newSpanWrapper.Fields.First(f => f.Name == "begin"));   // Load 'begin' field
il.Emit(OpCodes.Ldarg_1);                 // Load PublicManagedSpanWrapper parameter
il.Emit(OpCodes.Ldfld, newSpanWrapper.Fields.First(f => f.Name == "length"));  // Load 'length' field
il.Emit(OpCodes.Call, assembly.MainModule.ImportReference(origSpanWrapper.GetConstructors().First()));

// Call SetName_Injected
il.Emit(OpCodes.Ldarg_0);                 // Load the IntPtr parameter (_unity_self)
il.Emit(OpCodes.Ldloca_S, originalStructVar);  // Load reference to ManagedSpanWrapper
var privateType = unityAssembly.MainModule.GetType("UnityEngine.Object");
var privateMethod = privateType.Methods.First(m => m.Name == "SetName_Injected");
il.Emit(OpCodes.Call, assembly.MainModule.ImportReference(privateMethod));   // Call the original SetName_Injected method

il.Emit(OpCodes.Ret);

// Add the wrapper method to the target type
objectType.Methods.Add(nameSetter);
```

It's not half as scary as it looks and the entire process could be automated if you needed to do this for many different functions.

With all of this done, we can now add this function to our helper type from before.

```csharp
public static unsafe void SetName(TextureHandle texture, void* chars, int length)
{
    // Note that length is the number of CHARACTERS here, not the number of BYTES.
    var span = new UnityExposed.Bindings.ManagedSpanWrapper(chars, length);
    UnityExposed.Object.SetName_Injected(texture.Pointer, span);
}
```

Note that we cannot use `Span<char>` or `char*` in our functions: Burst does not support `char`.

Finally, we can now write code like this to change the name of a texture (or actually any Unity object) without allocating a string:

```csharp
[BurstCompile]
public class BurstTextureNameExample : MonoBehaviour
{
    public Texture Texture;
    public void Start()
    {
        TextureHelper.Init();

        // Set
        //  Texture.name
        // but in Burst:

        Span<char> chars = stackalloc char[10];
        chars[0] = 'H';
        chars[1] = 'e';
        chars[2] = 'l';
        chars[3] = 'l';
        chars[4] = 'o';
        unsafe
        {
            fixed (char* cs = chars)
            {
                SetName(handle, cs, 5);
            }
        }

        // Actually prints out the new name! Yay!
        Debug.Log($"New texture name: {Texture.name}");
    }

    [BurstCompile]
    public static unsafe void SetName(TextureHandle texture, void* chars, int length)
    {
        TextureHelper.SetName(texture, chars, length);
    }
}
```

### String return values

These are handled via out `ManagedSpanWrapper` parameters (as shown above in the `GetName` example). Unity's bindings then use [a marshalling helper](https://github.com/Unity-Technologies/UnityCsReference/blob/ee2e94e3ca16e0dbbb4a19814856da04a8e2a2a7/Runtime/Scripting/Marshalling/StringMarshalling.cs#L11) to allocate a new string and then deallocate the buffer coming from native code:

```csharp
internal unsafe ref struct OutStringMarshaller
{
    public static string GetStringAndDispose(ManagedSpanWrapper managedSpan)
    {
        if (managedSpan.length == 0)
        {
            // null and 0 length strings are not allocated, no need to free
            return managedSpan.begin == null ? null : string.Empty;
        }

        var outString = new string((char*)managedSpan.begin, 0, managedSpan.length);
        BindingsAllocator.Free(managedSpan.begin);
        return outString;
    }

    // ...
}
```

You can get rid of the GC allocated `string` by copying the data to an allocation of your choice, e.g. some UTF16 buffer you allocated yourself.

### Array return values

This is a little bit more involved because there are more scenarios to consider. Arrays are returned as out parameter of type `BlittableArrayWrapper`, whose [source](https://github.com/Unity-Technologies/UnityCsReference/blob/ee2e94e3ca16e0dbbb4a19814856da04a8e2a2a7/Runtime/Scripting/Marshalling/BlittableArrayWrapper.cs#L13) outlines how you take its data and turn it into a regular C# array. The linked source has quite a few comments and should by now be easy to understand without further help. You will of course have to do the full song-and-dance to expose `BlittableArrayWrapper`.

Note that while the comments talk about using `BlittableArrayWrapper` to pass data from managed to native code, I have never seen that happen in practice. As far as I can tell, the bindings always use `ManagedSpanWrapper`.

## Limitations

With all of the above said, there are still cases where the lowest level API takes managed objects. One example I could find is this:

```csharp
class Sprite {
    private static extern uint GetScriptableObjects_Injected(
      IntPtr _unity_self,
      ScriptableObject[] scriptableObjects);
}
```

This seems to mostly affect cases where arrays of managed objects are passed around, e.g. `ScriptableObject[]` or `string[]`. I have additionally observed that multi-dimensional managed arrays (`bool[,]`) are still directly returned from native code (but passing them into native code still uses `ManagedSpanWrapper`).

If you end up making unmanaged wrappers for some of Unity's managed interfaces, do be mindful when you call them. Unity usually throws exceptions to communicate errors, and there is no guarantee that this won't blow up in your face when using Burst.

I am also sure that there are plenty of edge-cases that I have not yet found. I have ensured that the cases I have looked at work in the editor and in both Mono and IL2CPP builds. But surely there are scenarios where you will have to still overcome some issues.

It is also worth pointing out that just because you can use a thing from Burst does not mean you can suddenly use something in a job. Unity tries its best to detect whether something is called from the main thread or not, and it will still complain if you violate that. Things do not magically become threadsafe.

Finally, I need to point out that if you decide to do any of these things, then you very obviously voided the warranty on whatever Unity things you depend on. These are clearly implementation details, and there is no guarantee that these details won't change (though my expectation is that they won't change within Unity 6's lifetime). Personally, I would happily use this approach if it helped me ship something, but that's a call you have to make for your project.

## Appendix

I wanted to record some vestigial bits of knowledge that may come in helpful:

First, iterating on the post-processed `UnityExposed.dll` while keeping Unity running often resulted in plenty of invalid errors coming from Burst. Remember, my process involves two Unity projects: One project has `UnityExposed` as a Unity assembly, then we have the script that post processes that assembly, and then the result is dropped into another Unity project where I actually use the post-processed assembly as an external assembly. That latter Unity project is the one that would have Burst errors. They seem to all relate to hashing, i.e. Burst trying to detect whether some code has actually changed. It looks like updating external assemblies trips Burst up a good bit. In all cases where I hit these errors, I was able to resolve them by closing the Unity editor, deleting the `BurstCache` and `ScriptAssemblies` folders from the projects Library folders, and then restarting Unity.

One particular aspect is worth commenting on for the Cecil code: Naively, it looks like all of the types we care about are declared in `UnityEngine.dll` and we should be able to reference that one. In practice however, we reference `UnityEngine.CoreModule.dll`. Why? Well, `UnityEngine.dll` doesn't actually contain the types we need. There is a dotnet concept at play that allows you to declare an API in one assembly and then implement it in another. The implementation for `ManagedSpanWrapper` is in `UnityEngine.CoreModule.dll`, and the details vary between the editor and standalone builds. In the editor, it is sufficient to use `UnityEngine.dll`. In a build however, `UnityEngine.dll` suddenly contains an empty `class ManagedSpanWrapper` instead of the struct that we are looking for. Why? I have no idea. But it means that our code no longer works with Burst because of this sudden shift to a class instead of a struct. Referencing `UnityEngine.CoreModule.dll` solves that completely.

You can find the code for this whole thing [here](https://github.com/sschoener/unity-unmanaged).
