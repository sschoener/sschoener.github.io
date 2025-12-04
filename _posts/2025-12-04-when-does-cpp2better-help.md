---
layout: post
title: When better codegen doesn't help
excerpt:
tags: []
---

I want to write a few words about what sorts of games benefit from my build postprocessor for Unity il2cpp builds, [cpp2better]({% post_url 2025-11-04-cpp2better-release %}). It's not the case that every game unconditionally benefits from it to the same extent. cpp2better essentially takes on the role of a compiler: given some program, it produces a (mostly) equivalent program that just happens to be leaner and generally better.

When does a better compiler not help? Imagine that your compiler is very bad at emitting (say) efficient sequences of math instructions. Is that going to impact the performance of your program? It is certainly going to affect the performance of *some* programs, but for a particular program, like yours, that is not necessarily true. In the case of cpp2better, here are some common factors:
 
First, is your frametime even limited by your CPU? If your game is not CPU-bound but mostly waits for the GPU to finish rendering, then there is no point in making the CPU code faster.

Second, does your game even use a lot of C# code in the first place? The core of Unity's engine is still native code, compiled once from the C++ source of the engine. Many of the facilities of the engine like the transform system, the audio system, the animation system, or parts of rendering use that native code. Improving the output of il2cpp is irrelevant for that part of the codebase. If your game spends 10% of your frametime in C# code, and that code gets (say) 20% faster, then your overall frametime is at most getting 2% faster. As a rule-of-thumb, I would expect a simulation or strategy game to run much more il2cpp-compiled C# code than a platformer, simply because there is a bigger need for simulation. Similarly, games that use Unity's newer DOTS stack are more likely to use more C# code, because DOTS is almost entirely implemented in C#. This brings us to the next point.

Third, is the C# code you write even compiled with il2cpp? Unity allows you to compile a subset of your code with Burst. Burst is a native compiler whose main purpose is to give you really great codegen. Unfortunately, large parts of Unity's API surface are not Burst compatible, and using Burst in your project is also a sure way to ruin your iteration times through obsessively long compile times. I have frequently seen teams that go all-in on Burst and are then surprised by how slow the remainder is. That's a good target for cpp2better!

Fourth, does the code you write even benefit from better codegen? It's no big news by now anymore that computation has outpaced memory access speeds over the last few decades. Typical old-school Unity games consist of lots of tiny objects, allocated one-by-one. There is a good chance that your CPU spends a significant amount of your frametime just waiting for memory accesses when touching all of these objects randomly scattered through memory. You can hide a lot of computation behind memory stalls, and making those computations faster then does not change end-to-end times. Additionally, the compiler can do very little about your memory access patterns and data organization, that's on you to resolve. Or in other words, a huge part of your runtime performance is already decided before your code even gets to the compiler.

All of this is to say that cpp2better is most likely to give you a good performance boost if you are running lots of C# code and use all of Unity's tools to reduce memory stalls, but still need to interact with the main engine (which can't go through Burst). If you have adopted DOTS for example, then your game is much less likely to just spend its time waiting for memory stalls, so good codegen actually matters. You also end up with a lot of code that is *almost* Burst-compatible, if it wasn't for all of Unity's API surface. That's the scenario that is most likely to benefit from better codegen through cpp2better. It raises the ceiling, not the floor.

---

Finally, I should also point out that better codegen is more-or-less the last piece in the optimization pipeline. The most common performance problems have nothing to do with codegen. These points below (along with data organization and batching) probably cover the majority of performance issues, and none of them can be addressed by better codegen:

1. **You are solving a problem you don't actually have.**
   * Examples: Your game's animation system supports up to 1024 dynamically moving enemies, but you are making chess. The squirrels roaming the environment in your open world game have 12 levels of sound effects layered on their footsteps (nobody cares!). You allocate a thousand things with separate calls to `malloc`, even though they all have the exact same lifetime (you don't need general purpose allocation!). You parse a 3MB JSON file but there's no point in it being JSON (it could be binary!).
   * What to do: actually write down what you care about and what your constraints are (and are not), then ruthlessly exploit them. Implement custom solutions instead of general purpose libraries.
2. **You are solving the right problem, but you chose inefficient algorithms.**
   * Examples: You walk a graph and put all nodes you have already seen in a big list that you need to now check before going to the next node (instead of putting the information on the node or a hashset).
   * What to do: look for a better algorithm (which for many problems just means "use a hashmap somewhere").
3. **You are re-computing data that is unchanging and static.**
   * Examples: Your build system keeps on recompiling the same source files. Your game re-encodes unchanging textures on every startup.
   * What to do: Figure out what data is actually constant, then precompute or add a cache if need be.

These problems have the unfortunate property that they require an understanding of what your software is doing or maybe rather "is trying to do." Nothing that a compiler (or Unity for that matter) could do will fix them for you.