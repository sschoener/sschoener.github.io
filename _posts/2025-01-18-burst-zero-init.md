---
layout: post
title: Burst and "zero cost"
tags: []
---

_Hey! You can find me on [Mastodon](https://mastodon.gamedev.place/@sschoener), [Bluesky](https://bsky.app/profile/sschoener.bsky.social), or [Twitter](https://twitter.com/s4schoener)!_

First of, let me apologize for the title. This is not about "zero cost" abstractions, but the title still holds.

To set the scene, note that Unity's Entities package has lots of safety checks to stop you from doing things that will either crash your game (in the best case) or just silently corrupt memory elsewhere (e.g. due to race conditions, double-freeing, etc.). The typical long-term Unity user is not used to such a hostile environment and hence the safety checks are really necessary to get a good user experience for developers, and even if you don't care about the user experience, it is still clear that these safety checks save _a lot_ of time when you need to debug crashes. I at least have often benefitted from the presence of these checks.

Originally, these checks were only enabled in the editor and guarded by a define `ENABLE_UNITY_COLLECTIONS_CHECKS`, but nowadays there is a flag `UNITY_DOTS_DEBUG` that enables a subset of these checks in standalone builds as well. I would argue that in many cases you may actually want to ship with at least some of these checks enabled (maybe even just temporarily), depending on how well your developers listen to the screams from your QA department and how much you are abusing your users to test your game. Some checks (like thread safety checks) still only exist in the editor, because the infrastructure such as `AtomicSafetyHandle` is not available in standalone builds.

Even if you never trigger these checks, these checks have a pretty steep cost purely by how they report errors. When a safety check fails, you want to get a nice error message that tells you what went wrong, maybe even formats the entity ID into it and so on. This formatting is not the cost I am talking about, but it is also a common issue: Any call of the form `Assert.IsTrue(condition, $"Length error message {some_variable}")` is prone to this because the formatting happens regardless of whether the condition is true or false. C# does not have macros, so this is just a function call that evaluates its arguments before the call.

In the case of Burst and safety checks, the issue is more subtle. Burst does not have regular `string` support, because that is a managed type. However, the Unity Collections package has various `FixedStringX` types, where `X` could be a number like 128 or 512. Those are value types with a buffer of the indicated size. Burst supports these types for handling strings. These strings need to go somewhere, and they end up on the stack. C# demands that every local variable is zero-initialized, and now you need to very regularly zero-initialize these buffers. But wait! These buffers are only used when the safety check fails, right? Alas, the IL below the C# has no notion of block-scoped local variables (for all I can tell), so whatever happens in a branch still affects the entire function.

OK, but setting things to zero can't be _that_ expensive, right? Uh. Oh. Bad news, this is from `EntityQueryImpl.GetSingleton<T>`:

<p align="middle">
  <img src="/img/2025-01-18-burst-zero-init/step-1.png" alt="" />
</p>

Note that we spend a ridiculous proportion of the time before we even execute any code that is actually visible: The time is attributed to `{`. We can confirm that this is zero-initialization by looking at the assembly listing:

<p align="middle">
  <img src="/img/2025-01-18-burst-zero-init/step-2.png" alt="" />
</p>

If you look at the IL in say `dotPeek`, you will find this near the top of the function:
```
.locals /*1100039F*/ init (
  [0] valuetype Unity.Entities.TypeIndex/*0200037B*/ typeIndex,
  [1] valuetype [Unity.Collections/*23000004*/]Unity.Collections.FixedString128Bytes/*01000057*/ fixedString,
  [2] valuetype [Unity.Collections/*23000004*/]Unity.Collections.FixedString128Bytes/*01000057*/ fixedString_V_2,
  [3] valuetype Unity.Entities.UnsafeCachedChunkList/*02000236*/ matchingChunkCache,
  [4] valuetype Unity.Entities.ChunkIndex/*02000347*/ chunk,
  [5] int32 V_5,
  [6] valuetype Unity.Entities.MatchingArchetype/*02000232*/* matchingArchetypePtr,
  [7] valuetype [Unity.Collections/*23000004*/]Unity.Collections.FixedString128Bytes/*01000057*/ fixedString_V_7,
  [8] int32 outIndexInArchetype,
  [9] valuetype Unity.Entities.ChunkIndex/*02000347*/ outChunk,
  [10] int32 outEntityIndexInChunk,
  [11] !!0/*T*/* V_11
)
```
That's no less than three separate `FixedString128Bytes` locals that all want to be zero-initialized when you call this function.

What options do we have around this? First, note that this is code from Unity's Entities package, so you can change it yourself but really Unity should just fix this. Here are two ways around this:
 * You can put the error that uses strings into a separate function and ensure that this function is never inlined by marking it with `[MethodImpl(MethodImplOptions.NoInlining)]`. This moves the costly initialization into a separate function, and that function should only ever execute when the safety check fails.
 * Alternatively, Burst has an attribute to disable zero-initialization for a function, `[SkipLocalsInit]` ([SkipLocalsInit docs](https://docs.unity3d.com/Packages/com.unity.burst@1.8/manual/optimization-skiplocalsinit.html)). This should be used with more caution, because in some cases you may really want the zero-initialization: you might be using `stackalloc` and rely on the memory you get back being zeroed out. 

Your move, Unity.

{% include clickable-image.html %}