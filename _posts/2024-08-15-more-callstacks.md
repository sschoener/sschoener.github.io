---
layout: post
title: std::stacktrace, redeemed?
excerpt:
tags: []
---

My [last note]({% post_url 2024-08-13-callstacks %}) dealt with collecting callstacks on Windows. As so often, I learned a bunch from what everyone else had to say about it, so here is the collection of the things I have learned.

First, [Josh Simmons](https://mastodon.gamedev.place/@dotstdy@mastodon.social) dug up the original rationale for the design of `std::callstack` to understand how we got here, found in [A Proposal to add stacktrace library](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2020/p0881r7.html):

> Current design assumes that by default users wish to see the whole stack and OK with dynamic allocations, because do not construct stacktrace in performance critical places. For those users, who wish to use stacktrace on a hot path or in embedded environments `basic_stacktrace` allows to provide a custom allocator that allocates on the stack or in some other place, where users thinks it is appropriate.

I personally will not go down the route of `basis_stacktrace`, because it means adding another layer of complexity to optimize some code that I did not want to have in the first place. What I take away from this is that I am not the intended user, and that is fine.

Next, I took mimalloc out of my program for a moment and returned to the default allocator. The original `std::callstack` logic then runs in 11s (down from 26s), which I would attribute to it "only" allocating 4.6GB (down from 9.2GB). So in this particular case, mimalloc is slower and more wasteful than the default allocator, interestingly.

My curiosity overcame me at this point so I decided to just step into `std::callstack::current(1)` and see what happens. It first allocates a `std::vector<void*>` of size `_Max_Frames = 0xFFFF`, which explains the large memory usage. I can imagine that repeatedly allocating _that particular size_ could expose pathological codepaths in allocators, so maybe that is making mimalloc extra bad. Then it just calls into `RtlCaptureStackBackTrace`.

This small adventure also revealed that there is a version of `std::callstack::current` that allows you to pass in a maximum size for the callstack:

- Setting that to 32 brings down the time to a more reasonable 112ms (compared to 32ms for the handwritten version without a vector), back again on mimalloc.
- A generous maximum of 255 stack entries sits at around 187ms.

[Bartosz Taudul](https://mastodon.gamedev.place/@wolfpld) had previously looked at `RtlCaptureStackBackTrace` and poked at its internals. That prompted me to look at the implementation of `RtlCaptureStackBackTrace` as well. I learned three things:

1. At least on relatively recent versions of Windows, it's a thin wrapper around `RtlWalkFrameChain`. I saw no perf difference when using that directly.
2. The callstack "hash" it computes is really just the sum of the frame addresses (which Bartosz also observed earlier). I wonder whether this is an intentional choice, and if not how many cases there are where this causes false-positives. I do not use the hash and if you pass in null, the calculation is skipped.
3. The function explicitly checks whether you are asking it to skip more than `0xFE` frames, in which case it just exits immediately.

It would be sad to stop now and not also look under the hood of `RtlWalkFrameChain`. `RtlWalkFrameChain` is terrible to google for and largely undocumented, but it is quite straight-forward to call once you have resolved it from `ntdll.dll` (using `GetProcAddress`). It can be found on Github as part of [PHNT](https://github.com/winsiderss/phnt/blob/master/ntrtl.h#L8725).

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

The only noteworthy detail about this signature is that the number of frames to skip are shifted into the upper bits of the `Flags`. The flags (you can only set `RTL_WALK_USER_MODE_STACK`) are otherwise irrelevant: `RtlWalkFrameChain` throws them away immediately. The check against `0xFE` frames to skip that we saw earlier only exists because `RtlWalkFrameChain` adds one to that number. It presumably used to be 8 bits at some point, but is now 16 bits. `RtlWalkFrameChain` just ends up incrementing both inputs and calls into `RtlpWalkFrameChain`, which does some light setup and then repeatedly calls `RtlpVirtualUnwind`.

Someone mentioned that the operating system API might only returns callstacks up to a given length anyway, but that loop is only bounded by that size of the buffer we passed into the function, and there are no indications that anything else would stop legitimately deep callstacks from getting fully walked. In particular, a function such as the one below will correctly capture a deep stacktrace (in debug builds -- optimized builds do produce a different output here, in my case it's 1032 vs. 5):

```cpp
size_t Test(size_t x = 1024) {
    if (x == 0) {
        auto c = std::stacktrace::current();
        return c.size();
    }
    else
        return Test(x - 1);
}
```

Finally, [Doug Binks](https://mastodon.gamedev.place/@dougbinks) pointed out [Fredrik Kihlander's](https://mastodon.gamedev.place/@wcduck) Github repository [dbgtools](https://github.com/wc-duck/dbgtools). It's a small cross-platform library that has logic for collecting callstacks among other things. The interfaces are nice and clean and you bring your own buffers everywhere, which is all I wanted in the first place.

_UPDATE_: I have yet another follow-up post [here]({% post_url 2025-01-24-stack-walking-generated-code %}).