---
layout: post
title: Whoops, I wrote a build system
excerpt:
tags: []
---

_Hey! You can find me on [Mastodon](https://mastodon.gamedev.place/@sschoener) and [Bluesky](https://bsky.app/profile/sschoener.bsky.social)!_

A perennial pet peeve of mine (and of every C++ programmer, presumably) is the apparent lack of a default build system. There are two separate problems here: First, everyone is using a different build system. Second, what build system should _I_ use? I am interested in the latter problem, not the former: I am not trying to solve everyone's build problems, and this post does not end with a link to the repository to my build system because that's an anti-goal.

When I say "build system" I really mean "thing that takes me from a bunch of `.cpp` files with external dependencies to a working executable." This is more than just a compiler and linker because you need to handle dependencies, ensure you copy the right build outputs, maybe not rebuild everything all of them time, generate project files for Visual Studio etc.. I'd like to solve this in a way where I actually enjoy the process, and I do not enjoy undebuggable batch files and shellscripts with nearly arbitary syntax.

Some years ago, I had chosen to solve my build problems by using CMake for everything. So my build problems became my CMake problems. I am not particularly fond of CMake (is anyone?), you might even say I absolutely despise it, but I understand it well enough to use it. (And yes, CMake is not a build system; it just generates your build setup for you.) Still, it felt like I was using a complete blackbox. Adding `vcpkg` as a package manager didn't help, and after an initial high of how easy vcpkg is ([easy, not simple!]({% post_url 2024-06-03-simplicity %})) I felt that I was quickly accumulating baggage that I'd rather not have.

## Why did I create a build system?
I like to understand the things I am using. I can either invest a lot of time understanding someone else's system, or I can build my own. I have repeatedly found in my life that sooner or later I will have to understand whatever it is that I am using and complex dependencies (CMake, `vcpkg`) then become a liability, not a benefit. They solve more problems than I have and are more complicated for it.

My own system has the advantage that I only need to solve my concrete problems and I can make choices that represent my values. Some of my main values are:

1. The build system should be debuggable. Please try to keep the number of programming languages and systems involved to a minimum. Please use something with mature tooling including a debugger.
2. Builds should be self-contained and reproducible, as far as possible. Please do not pull in random system libraries unless I specifically ask for it. Please tell me what toolchain you are using and where it comes from. Please be explicit about all dependencies.
3. The build system should just get out of the way. Please do not invent a new language with rules like "everything (even a list of strings) is a string." Please do something very conventional. Please allow me to just set a compiler option for a file if I want to.

Coincidentally, both Unity's and Epic's internal build systems are quite close to this.

## What did I build?
I chose to write my build system in C#. Everything is C#: both the core code and the actual specification of build targets are just C# code (side note: I think this was a mistake; it should probably have been native code from the beginning). The build system is called "Swamp", because that is a fairly accurate description of how most build systems look to me: wet, muddy, dirty, sometimes more alive than the code it builds -- like a swamp. Swamp is currently tightly integrated with my own C++ monorepo, and you essentially just have to run `./bootstrap.bat` (minimal script to build Swamp) followed by `swamp build <target> <config>` to build whatever target you want.

Here are some Swamp facts:
 * Swamp currently only supports Windows (with emscripten in progress)
 * Swamp does not support "installing." Maybe this is a Windows-ism of mine, but I have never liked the notion of installing via CMake.
 * Swamp is incremental and only builds things that have changed and have not been built before. Swamp's lower layer deals with hashing of inputs to steps of the build process to cache all results, indefinitely.
 * Swamp supports generating Visual Studio solutions and projects, and their automatic regeneration when necessary.
 * I have ported all of my own applications to Swamp, plus a good bunch of external dependencies (e.g. mimalloc, Microsoft Detours, various audio codecs, lots of small libraries, now considering some meatier things).

## What did I learn from doing so?

 * I am now more familiar with build systems in general. I am always amazed at how quickly this sort of learning pays off unexpectedly: Within days of learning this, I needed to set up a multi-platform build for something entirely unrelated. I benefitted greatly from all the Visual Studio trivia I picked up in the process. For example, I never had a strong understanding what a "Visual Studio Project" actually is and how it relates to `msbuild`. Now I do, and it was immediately useful.
 * Caching results is really tricky with incremental work. Stuff like incremental linking keeps state around. Where does that state go? Do I associate that with build artifacts? Do I care that two identical inputs to the compilation process can now produce a different outcome? (I do not claim to have deterministic compilation otherwise -- I just figured that _for now_ "I don't care :)" is a good enough answer.)
 * The build system itself was not a lot of work, and the majority of the time was spent trying to avoid having to write Visual Studio projects. It was actually quite simple in the end and fits into the general theme of overestimating the work it takes to roll your own and underestimating the frustration you will experience by using someone else's solution. I ended up just writing "makefile projects", which are Visual Studio projects that just invoke a specific commandline for building. Otherwise I would have ended up not using my build system for building.
 * I would probably recommend people try just not use CMake but setting up their build in Make or msbuild instead. I was just too stubborn for that and went with my own build system, but the actual build scripts can be quite simple for most targets and even dependencies.
 * Most dependencies are easier to build manually than I expected.
 * Dependency handling is just as tricky as I expected. For example, I am hashing all dependencies of an artifact (e.g. all files that affect a single obj file) to determine whether the artiact needs to be built. There are a few annoying edge-cases, such as: Only the compiler can really tell me what files it needed. We only get that list of files _after_ compilation (compilers have flags to produce such a file). These are "late dependencies", which then change your hash. Does your system handle cases where a dependency changes _post_ compilation but _pre_ hashing? And since the compiler is the consumer of the dependencies but not the thing doing the hashing, do you also handle cases where inputs change _post_ hashing but _pre_ compilation? -- I ended up solving the fist conservatively ("if file changed post compilation by start time, poison the hash") and the second expensively (check if file potentially needs re-hashing, then hash but keep file handle open with read-only sharing allowed so no one can change the file during compilation).

In general I think I have mostly achieved my goals. I have completely deleted CMake from all of my projects. I still spend time on build stuff, but instead of hating that time (urgh, CMake) I now enjoy it (I get to fix bugs in Swamp, nice!).

That to me is the biggest take-away: I enjoy programming, I enjoy solving problems, but I do not enjoy just randomly poking at black boxes. I don't enjoy non-debuggable systems. I don't enjoy systems that make it hard for me to reason about what the machine is actually going to do. I don't enjoy systems that implicitly pull in a hundred different library paths without telling you ("because this makes it easy for users"). Yet somehow when you rely on a tool to solve your problems you often spend so much more time learning the idiosyncrasies of those tools instead of investing the same time into actually solving your problem. In the words of Eskil Steenberg: "In the beginning you always want results. In the end all you want is control." (from his talk [How I program C](https://www.youtube.com/watch?v=443UNeGrFoM))
