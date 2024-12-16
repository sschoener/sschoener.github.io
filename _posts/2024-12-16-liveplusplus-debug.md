---
layout: post
title: Fixing bugs in style with Live++
excerpt:
tags: []
---

_Hey! You can find me on [Mastodon](https://mastodon.gamedev.place/@sschoener), [Bluesky](https://bsky.app/profile/sschoener.bsky.social), or [Twitter](https://twitter.com/s4schoener)!_

[Live++](https://liveplusplus.tech/) is a fantastic product that enables hot reload for C++ code in pretty much arbitrary codebases on Windows (and XBox and Playstation). The neat part is that it doesn't require any specific setup like splitting all of your code into reloadable DLLs or similar, and it plays nicely with the subtleties of reloading code (what happens to global data defined in the reloaded compilation units? etc.).

The integration is stupidly simple (quite literally ten lines of code to get started), and it doesn't require any integration into your build system beyond setting two or three compiler or linker flags. The magic sauce is that the debug info (e.g. PDB) for your program already contains enough information for how to rebuild and link single files. This means that Live++ already knows more about your build than your average developer does in a large codebase!

In my work with large-ish codebases this has been a phenomenal addition to my toolbox: There is no chance that they get rewritten to support DLL-hotreload. But adding ten lines to get hotreload? _Yes, please!_

The real benefit is not just that I can skip recompilation and linking: it's that I don't have to restart the program and set my scenario up anew. I can just keep editing code and it works without kicking me out of the current program state (in my case: a running game).

This post, however, is not a sales-pitch for Live++ (though you should take a look and do the math: Live++ is a net-positive if it only saves me a few _hours_ per year (!), and it saves me hours per day). No, I am writing this because I wanted to share a thing I learned while using Live++ with Visual Studio.

Live++ has a feature for intercepting crashes in your program. This makes sense, because my live-iteration workflow definitely involves screwing up. Take a look here at this failure happening (in the debugger):

<p align="middle">
  <img src="/img/2024-12-16-liveplusplus-debug/bug.png" alt="" />
</p>

Who writes code that is so obviously wrong and stupid? _Me_, of course! This is in fact a dramatic reenactment of a bug I recently produced all by myself, where I was first setting something to null and then used it on the next line while releasing some resources. I am very smart: s-m-r-t.

If you do not have a debugger attached, or you continue execution in your debugger, you will see this popup from Live++ (or similar - this one is from an earlier version of the crash):

<p align="middle">
  <img src="/img/2024-12-16-liveplusplus-debug/exception-handler.png" alt="" />
</p>

(Sidenote: Just because Windows decided it is fine to shorten my first name to "Sebas" does not mean that it is fine for you to do it. You have been warned, I may respond in kind.)

There are a couple of options here: You can disable or ignore the faulting instruction, you can just leave the function, or continue and see what happens. All of them are useful. What I however am often looking for is "please let me fix the bug and then re-execute the function." Can we do this manually with Live++?

Hotreloading works by patching a jump into the function itself, in the very beginning. That jump will then go to the latest version of the function. So when we fix the bug and trigger a hot-reload we still have to re-enter the function if we want to re-execute the correct code. In some cases, your function will have modified global state etc, but in other cases just re-entering the function would be completely sufficient. And it turns out you can just do that:

<p align="middle">
  <img src="/img/2024-12-16-liveplusplus-debug/arrows-rip.png" alt="" />
</p>

After all these years, I finally learn that you can actually drag those damn arrows around. It did not occur to me until writing this down that this "arrow" is in fact a pointer towards the instruction, an "instruction pointer" if you will.

It is almost embarassing, because _of course_ I knew that it is very well possible to adjust the instruction pointer however I please. But it never occurred to me to do it outside of debugging assembly directly, because it was cumbersome, and now I can just drag and drop the instruction pointer.

I have quickly learned to prefer to do this in the disassembly view instead of the source code view, because then I actually see where exactly I'm going and whether I am at risk of breaking something in a subtle way (e.g. skipping over a destructor, trampling over arguments that are passed in registers, changes to the stack). To point out the obvious, dragging the function pointer around _does not_ undo previously executed code. So unless you know what you are doing, you could leave your program in an arbitrarily broken state.

With this small trick (that many are surely going to tell me is not really any news to them), here is my workflow:

1. Crash happens. Break in debugger. Notice the bug.
2. Drag the instruction pointer back to the start of the function you want to fix. In this case, drag the arrow first to the end of the `Release` function, then step out, then drag it all the way to the start of the `AccessViolation` function; directly on the first instruction. You can't directly drag it to the start of `AccessViolation`, because otherwise you would break the stack.
3. Fix the bug.
4. Hot reload in Live++.
5. Continue stepping from the start of the function and see that we are now executing the new version of the code.

I didn't even have to re-enter the function for this: The old version of the function (which we are currently in) gets the redirection to the new function patched in at the very start. By placing the instruction pointer to re-execute the start of the function, the very next step is going to jump to the new version of the code. Live++ is smart enough to allow code-reloading while the debugger has paused the process. The code-reload might briefly confuse the debugger for a single step, but then it's back to regular operation.

Instead of just going back to the top of the function, we could leave the function (using Live++), do the hot-reload, and then step in again. Leaving the function using Live++ has the advantage of properly calling destructors (using stack unwinding). Before you hit "Leave function", you should manually place a breakpoint _after_ the call to your function: In order to use "Leave function" you had to continue in the debugger, so if you do not place a breakpoint, execution will just continue.

You can probably tell, but I am having a great time with Live++. Fixing a bug like this for the first time and _then just continuing_ has been an absolute highlight (no re-linking of a large executable! no restarting! no going through loading screens! etc.), and you quickly start to ask yourself how you got anything done before hotreload.

{% include clickable-image.html %}