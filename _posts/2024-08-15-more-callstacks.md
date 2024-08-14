---
layout: post
title: Collecting MORE Callstacks
excerpt:
tags: []
---

My last note dealt with collecting callstacks on Windows. As so often, I learned a bunch from what everyone else had to say about it, so here is the collectiong of the things I have learned.

First, I took mimalloc out of my program and returned to the default allocator. The original `std::callstack` logic then runs in 11s (down from 26s) which is nice but ultimately not enough when I could get multiple order of magnitudes by implementing it manually. This variant still allocates 4.6GB (down from 9.2GB), which is nice but again not good enough. So in this particular case, mimalloc is slower and more wasteful than the default allocator, interestingly. I have no good explanation for it, but the effect reproduces consistently on my machine.

[Bartosz Taudul](https://mastodon.gamedev.place/@wolfpld) pointed out that `RtlCaptureStackBackTrace` is implemented in terms of `RtlWalkFrameChain`, which you can also call. I did not find a difference in performance. Looking at the implementation of `RtlCaptureStackBackTrace`, it's evident that at least on relatively recent versions of Windows it's a thin wrapper around `RtlWalkFrameChain`. More interesting, this also reveals that the "callstack hash" it optionally computes is really just the sum of the addresses of the captured frames. I wonder how many cases there are where this causes false-positives.

`RtlWalkFrameChain` is terrible to google for and largely undocumented, but it is quite straight-forward to call once you have resolved it from `ntdll.dll` (using `GetProcAddress`). It can be found on Github as part of [PHNT](https://github.com/winsiderss/phnt/blob/master/ntrtl.h#L8725).

```cpp
#define RTL_WALK_USER_MODE_STACK 0x00000001
#define RTL_WALK_VALID_FLAGS 0x00000001
#define RTL_STACK_WALKING_MODE_FRAMES_TO_SKIP_SHIFT 0x00000008

// private
NTSYSAPI
ULONG
NTAPI
RtlWalkFrameChain(
    _Out_writes_(Count - (Flags >> RTL_STACK_WALKING_MODE_FRAMES_TO_SKIP_SHIFT)) PVOID *Callers,
    _In_ ULONG Count,
    _In_ ULONG Flags
);
```

The only noteworthy detail is that the number of frames to skip are shifted into the upper bits of the `Flags`. The flags (you can only set `RTL_WALK_USER_MODE_STACK`) are otherwise irrelevant. `RtlCaptureStackBackTrace` does not set `RTL_WALK_USER_MODE_STACK` and it's probably only relevant for kernel mode callers.

[Josh Simmons](https://mastodon.gamedev.place/@dotstdy@mastodon.social) dug up the original rationale for the design of `std::callstack` to understand how we got here, found in [A Proposal to add stacktrace library](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2020/p0881r7.html):

> Current design assumes that by default users wish to see the whole stack and OK with dynamic allocations, because do not construct stacktrace in performance critical places. For those users, who wish to use stacktrace on a hot path or in embedded environments `basic_stacktrace` allows to provide a custom allocator that allocates on the stack or in some other place, where users thinks it is appropriate.

I personally will not go down the route of `basis_stacktrace`, because it means adding another layer of complexity to optimize some code that I did not want to have in the first place. What I take away from this is that I am not the intended user, and that is fine. That is probably true for most of the standard library: I don't so much think that the entire thing is "terrible", if only because I do not have the nerve or time for the inevitable discussion this would prompt. No, it's just a thing that I am not the intended user for and that's where it usually stops being my problem.

Finally, [Doug Binks](https://mastodon.gamedev.place/@dougbinks) pointed out [Fredrik Kihlander's](https://mastodon.gamedev.place/@wcduck) Github repository [dbgtools](https://github.com/wc-duck/dbgtools). It's a small cross-platform library that has logic for collecting callstacks among other things. The interfaces are nice and clean and you bring your own buffers everywhere, which is all I wanted in the first place.
