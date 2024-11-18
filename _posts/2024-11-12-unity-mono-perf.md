---
layout: post
title: A word on using modern C# in Unity
excerpt:
tags: [unity]
---

_Hey! You can find me on [Mastodon](https://mastodon.gamedev.place/@sschoener), [Bluesky](https://bsky.app/profile/sschoener.bsky.social), or [Twitter](https://twitter.com/s4schoener)!_

I want to talk about why Unity C# code is different. This is about editor performance, with nullable types as an example. There's some JSON parsing happening, which someone wants faster. (It has to be a JSON parser.) A significant portion here goes into peeking chars. "OK, that's where I/O is happening, duh." But no, there is a lot of work happening in this very PeekChar function. Look at the "Exclusive time" column in Superluminal.

<p align="middle">
  <img src="/img/2024-11-12-unity-mono-perf/0-before.png" alt="Measurement of the before state in Superluminal" />
</p>

Why? How? What's happening here? Superluminal unfortunately can't show us the disassembly here: the code is JIT compiled, so by the time we look at the trace, the machine code has probably vanished. This is a convenient point to say "well that's unfortunate!" and subsequently give up, but that's not in the spirit of what I do. I wrote [a small utility](https://github.com/sschoener/unity-asm-explorer-package) ages ago that allows you to look at the generated machine code in Unity. It even comes with a badly made sampling profiler I created before Superluminal had Mono support. (Unity has a somewhat dated fork of Mono that they are using for C#.) In this case, it's sufficiently telling to just look at the disassembly however.

Back to the code. The relevant bit is that "peekedChar" is of type "char?". That's a nullable char. It allows you to assign null to it. It's C#'s version of an optional value. This is with Unity set to "Release" in the editor, as this is editor code. I have commented the assembly for easier reading. "Debug" config makes all of this much worse still.

<p align="middle">
  <img src="/img/2024-11-12-unity-mono-perf/1-generated-code.png" alt="Generated machine code using nullable char" />
</p>

As you can see, Unity (or rather, Mono) will take things very literally, even on an "optimized" release configuration. Mono wasn't written for perf, it was written for compatibility, and it succeeded greatly on that. Not Mono's fault that Unity is using it. 

So what happens if we don't use "char?" but instead use a char and a boolean?

<p align="middle">
  <img src="/img/2024-11-12-unity-mono-perf/2-improved-code.png" alt="Generated machine code using char and bool" />
</p>

This is much simpler! No more "call" to somewhere! Fewer copies! You can see that it is still taking things very literally: for example, we still redundantly load the character from the object instead of just doing nothing (it's already in AX!). Debug mode gets worse (101 instructions) but the code structure generally changes a lot because Mono inserts a lot of check-for-single-step-debugging trampolines. (Most of that code is never running, but that doesn't mean it's 100% free either. Adding tons of redundant branches literally everywhere could reasonably be assumed to make branch prediction worse, for example.) Instruction count is a very poor metric for performance. However, if you make everything require 7 times more instructions and apply this to an entire program. In this local case, we get a factor of 3 improvement in exclusive time:

<p align="middle">
  <img src="/img/2024-11-12-unity-mono-perf/3-after.png" alt="Measurement of the improved state in Superluminal" />
</p>

Where does that leave us? When you write C# code for the Unity Editor, you are playing a completely different game than when you are writing C# code for regular dotnet: CoreCLR has a competitive, optimizing compiler. Unity's Mono fork doesn't. Ironically, writing Unity C# code is way closer to directly typing out instructions, except that you don't get as much control. The vast majority of advice for how to write C# probably needs to be taken with a grain of salt for Unity.

What is the takeaway? Eliminate "char?" everywhere? I honestly don't know. Yes, I made that frequently called thing 3x faster. No, it's not fast enough globally. I would have to go through the entire program and eliminate stuff like this everywhere. And that wouldn't even be the end of the story. Those are just local changes. An optimizing compiler would likely make this code orders of magnitude faster. What would a good inliner do to this code? Probably a lot! 

Locally, the solution is to re-architect. Rewrite the parser in the C99 equivalent of C# and pretend you are writing assembly. Or use Burst, if you can. Globally, that's often infeasible for existing projects. At that point it is probably a better idea to look at improving Mono. It puts into perspective why Unity wants CoreCLR, but you can either wait for CoreCLR (how long?), not use C# (totally feasible in some cases), or try and improve Unity's version of Mono today. I don't know what the cost of the latter is, but I'd find out if I had the time :)

{% include clickable-image.html %}