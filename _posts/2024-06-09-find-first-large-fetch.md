---
layout: post
title: How much does FIND_FIRST_EX_LARGE_FETCH help?
excerpt:
tags: []
---

Today, while looking at something rather unrelated, I stumbled over `FIND_FIRST_EX_LARGE_FETCH`. It's a flag you can pass to `FindFirstFileEx` ([FindFirstFileEx MSDN](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-findfirstfileexw)) to use bigger buffers internally, reduce the number of trips to the device, and ultimately trade memory for performance (sometimes). I somehow never noticed this flag. Raymond Chen has [a short piece on when to use it](https://devblogs.microsoft.com/oldnewthing/20131024-00/?p=2843), which also outlines the subtleties of why this might not always be faster. Raymond's post is pure gold as usual:

> Far be it for MSDN to tell you how to write your application; the job of function-level documentation is to document the function. If you want advice, go see a therapist.

So, back to `FIND_FIRST_EX_LARGE_FETCH`. Raymond mentions that it is great for when you want to enumerate everthing, especially on slow drives, though he does not say how much faster it could be. "But who has slow drives in 2024?" Well, first off "slow" is relative, and second _I do_! My personal machine is more than 11 years old by now and has an HDD.

Sidenote: I am sure someone will tell me to upgrade and stop wasting my life on things, but the machine holds up nicely in most regards, at least for someone who only really uses IDE-like tools and a browser. I should probably get an SSD some time but so far there have been more important things in my life to fix. I have also been spending a lot of time fixing up my neighbor's machine and networks, and his machine is older still. It is a good perspective to have that some people still use machines with 3GB RAM, and there is this excruciating slowness that is distinct for non-stop hard pagefaults. Anyone working with software should at least sometimes seek out work with older machines and then repent for the collective sins of us programmers for failing 80 year olds who just want to print their files. But hey, it _is_ a nice opporunity to spend some time with my lovely neighbor.

I have a program that needs to enumerate parts of my drive to collect all files there. It is using `FindFirstFileEx`. (For reasons, I cannot directly read the NTFS entries, which may or may not be faster. For all I know, this approach works really well for reading the _entire_ partition, though then you presumably need to reconstruct the file system manually to filter down.) In my setup, I am using [RAMMap by SysInternals](https://learn.microsoft.com/en-us/sysinternals/downloads/rammap) to ensure that no previously accessed files are still mapped to memory, otherwise repeated runs of the program would be pretty much instantenous. In RAMMap, use `Empty Standby List` in the `Empty` menu to achieve this. My program does a parallel enumeration of the file system (start at a folder, then put every subfolder into a workqueue for other queues to pick up while processing the files in the current directory in the current thread), combined with some light filtering before collecting the results.

On my machine, the workload takes 54.7s walltime without `FIND_FIRST_EX_LARGE_FETCH`. With `FIND_FIRST_EX_LARGE_FETCH` the total duration goes down to 27.8s walltime, which is almost 2x faster. In both cases that is across 7 threads, with 99%+ of time going into waiting for I/O and everything else basically idling. The time spent in `FindFirstFileExW` goes from 252s to 164.6s (that's total time across 7 threads), but the real win is in `FindNextFileW`: from 128s down to 29s. Makes sense, since a larger buffer means that this latter function will not need to query the device as often. I have briefly looked at the difference in memory usage, but have not found anything significant beyond noise.