---
layout: post
title: My Worst Piece Of Useful Code
tags: [computer science, programming]
---

I was once asked in a job interview which code that I had written I was most proud of and which code I was least proud of. It did not take me long to realize that for me there is a simple answer for both: It's the same piece of code in both cases. I'm proud of it because it has probably been the most impactful code I have ever written and I'm not-so-proud of it because it is what most people would consider a hack that people have started to build on:

```csharp
/// <summary>
/// Redirects all calls from method 'from' to method 'to'.
/// </summary>
public static void RedirectCalls(MethodInfo from, MethodInfo to)
{
    // GetFunctionPointer enforces compilation of the method.
    var fptr1 = from.MethodHandle.GetFunctionPointer();
    var fptr2 = to.MethodHandle.GetFunctionPointer();
    PatchJumpTo(fptr1, fptr2);
}

/// <summary>
/// Primitive patching. Inserts a jump to 'target' at 'site'. Works even if both methods'
/// callers have already been compiled.
/// </summary>
private static void PatchJumpTo(IntPtr site, IntPtr target)
{
    // R11 is volatile.
    unsafe
    {
        byte* sitePtr = (byte*)site.ToPointer();
        *sitePtr = 0x49; // mov r11, target
        *(sitePtr + 1) = 0xBB;
        *((ulong*)(sitePtr + 2)) = (ulong)target.ToInt64();
        *(sitePtr + 10) = 0x41; // jmp r11
        *(sitePtr + 11) = 0xFF;
        *(sitePtr + 12) = 0xE3;
    }
    
    /*
        Note: For a x86/32 bit version, you can drop the REX prefixes (0x49, 0x41) of the opcodes.
        You will also need to change ulong to uint. This yields opcodes for
        mov ebx, target
        jmp ebx
        (which just happens to work since the REX prefix turns ebx into R11).
    */
}
```
This is C# code that writes some x86/64 machine code to change the program's behavior. What for? Read on.

In 2015 Colossal Order and Paradox released [Cities: Skylines](https://store.steampowered.com/app/255710/Cities_Skylines/) (CS), a truly great game created using Unity and C#. I have a bit of a history with modding video games and it usually doesn't take me more than a few hours with a game before I start becoming more interested in the technical aspects of messing with it than actually playing it. CS allows you to load your own .NET assemblies into the game and provides a simplistic interface for changing parts of the game, like the demand for industrial zoning etc. It is well-inteded, but quite limited.[^moddability] I have never been satisfied with just changing some numbers or exchanging some of the game's resources -- modding gets interesting as soon as you can experiment with mechanics. At that point, I spent a weekend investigating different ways to redirect (_detour_) method calls in .NET because that would allow me to change arbitrary code in the game and hook in to whatever part I liked to modify it.

I had worked a lot with DLL injection and patching game code previously when I was modding Relic Entertainment's _Company of Heroes_ (CoH) and _Dawn of War_ (DoW) games. I still fondly remember the time I wrote a patch in assembly to load a .NET runtime in DoW2 that would then hook new bindings into the game's LUA scripting system to communicate with a webserver: Yes, I had a lovely childhood and apparently plenty of time for this kind of stuff back then. For CS, which is using the open-source .NET implementation Mono, I had hoped to find a "proper" way to easily redirect method calls and came up with [a few approaches](https://github.com/sschoener/cities-skylines-detour) that more of less worked. The simplest one was unfortunately (?) the least exciting one: Force the JIT compiler to compile a method and then just patch the machine code to include a jump to the target method.

I was reluctant at first because when you talk about JIT compilers, people usually imagine those highly dynamic environments with heroic optimizations and ever changing more and more optimized code over the course of the program's runtime. This would immediately break this hack. Similarly, inlined functions would also be completely broken. To my surprise, none of this was a problem that I encountered with Mono, but I could not completely rule it out, so I labeled it a _proof of concept_ above anything else. It is a hack that could easily break when you move over from Windows to Linux or from one Mono version to another or from Mono to some other JIT.
It is not even particularly complex, _anyone_ could have done this. In all likelihood nobody implemented it before because in theory it should not have worked. In practice, however, it did.

Since I have released the code, it has taken on a life on its own. People first started to use it verbatim in CS, then built abstractions around it. It quickly found use in plenty of other modding communities around Unity games and other games that rely on Mono. Since then, answers to the question of how to detour a .NET method frequently use this very primitive patching approach.[^note] It took some time for me to realize what had happened. At some point, I was asked to link to [the Harmony library](https://github.com/pardeike/Harmony) with [the note](https://github.com/sschoener/cities-skylines-detour/issues/3) that this was a library intended to replace the offspring of my work because it was inherently problematic when multiple clients tried to detour the same method. It's a pretty useful library, by the way, and it attempts to solve the difficult problems that I did not touch on at all (inlining, multiple detours, dynamic methods etc.). At its core, Harmony is still [patching the compiled function](https://github.com/pardeike/Harmony/blob/b3a05712706ae218e351e824276875c1d056f834/Harmony/Internal/Memory.cs#L95) (using `RAX` instead of `R11` for the jump).

In retrospect, I believe that this has been a helpful lesson. This code solves an _actual problem_ in this plane of existence, even though it really shouldn't work in whatever world software engineering usually happens in. That's helpful to keep in mind for someone like me who usually _really_ enjoys a good theory. I have to admit that while this code has questionable implications for a codebase at large, it is probably my piece of code that has had the biggest influence on the world so far, ran on what might be a few 100k machines, and it _definitely_ made the world a better place by allowing more people to express their creativity through modding their favorite games. Mission accomplished.

---

[^moddability]: Nowadays people often want their games to be moddable so they reap the benefits of a (hopefully) large, engaged userbase that keeps the game alive for years. If you ask me, all you need to make your game moddable is to have a way to load new files into your game (if it is data driven) or run new, unrestricted code. As long as you do not actively hinder people in making mods, they will do it. I get that you want to make your game secure and prevent cheating, but at least have a mode that disables achievements (or whatever you are concerned about) or restrict matchmaking by checksum etc. If you wanted to actively help modders, make sure that you communicate architectural changes and make it easy to update tools, e.g. by adding a version tag to your binary file formats. My point is that modders are resourceful and some even _like_ the challenge of reverse engineering your file formats.

[^note]: Maybe I am reading too much into it, but when I first implemented this solution, I of course looked for what other people had written and could not find someone using this approach, most likely because it is inherently non-portable and makes hefty assumptions.