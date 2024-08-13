---
layout: post
title: Collecting Callstacks
excerpt:
tags: []
---

I have a leak-tracking allocator for my personal C++ codebase. It records all allocations (except the ones it is making) by capturing a stack trace for every allocation, puts those traces into a hashmap, and then deletes the entries when the allocations are freed. Then on program shutdown (or any other time, really), we can inspect all leaks. There are probably better ways to do this but for now I just needed something simple.

My codebase forbids standard-library includes in headers and generally strives to be free of the standard library. It's generally a very conservative C++ codebase (e.g. no destructors, no inheritance) and I hope to move it all over to pure C eventually. However, in this case I remembered that in one particular codebase I worked with in the past, the callstack collection logic was really nasty and I did not have the endurance for "nasty" that evening. So I thought: "_Why not try std::stacktrace?_", which was added in C++23.

It turns out that `std::stacktrace` on MSVC allocates a vector internally, and this is very slow in debug builds (and elsewhere). My application usually sits comfortably below 100MB of memory usage, but with `std::stacktrace` it jumps up to 9.4GB committed memory on startup. That's also why it takes 26s to register allocations in the leak-tracking allocator: the sheer amount of memory requested leads to lots of page-faults, and if I were not using mimalloc I would probably pay more still.

This was enough motivation to look at manually collecting and printing callstacks, and it turns out to be much simpler to do this (on Windows) than I remembered. Windows offers two different APIs: `RtlCaptureStackBackTrace` and `StackWalk64`. The latter uses unwind instructions (which is a sort of mini-language that tells exception handlers how to unwind the stack) and PDBs to correctly walk stackframes in more scenarios. Swapping to `StackWalk64` immediately brings down memory usage to ~200MB and "only" takes 1.5s. The main gains are that I only keep 32 stackframes around and forgo the need of a vector. However, I have never observed needing more than 32 frames in my case either, so who knows what the other 9.2GB are used for. `RtlCaptureStackBackTrace` is much faster still and does the same thing in 32ms -- with the caveat that it might break. I have not observed that problem so far, even when omitting frame pointers and running more optimized builds. `StackWalk64` has the additional downside of requiring a lock, because it is part of the strictly single-threaded DbgHelp library. For now, I'll stick with `RtlCaptureStackBackTrace` and leave with the reassurance that it pays off to reinvent wheels for special cases.
