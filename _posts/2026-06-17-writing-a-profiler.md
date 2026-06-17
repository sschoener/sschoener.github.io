---
layout: post
title: Why I wrote a profiler
excerpt:
tags: []
---

I have written [a profiler for Windows](https://profiler.kerntief.net). It's called `ktp` until I find a better name ("kerntief profiler"). I want to provide some reasoning for why I have even gone down this path.

Some basic facts:
 * It's a Windows-only command-line profiler for now.
 * It requires zero per-project setup.
 * It supports sampling but also instrumentation, but not in the "manually compile markers into your program" kind of way. It instead inserts "probes" into functions at runtime. Any function can be hooked, and you can specify what a hook should do: capture a stacktrace, record timing, capture return values, capture the third field of the second parameter. All of this works without having to rebuild anything.
 * It supports sampling CPU performance counters on Windows. For example, it samples last level cache misses and uses this to estimate how much of the time CPU time is spent waiting on memory. It also allows you answer questions such as "which function is causing the most cache misses."
 * It's fully usable by LLM clankers, and that's very much the intended use-case. I know that some people will hate it (and me) for this on principle, and I'm fine with that. You can literally just say "Use the profiler in C:/path/to/profiler and figure out why whatever-you-want is slow" and it is well-documented enough such that an LLM will just figure everything out. That's pretty neat. There are also many small features and tweaks in and around the profiler to ensure that it is well-usable by an LLM without getting stuck or requiring a human to hold its hand.
 * Parts of the profiler are based on Event Tracing for Windows (ETW) and its ETL traces. The profiler hence also supports capturing a whole bunch of ETW events besides CPU samples like I/O events. It also adds a layer on top of the raw samples to reconstruct a timeline, e.g. to measure how much blocked time a function is responsible for.

Why write another profiler? The first and most important answer is: Because I can't help it. I am using profilers so much that not writing a profiler was never an option. This is not even the first profiler I wrote to scratch that itch, but certainly the most competent one of mine yet.

This particular incarnation actually reaches back by a few years when I profiled another profiler and came to the conclusion that it could resolve traces much faster if it had its own bespoke ETL parser. That set me down the path to write such a parser. Compared to the built-in ETL tooling that ships with Windows (or is available via nugets), my profiler resolves traces somewhere between 6x-8x times faster -- assuming you have downloaded all debug symbols already, otherwise that will be the slow part across all tools.

Second, I want a tool that blurs the line between "performance analysis" and "debugging" a little bit more. A profiler is a debugging tool, and sometimes you just happen to debug performance issues. Traditional debuggers and profilers just sit on different ends of a spectrum: Debuggers are microscopes, profilers are X-ray machines.

The vast majority of performance problems that people encounter are not of the form "this loop needs to be manually rewritten in assembly." Such problems indeed require microscopes. But if you want to understand "why is this happening AT ALL?" or "which file are we opening 600 times here?" you usually need to look at the larger picture and capture more than just timing information (if you even still care about that at all).

The reality is that you probably work on software that you only partially control and you now need to get a random piece of information. Rebuilding your software to add instrumentation takes 20 minutes in the best case, if you even have the necessary source files. So when I next find myself in that very situation, I now have a profiler that I can reach for.