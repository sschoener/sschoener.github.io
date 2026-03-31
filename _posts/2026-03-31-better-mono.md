---
layout: post
title: Better codegen for Unity games on Mono
excerpt:
tags: []
---

tl;dr: I am tinkering with improved codegen for Mono to get better performance in the Unity Editor and in Unity games that ship with Mono as their runtime. Not done yet, but please do get in touch if you are interested in this (mail@s-schoener.com).

Unity has for a very long time relied on the Mono runtime for C# to run its editor (and sometimes its games). Mono was not made for games and its codegen is often not competitive with either native code or more modern jit-compilers. The official dotnet runtime CoreCLR frequently runs circles around Mono in terms of performance. Unity's IL2CPP runtime generally also outperforms Mono, since IL2CPP can just rely on the C++ compilers for its target platform.

Some folks however need to ship their game on Mono. The main reason for doing that is mod support: Mono makes it very easy to load new code at runtime and even patch, hook, and redirect existing parts of the code. (Read about it [here]({% post_url 2019-06-23-best-worst-code %}).) In the Unity editor, there is no way around Mono anyway.

Unfortunately, Unity has never invested into Mono, and with CoreCLR on the horizon that seems less likely than ever. I have been complaininig about Mono's codegen for close to ten years now, so it's not like this has been an unknown.

That was finally reason enough for me to try and improve the codegen for Mono (on Windows x64 specifically), and there is quite a bit I was able to do. If like so many you can't just directly upgrade to Unity 6.8 the moment it will ship because you already have a working product, then this is for you.

The improvements are significant. It's not quite on the level of Burst or CoreCLR's compiler of course, but it is much better than what Mono does by itself. You can find some code comparison at the end of the post.

One caveat: As with [cpp2better]({% post_url 2025-11-04-cpp2better-release %}) (my tool that improves codegen for il2cpp) the improvements you observe in any specific project are hard to predict. Improved codegen only leads to improved performance if your game is CPU compute-bound in some places (and doesn't just wait for memory all of its time). I have more thoughts about this [here]({% post_url 2025-12-04-when-does-cpp2better-help %}). The good (???) news is that Mono's codegen by default is so bad that you are likely CPU compute-bound somewhere if you try to write performant code.

Excellent targets usually are simulation games or games that make heavy use of DOTS/Entities. Mono's codegen is especially bad for struct-heavy code, so if your code uses `Vector3`, you are affected :)

As with cpp2better, all of this has the nice property that you don't need to change *anything* about your game for this to work. You just need to drop in a new Mono runtime into your game's build, and you're done! Then you may still want to tweak what optimizations you enable specifically. For "Debug" builds, all optimizations are disabled anyway. But for "Release" mode, you can still check which optimizations make the most sense for you. (Adding optimizations costs a little bit of time during JIT compilation, so there is a balance to strike.)

In games, the upside of better performance is obvious.

In the editor, there are a couple of upsides:
 * you still have to run your game and possibly also a client *and* a server, so performance is still very relevant,
 * you get performance in the editor that is closer to what you'd see in an il2cpp build,
 * you can avoid or delay porting code to Burst because the baseline behavior is better, which means less waiting on Burst,

If you are a game studio and improved Mono performance for your game or Unity editor sounds like something you are interested in, get in touch. (Full transparency: the goal is to make money with this.)

### Some codegen comparison
Here is a function from Unity's Entities graphics package. It's just one from the vast corpus of functions that I have looked at to evaluate codegen. The function is not really all that special and Mono struggles with this no more than it does with a Unity function that just uses, say, Unity's Vector3. The improved version with my modified Mono is an order of magnitude faster. Here is the source code for this function:

```csharp
private static float4 dot4(float4 xs, float4 ys, float4 zs, float4 mx, float4 my, float4 mz)
{
    return xs * mx + ys * my + zs * mz;
}
```

Here is the original codegen. It suffers from float-to-double conversions and lots of temporaries that Mono can't eliminate. Warning, it's LONG.

```
push rbp
mov rbp, rsp
sub rsp, 0x170
mov [rbp-0x8], rcx
mov [rbp-0x160], rdx
mov [rbp-0x168], r8
mov [rbp-0x170], r9
mov rax, [rbp-0x160]
movsxd rcx, dword [rax]
mov [rbp-0x148], ecx
movsxd rcx, dword [rax+0x4]
mov [rbp-0x144], ecx
movsxd rcx, dword [rax+0x8]
mov [rbp-0x140], ecx
movsxd rax, dword [rax+0xc]
mov [rbp-0x13c], eax
mov rax, [rbp+0x30]
movsxd rcx, dword [rax]
mov [rbp-0x138], ecx
movsxd rcx, dword [rax+0x4]
mov [rbp-0x134], ecx
movsxd rcx, dword [rax+0x8]
mov [rbp-0x130], ecx
movsxd rax, dword [rax+0xc]
mov [rbp-0x12c], eax
movss xmm0, dword [rbp-0x148]
cvtss2sd xmm0, xmm0
movss xmm1, dword [rbp-0x138]
cvtss2sd xmm1, xmm1
movsd xmm3, xmm0
mulsd xmm3, xmm1
movss xmm0, dword [rbp-0x144]
cvtss2sd xmm0, xmm0
movss xmm1, dword [rbp-0x134]
cvtss2sd xmm1, xmm1
movsd xmm2, xmm0
mulsd xmm2, xmm1
movss xmm0, dword [rbp-0x140]
cvtss2sd xmm0, xmm0
movss xmm4, dword [rbp-0x130]
cvtss2sd xmm4, xmm4
movsd xmm1, xmm0
mulsd xmm1, xmm4
movss xmm0, dword [rbp-0x13c]
cvtss2sd xmm0, xmm0
movss xmm4, dword [rbp-0x12c]
cvtss2sd xmm4, xmm4
mulsd xmm0, xmm4
mov dword [rbp-0x128], 0x0
mov dword [rbp-0x124], 0x0
mov dword [rbp-0x120], 0x0
mov dword [rbp-0x11c], 0x0
cvtsd2ss xmm5, xmm3
movss [rbp-0x14c], xmm5
cvtsd2ss xmm5, xmm2
movss [rbp-0x150], xmm5
cvtsd2ss xmm5, xmm1
movss [rbp-0x154], xmm5
cvtsd2ss xmm5, xmm0
movss [rbp-0x158], xmm5
movss xmm0, dword [rbp-0x14c]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0x128], xmm5
movss xmm0, dword [rbp-0x150]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0x124], xmm5
movss xmm0, dword [rbp-0x154]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0x120], xmm5
movss xmm0, dword [rbp-0x158]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0x11c], xmm5
movsxd rax, dword [rbp-0x128]
mov [rbp-0x58], eax
movsxd rax, dword [rbp-0x124]
mov [rbp-0x54], eax
movsxd rax, dword [rbp-0x120]
mov [rbp-0x50], eax
movsxd rax, dword [rbp-0x11c]
mov [rbp-0x4c], eax
mov rax, [rbp-0x168]
movsxd rcx, dword [rax]
mov [rbp-0x118], ecx
movsxd rcx, dword [rax+0x4]
mov [rbp-0x114], ecx
movsxd rcx, dword [rax+0x8]
mov [rbp-0x110], ecx
movsxd rax, dword [rax+0xc]
mov [rbp-0x10c], eax
mov rax, [rbp+0x38]
movsxd rcx, dword [rax]
mov [rbp-0x108], ecx
movsxd rcx, dword [rax+0x4]
mov [rbp-0x104], ecx
movsxd rcx, dword [rax+0x8]
mov [rbp-0x100], ecx
movsxd rax, dword [rax+0xc]
mov [rbp-0xfc], eax
movss xmm0, dword [rbp-0x118]
cvtss2sd xmm0, xmm0
movss xmm1, dword [rbp-0x108]
cvtss2sd xmm1, xmm1
movsd xmm3, xmm0
mulsd xmm3, xmm1
movss xmm0, dword [rbp-0x114]
cvtss2sd xmm0, xmm0
movss xmm1, dword [rbp-0x104]
cvtss2sd xmm1, xmm1
movsd xmm2, xmm0
mulsd xmm2, xmm1
movss xmm0, dword [rbp-0x110]
cvtss2sd xmm0, xmm0
movss xmm4, dword [rbp-0x100]
cvtss2sd xmm4, xmm4
movsd xmm1, xmm0
mulsd xmm1, xmm4
movss xmm0, dword [rbp-0x10c]
cvtss2sd xmm0, xmm0
movss xmm4, dword [rbp-0xfc]
cvtss2sd xmm4, xmm4
mulsd xmm0, xmm4
mov dword [rbp-0xf8], 0x0
mov dword [rbp-0xf4], 0x0
mov dword [rbp-0xf0], 0x0
mov dword [rbp-0xec], 0x0
cvtsd2ss xmm5, xmm3
movss [rbp-0x158], xmm5
cvtsd2ss xmm5, xmm2
movss [rbp-0x154], xmm5
cvtsd2ss xmm5, xmm1
movss [rbp-0x150], xmm5
cvtsd2ss xmm5, xmm0
movss [rbp-0x14c], xmm5
movss xmm0, dword [rbp-0x158]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0xf8], xmm5
movss xmm0, dword [rbp-0x154]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0xf4], xmm5
movss xmm0, dword [rbp-0x150]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0xf0], xmm5
movss xmm0, dword [rbp-0x14c]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0xec], xmm5
movsxd rax, dword [rbp-0xf8]
mov [rbp-0x48], eax
movsxd rax, dword [rbp-0xf4]
mov [rbp-0x44], eax
movsxd rax, dword [rbp-0xf0]
mov [rbp-0x40], eax
movsxd rax, dword [rbp-0xec]
mov [rbp-0x3c], eax
movsxd rax, dword [rbp-0x58]
mov [rbp-0xe8], eax
movsxd rax, dword [rbp-0x54]
mov [rbp-0xe4], eax
movsxd rax, dword [rbp-0x50]
mov [rbp-0xe0], eax
movsxd rax, dword [rbp-0x4c]
mov [rbp-0xdc], eax
movsxd rax, dword [rbp-0x48]
mov [rbp-0xd8], eax
movsxd rax, dword [rbp-0x44]
mov [rbp-0xd4], eax
movsxd rax, dword [rbp-0x40]
mov [rbp-0xd0], eax
movsxd rax, dword [rbp-0x3c]
mov [rbp-0xcc], eax
movss xmm0, dword [rbp-0xe8]
cvtss2sd xmm0, xmm0
movss xmm1, dword [rbp-0xd8]
cvtss2sd xmm1, xmm1
movsd xmm3, xmm0
addsd xmm3, xmm1
movss xmm0, dword [rbp-0xe4]
cvtss2sd xmm0, xmm0
movss xmm1, dword [rbp-0xd4]
cvtss2sd xmm1, xmm1
movsd xmm2, xmm0
addsd xmm2, xmm1
movss xmm0, dword [rbp-0xe0]
cvtss2sd xmm0, xmm0
movss xmm4, dword [rbp-0xd0]
cvtss2sd xmm4, xmm4
movsd xmm1, xmm0
addsd xmm1, xmm4
movss xmm0, dword [rbp-0xdc]
cvtss2sd xmm0, xmm0
movss xmm4, dword [rbp-0xcc]
cvtss2sd xmm4, xmm4
addsd xmm0, xmm4
mov dword [rbp-0xc8], 0x0
mov dword [rbp-0xc4], 0x0
mov dword [rbp-0xc0], 0x0
mov dword [rbp-0xbc], 0x0
cvtsd2ss xmm5, xmm3
movss [rbp-0x14c], xmm5
cvtsd2ss xmm5, xmm2
movss [rbp-0x150], xmm5
cvtsd2ss xmm5, xmm1
movss [rbp-0x154], xmm5
cvtsd2ss xmm5, xmm0
movss [rbp-0x158], xmm5
movss xmm0, dword [rbp-0x14c]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0xc8], xmm5
movss xmm0, dword [rbp-0x150]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0xc4], xmm5
movss xmm0, dword [rbp-0x154]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0xc0], xmm5
movss xmm0, dword [rbp-0x158]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0xbc], xmm5
movsxd rax, dword [rbp-0xc8]
mov [rbp-0x38], eax
movsxd rax, dword [rbp-0xc4]
mov [rbp-0x34], eax
movsxd rax, dword [rbp-0xc0]
mov [rbp-0x30], eax
movsxd rax, dword [rbp-0xbc]
mov [rbp-0x2c], eax
mov rax, [rbp-0x170]
movsxd rcx, dword [rax]
mov [rbp-0xb8], ecx
movsxd rcx, dword [rax+0x4]
mov [rbp-0xb4], ecx
movsxd rcx, dword [rax+0x8]
mov [rbp-0xb0], ecx
movsxd rax, dword [rax+0xc]
mov [rbp-0xac], eax
mov rax, [rbp+0x40]
movsxd rcx, dword [rax]
mov [rbp-0xa8], ecx
movsxd rcx, dword [rax+0x4]
mov [rbp-0xa4], ecx
movsxd rcx, dword [rax+0x8]
mov [rbp-0xa0], ecx
movsxd rax, dword [rax+0xc]
mov [rbp-0x9c], eax
movss xmm0, dword [rbp-0xb8]
cvtss2sd xmm0, xmm0
movss xmm1, dword [rbp-0xa8]
cvtss2sd xmm1, xmm1
movsd xmm3, xmm0
mulsd xmm3, xmm1
movss xmm0, dword [rbp-0xb4]
cvtss2sd xmm0, xmm0
movss xmm1, dword [rbp-0xa4]
cvtss2sd xmm1, xmm1
movsd xmm2, xmm0
mulsd xmm2, xmm1
movss xmm0, dword [rbp-0xb0]
cvtss2sd xmm0, xmm0
movss xmm4, dword [rbp-0xa0]
cvtss2sd xmm4, xmm4
movsd xmm1, xmm0
mulsd xmm1, xmm4
movss xmm0, dword [rbp-0xac]
cvtss2sd xmm0, xmm0
movss xmm4, dword [rbp-0x9c]
cvtss2sd xmm4, xmm4
mulsd xmm0, xmm4
mov dword [rbp-0x98], 0x0
mov dword [rbp-0x94], 0x0
mov dword [rbp-0x90], 0x0
mov dword [rbp-0x8c], 0x0
cvtsd2ss xmm5, xmm3
movss [rbp-0x158], xmm5
cvtsd2ss xmm5, xmm2
movss [rbp-0x154], xmm5
cvtsd2ss xmm5, xmm1
movss [rbp-0x150], xmm5
cvtsd2ss xmm5, xmm0
movss [rbp-0x14c], xmm5
movss xmm0, dword [rbp-0x158]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0x98], xmm5
movss xmm0, dword [rbp-0x154]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0x94], xmm5
movss xmm0, dword [rbp-0x150]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0x90], xmm5
movss xmm0, dword [rbp-0x14c]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0x8c], xmm5
movsxd rax, dword [rbp-0x98]
mov [rbp-0x28], eax
movsxd rax, dword [rbp-0x94]
mov [rbp-0x24], eax
movsxd rax, dword [rbp-0x90]
mov [rbp-0x20], eax
movsxd rax, dword [rbp-0x8c]
mov [rbp-0x1c], eax
movsxd rax, dword [rbp-0x38]
mov [rbp-0x88], eax
movsxd rax, dword [rbp-0x34]
mov [rbp-0x84], eax
movsxd rax, dword [rbp-0x30]
mov [rbp-0x80], eax
movsxd rax, dword [rbp-0x2c]
mov [rbp-0x7c], eax
movsxd rax, dword [rbp-0x28]
mov [rbp-0x78], eax
movsxd rax, dword [rbp-0x24]
mov [rbp-0x74], eax
movsxd rax, dword [rbp-0x20]
mov [rbp-0x70], eax
movsxd rax, dword [rbp-0x1c]
mov [rbp-0x6c], eax
movss xmm0, dword [rbp-0x88]
cvtss2sd xmm0, xmm0
movss xmm1, dword [rbp-0x78]
cvtss2sd xmm1, xmm1
movsd xmm3, xmm0
addsd xmm3, xmm1
movss xmm0, dword [rbp-0x84]
cvtss2sd xmm0, xmm0
movss xmm1, dword [rbp-0x74]
cvtss2sd xmm1, xmm1
movsd xmm2, xmm0
addsd xmm2, xmm1
movss xmm0, dword [rbp-0x80]
cvtss2sd xmm0, xmm0
movss xmm4, dword [rbp-0x70]
cvtss2sd xmm4, xmm4
movsd xmm1, xmm0
addsd xmm1, xmm4
movss xmm0, dword [rbp-0x7c]
cvtss2sd xmm0, xmm0
movss xmm4, dword [rbp-0x6c]
cvtss2sd xmm4, xmm4
addsd xmm0, xmm4
mov dword [rbp-0x68], 0x0
mov dword [rbp-0x64], 0x0
mov dword [rbp-0x60], 0x0
mov dword [rbp-0x5c], 0x0
cvtsd2ss xmm5, xmm3
movss [rbp-0x14c], xmm5
cvtsd2ss xmm5, xmm2
movss [rbp-0x150], xmm5
cvtsd2ss xmm5, xmm1
movss [rbp-0x154], xmm5
cvtsd2ss xmm5, xmm0
movss [rbp-0x158], xmm5
movss xmm0, dword [rbp-0x14c]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0x68], xmm5
movss xmm0, dword [rbp-0x150]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0x64], xmm5
movss xmm0, dword [rbp-0x154]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0x60], xmm5
movss xmm0, dword [rbp-0x158]
cvtss2sd xmm0, xmm0
cvtsd2ss xmm5, xmm0
movss [rbp-0x5c], xmm5
movsxd rax, dword [rbp-0x68]
mov [rbp-0x18], eax
movsxd rax, dword [rbp-0x64]
mov [rbp-0x14], eax
movsxd rax, dword [rbp-0x60]
mov [rbp-0x10], eax
movsxd rax, dword [rbp-0x5c]
mov [rbp-0xc], eax
mov rax, [rbp-0x8]
movsxd rcx, dword [rbp-0x18]
mov [rax], ecx
movsxd rcx, dword [rbp-0x14]
mov [rax+0x4], ecx
movsxd rcx, dword [rbp-0x10]
mov [rax+0x8], ecx
movsxd rcx, dword [rbp-0xc]
mov [rax+0xc], ecx
lea rsp, [rbp]
pop rbp
ret
```

Here is the improved version. It's not perfect either, but it is way, way, way better than the original (still no vectorcall, still some unnecssary spilling):
```
push	rbp
mov	rbp, rsp
sub	rsp, 0x90
mov	qword ptr [rbp - 0x8], rcx
mov	qword ptr [rbp - 0x80], rdx
mov	qword ptr [rbp - 0x88], r8
mov	qword ptr [rbp - 0x90], r9
mov	rax, qword ptr [rbp - 0x80]
movups	xmm0, xmmword ptr [rax]
mov	rax, qword ptr [rbp + 0x30]
movups	xmm1, xmmword ptr [rax]
mulps	xmm0, xmm1
mov	rax, qword ptr [rbp - 0x88]
movups	xmm1, xmmword ptr [rax]
mov	rax, qword ptr [rbp + 0x38]
movups	xmm2, xmmword ptr [rax]
mulps	xmm1, xmm2
addps	xmm0, xmm1
mov	rax, qword ptr [rbp - 0x90]
movups	xmm1, xmmword ptr [rax]
mov	rax, qword ptr [rbp + 0x40]
movups	xmm2, xmmword ptr [rax]
mulps	xmm1, xmm2
addps	xmm0, xmm1
mov	rax, qword ptr [rbp - 0x8]
movups	xmmword ptr [rax], xmm0
lea	rsp, [rbp]
pop	rbp
ret
```