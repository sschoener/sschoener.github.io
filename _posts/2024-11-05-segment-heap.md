---
layout: post
title: How to enable the Windows Segment Heap
excerpt:
tags: []
---



If you have profiled Windows applications for any length of time, you will know that multi-threaded workloads on Windows often end up contending over some lock in the default Windows allocator. In the screenshot below (from the awesome [Superluminal profiler](https://superluminal.eu/)), you can see that in the top right there are two threads actively doing work at the same time, yet their bars are not completely green as you would want them to be. Instead, there is a red lining at the top, indicating that these threads actually spend a lot of time on synchronization -- i.e. trying to acquire locks, waiting for signals. Then towards the bottom left, you can see that we spend roughly 950ms on synchronization -- and the majority of this is coming from trying to enter a Critical Section. That's the Windows version of a mutex. Looking at the callers, they all come from allocation functions that pass through `AllocatorNTHeapInternal`. Note the `NTHeap`.

![NT Heap](/assets/img/2024-11-05-segment-heap/nt-heap.png)

If only there was a better way to allocate! Maybe an allocator implementation that knows that multi-threaded workloads are quite common and that software often allocates wildly. If you have source access, you can switch to different allocators that are essentially plug-and-play (mimalloc, jemalloc, tcmalloc are all worth trying!) -- or rewrite your program to not allocate like this anymore, of course. That would be the preferred option, but in the context of large software also often organizationally infeasible. Personally, I have had great success with mimalloc in the past but others have reported issues with mimalloc on ARM platforms.

Since Windows 10 there are two different heap implementation available for the default heap allocation functions. There is the NT Heap and then there is the Segment Heap. The Segment Heap seems to be friendlier for multi-threaded workloads, but the original goal of the Segment Heap was to reduce memory footprint. This [Github discussion](https://github.com/microsoft/Windows-Dev-Performance/issues/39) suggests that the Segment Heap can be slower in some scenarios, and the Windows developers really don't want you to expect it to be faster or start relying on such an expectation. From what I have seen, the segment heap is certainly worth at least testing when you cannot change the program at hand.

If this is your application, you can enable the new segment heap via the [application manifest](https://learn.microsoft.com/en-us/windows/win32/sbscs/application-manifests). However, I am looking for a way to quickly test things and often cannot recompile the programs I am profiling. Luckily, there are some registry keys that you can set. I have learned about them from the [Windows 10 Segment Heap Internals talk](https://www.youtube.com/watch?v=hetZx78SQ_A&t=315s).

If you want to enable the segment heap per executable, set this registry key:
```
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\<YOUR EXECUTABLE NAME HERE>
 - FrontEndHeapDebugOptions (DWORD) = 0x08
```
That's a DWORD key (so 32bit). Bit 3 is set for enabling the segment heap. The executable name is literally the name of the executable, e.g. `Profiler.exe`. This will apply to _all_ executables of that name.

Let's talk about `FrontEndHeapDebugOptions` for a moment. This is a bit-field, and you can also explicitly disable the segment heap as an override. Possible values are here:
```
0x08 - enable segment heap
0x04 - disable segment heap (override). Useful when you globally enabled the segment heap but want to selectively disable it.
```

In "newer" Windows versions (since Windows 7, I believe?) you can also be more specific in what binaries you apply overrides to. You can't just filter by name, but also by path. This requires a slightly different setup. This is probably simpler to explain with a made-up example:

```
Computer\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe
- UseFilter (DWORD) = 0x1 -- non-zero value indicates that we use filters
- FrontEndHeapDebugOptions (DWORD) = 0x0 -- this is the default value to use for all notepad.exe, unless a filter matches
- FilterClause1 (KEY) -- this is a subkey of an arbitrary name that represents one filter clause
-- FilterFullPath (STRING) = "C:\Windows\notepad.exe" -- if an executable matches this precise path...
-- FrontEndHeapDebugOptions (DWORD) = 0x8 -- ...then apply these exact options
- FilterClause2 (KEY) -- this is another filter clause
-- FilterFullPath (STRING) = "C:\Windows\SysWOW64\notepad.exe" -- if an executable matches this precise path...
-- FrontEndHeapDebugOptions (DWORD) = 0x4 -- ...then apply these exact options
```

At the top-level, right below `notepad.exe`, we set up some default options for the heap and then also specify that we want to use a filter. Then there are subkeys whose names don't matter (I've called them `FilterClause1` and `FilterClause2`) that allow you to override settings for specific paths. You specify the full path of your binary in `FilterFullPath` and then put whatever options you want next to it.

If you want to enable the segment heap globally, set
```
HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Segment Heap
Enabled (DWORD) = 1
```

To satisfy my curiosity, I have enabled the segment heap for the program that had the contention problem above. Note that the picture below is *not* an apples-to-apples comparison to the picture above: I don't have the source, I don't have symbols, I have imperfect knowledge about what the app is doing, I am comparing completely different timeranges. However, the scenario is similar: there are two threads that are both allocating, as before, and they _do not_ constantly contend over a lock in the heap allocator. (They both still spend a lot of their time on just allocating things.) Looking at the calltree, it is evident that we are now using a different implementation behind the scenes:

![Segment Heap](/assets/img/2024-11-05-segment-heap/segment-heap.png)

If you try this, please do report back on your measurements. I have some more ideas for how to improve allocation performance when you cannot control the program yourself, but this will have to wait until another time.


