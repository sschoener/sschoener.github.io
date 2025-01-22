---
layout: post
title: A curious access violation
tags: []
---

_Hey! You can find me on [Mastodon](https://mastodon.gamedev.place/@sschoener) and [Bluesky](https://bsky.app/profile/sschoener.bsky.social)!_

Recently, while doing things I probably should not be doing in the first place, I ran into an access validation that really threw me off: 
```
0xC0000005: Access violation reading location 0xFFFFFFFFFFFFFFFF
```

It happened in a call to `CloseHandle`, so I looked at the assembly listing: We are attempting to write to `[RBP+0x170]`, where `RBP` is `0xC89C3FF4E8`. Uh, what? How do we get from that to `0xFFFFFFFFFFFFFFFF`? If you know the Windows x64 calling conventions really well, you probably already have alarm clocks ringing in your head.

I had to re-read the assembly not once, not twice, but three times before I figured out what is happening:

<p align="middle">
  <img src="/img/2025-01-17-access-violation-aligned-access/movaps.png" alt="" />
</p>

We're writing using `movaps`! That address is supposed to be aligned, and it is not. That is causing the access violation. The debugger is then just presenting the wrong address: We're not trying to write to `0xFFFFFFFFFFFFFFFF`, that's a red heFFFFFFFFFFFFFFFFing.

How did that happen? Well, that's my fault. _For reasons_, I am writing to a bit of shellcode that I load into another process. `Slack.exe` is just my guinea pig here; I don't particularly care about it except that it is a process I have always running. The last time I actively wrote shellcode was 15 years ago on an x86 machine, and I did not apply the care that I should have applied on x64.

On x64, outside of the function prologue and epilogue, the stack must *always* be aligned to 16 bytes (except in leaf functions). I never realized it before, but that means you cannot use `push` or `pop` outside of the epilogue and prologue. When you call a function, the stack _was_ aligned to 16 bytes, but then the call has pushed `RSP` onto the stack, and it is not aligned anymore, it is off by 8 bytes. So you *have* to put something on the stack to align it again. The Windows x64 calling convention requires you to also reserve 32 bytes of "shadow space" for the functions you call (those are just some bytes so the functions you call can save some registers, if they want to), but that alone is insufficient to re-align the stack: `32 = 0x20` doesn't change the alignment mod 16.

Side note: If you let your x86 habits take the better of you, you might forget to allocate the shadow space and find out that your return address is suddenly overwritten. Fun! Another technicality with this sort of codegen is that the calling convention *requires* you to place unwind information somewhere if your function has a prologue ([x64 prolog and epilog MSDN page](https://learn.microsoft.com/en-us/cpp/build/prolog-and-epilog?view=msvc-170)). If your function is not a leaf, then you are guaranteed to have a prologue because you need to align the stack (and you need to allocate the shadow space). So far, I have ignored this requirement and not generated any unwind information, and I'm curious to see when exactly that poor choice will come back to bite me.

{% include clickable-image.html %}