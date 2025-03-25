---
layout: post
title: Nobody cares about vectorization?
excerpt:
tags: []
---

In a recent discussion around auto-vectorization someone suggested: "What if users could tell the compiler that they expect a loop to be vectorized?" We are in luck, that experiment has already been conducted. In particular, Unity's Burst compiler has an intrinsic for that (see [Burst docs](https://docs.unity3d.com/Packages/com.unity.burst@1.8/manual/optimization-loop-vectorization.html?q=ExpectVectorized)). Put `Loop.ExpectVectorized();` into a loop and you will get a compile error if it fails to auto-vectorize. I know why it is there; it's there because someone approached the Burst team and asked "can you please add that." Funnily enough, across many game projects that make heavy, heavy use of Burst I have not seen this intrinsic used even once. Some searching on GitHub shows just a single result where it is actually used, and it looks like a test at best.

So the answer to the original question then is "users will not care." Why do they not care? Do they not want faster code? I believe the answer is a little bit more nuanced.

How would you ever use the `Loop.ExpectVectorized` intrinsic and who is the ideal user? The ideal user for this intrinsic knows about vectorization (otherwise they would not bother using that intrinsic), they are unable or unwilling to write the vectorized code themselves, and they are still somehow capable of actually formulating a reasonable expectations about what code a compiler should be able to auto-vectorize. Then finally if some random change in your project breaks auto-vectorization, manifesting as a compile error, which breaks your build and leaves your entire team blocked for an entire day, then that user will also have to have a better answer than "I guess I'll just delete the `Loop.ExpectVectorized` then."

![Meme "Is this user in the room with us right now?"](../assets/img/2025-03-25-vectorization/user-in-the-room.png)

Joking aside, if you do use this intrinsic as a user (not a compiler developer!), please do reach out. I would love to understand how it fits into your workflows, because I lack the imagination to see how that would work.

It is very unlikely that someone has a good mental model of what loops they can expect a compiler to auto-vectorize and then decides to start playing russian roulette on the build farm instead of writing the vectorized code themselves. From experience, it is usually much harder to coax a compiler (or rather "all the compilers you are using across the many platforms you support") into always generating a vectorized form of a loop than to manually write something that is already in a vectorized form, either through intrinsics or through specifically designed data types. You need to be _more_ of an expert to predict what a compiler will do, not _less_ of an expert.

On a broader note, the point of auto-vectorization is that it is automatic. If I need to manually intervene and check, then that is not very automatic. Auto-vectorization is an opportunistic optimization, and you count on the compiler doing it where it makes sense without your intervention.

Another reason why people do not use that intrinsic might be that the cases where you can reasonably expect auto-vectorization in the "do 4 iterations of this loop at a time" sense are actually pretty rare, comparatively. I wrote about [the kernel theory of video game programming]({% post_url 2024-12-12-burst-kernel-theory-game-performance %}) earlier, and a similar point holds here: Across all of the many games I have seen, the idea that there are many gameplay loops you can naturally vectorize is just false. A team of experts can of course still carefully craft and design exactly that, but the average gameplay code does not consist of large loops of math. No, that code is way uglier. It is messy, and `if` is more important than `for`. The idea that your average game can be made 4x faster by just auto-vectorizing their loops (either by compiler or by getting AI to rewrite them) has no support in my entire life experience, even for games that have bought into all the ECS things. Are there games where that is possible and actually happening? Yes, sure. Are those most games? Absolutely not[^experts].

This is not to say that vectorization does not matter. Of course it does! A good example is Unity's culling code. It is written with `float4` from Unity's math package, and `float4` operations vectorize reasonably nicely, with the main exception being that for _some reason_ comparisons result in a 32bit-wide `bool4` type instead of a 128bit-wide mask, sigh[^bool4]. Vectorizing this culling code makes a massive difference. Yet nobody would ever rely on auto-vectorization for this, because it is so important that this code is vectorized.

Another example of vectorization, maybe even "auto"-vectorization, is any code that uses `float3` types. Gameplay logic usually contains plenty of logic about positions, distances, speed, movement, all of which is happening in 3D space. Those calculations are all over the place, everywhere, and most games I have seen do not pre-emptively construct `float4` on-the-fly everywhere to get better codegen. It's not top-of-mind for the gameplay programmer writing that code. If you toy around with `float3`-types for a while, you will notice that different compilers generate vastly different code for this: MSVC will do everything one-by-one. Clang vectorizes a little bit, and Burst will for the most part realize that it can often treat `float3` as a `float4` and generate much better code that way.

This notion of auto-vectorization, where a `float3` is automatically promoted to a `float4` (except for storage, of course), or even that your compiler recognizes that a naively defined `float4` should probably map to an `XMM` register, is _way_ more impactful for gameplay code than "auto-vectorize this loop." The speed-up that you get that way is not just 3x but frequently much more. The important bit is not that you do vectorized addition and handle 3 floats at a time instead of one. No, the important bit is that you no longer have 10 instructions in between that just shuffle data into the right places. *That* is the important part of vectorization for randomly picked gameplay code.

My claims here come from looking at codegen and performance across many games, and recently specifically comparing vector codegen across different compilers and platform. The naive example I will now give below is an illustration of the point, but not the point itself, but it still gives you a sense of why this is important:

```cpp
struct float3 {
    float x,y,z;
};

float3 addps(float3 a, float3 b) {
    float3 r;
    r.x = a.x + b.x;
    r.y = a.y + b.y;
    r.z = a.z + b.z;
    return r;
}

float3 mulps(float3 a, float3 b) {
    float3 r;
    r.x = a.x * b.x;
    r.y = a.y * b.y;
    r.z = a.z * b.z;
    return r;
}

float3 mul(float3 a, float b) {
    float3 r;
    r.x = a.x * b;
    r.y = a.y * b;
    r.z = a.z * b;
    return r;
}

float3 dothing(float3 a, float3 b, float x) {
    return addps(mul(a, x), mulps(a, b));
}
```
Compiling on x64 (hence SSE2), you get this code under `/O2` with MSVC (with or without `/fp:fast`, it has no bearing here):

```x86
float3 dothing(float3,float3,float) PROC           ; dothing, COMDAT
$LN10:
        sub     rsp, 40                             ; 00000028H
        movsd   xmm5, QWORD PTR [rdx]
        mov     rax, rcx
        movsd   xmm0, QWORD PTR [r8]
        movaps  xmm1, xmm5
        movss   xmm2, DWORD PTR [r8+4]
        mulss   xmm1, xmm3
        mulss   xmm0, xmm5
        movaps  XMMWORD PTR [rsp+16], xmm6
        movaps  xmm6, XMMWORD PTR [rsp+16]
        addss   xmm1, xmm0
        movaps  xmm0, xmm5
        shufps  xmm0, xmm0, 85                          ; 00000055H
        mulss   xmm2, xmm0
        movss   DWORD PTR [rcx], xmm1
        movaps  xmm1, xmm5
        shufps  xmm1, xmm1, 85                          ; 00000055H
        mulss   xmm1, xmm3
        addss   xmm2, xmm1
        movss   xmm1, DWORD PTR [rdx+8]
        mulss   xmm1, xmm3
        movss   DWORD PTR [rcx+4], xmm2
        movss   xmm2, DWORD PTR [r8+8]
        mulss   xmm2, DWORD PTR [rdx+8]
        addss   xmm2, xmm1
        movss   DWORD PTR [rcx+8], xmm2
        add     rsp, 40                             ; 00000028H
        ret     0
```

And here is the result with Clang (`-O11`):
```asm
dothing(float3, float3, float):
        movaps  xmm5, xmm1
        mulss   xmm5, xmm4
        mulss   xmm1, xmm3
        addss   xmm1, xmm5
        shufps  xmm4, xmm4, 0
        mulps   xmm4, xmm0
        mulps   xmm0, xmm2
        addps   xmm0, xmm4
        ret
```

Now imagine that this happens all over your codebase, everywhere. Which of the two kinds of codegen would you prefer? (Neither is great when read carefully, Clang splits the float3 across two registers, but one of them is better.) Also note that this is a simple case: nobody is XORing a `float3` with a bit mask to flip a sign, for example. Unity's math package has many such problems even in its internal code that will make MSVC choke, understandably so. Longer functions with more inlining give Clang's codegen a bigger and bigger advantage.

`float4` has a similar issue where MSVC will not naturally recognize it as something that can make use of vector instructions. The upside with `float4` is that it is reasonably simple to convince MSVC to emit the right code by manually putting some intrinsics in the right places. For the culling code for example, convincing MSVC to treat `float4` as a vector speeds up the code by more than 8x on my machine and results in codegen that is not noticeably worse than Burst's. As noted before, the 8x speed-up is not just because we have fewer arithmetic instructions but just as much because all the waste in between is suddenly gone.

For `float3`, I have not been able to convince MSVC to actually pretend that it is a vector. The biggest problem is that math libraries such as Unity's mathematics express the basic operations as functions with a `float3` return type. So you can temporarily convince MSVC to use a vectorized approach inside of the function, but returning from the function adds a choke-point. You'd really want to _first_ inline and _then_ expand to vectors. That is a good reason to prefer clang, if you can't change the programming abstraction (which I can't, because `float3` is what exists in Unity Mathematics).

In summary, my points:
 * Auto-vectorization needs to be automatic, and I fail to see how anyone (outside of compiler writers) would care to check for it instead of manually vectorizing.
 * The idea that a randomly chosen real game can be made significantly faster by somehow vectorizing all or many of its loops has zero support in my experience.
 * Vectorization is obviously still monumentally important for many parts of engine code and some systems can get much much faster.
 * For gameplay code, it is more important to have decent codegen for random math code that just happens everywhere, in particular automatic handling of naively defined float3/float4 types. Programmers tend to write `float3` code.

---

[^experts]: Note, I am not claiming that it is impossible to write code in a form that is more amendable to auto-vectorization, and I am also not claiming that it is impossible for an expert to come in and in a heroic effort spend a month of their life to rewrite a system and make it significantly faster by exploiting the hardware properly. It is just not what I see happening in the vast majority of cases, even when everyone is performance-sensitive and has bought into "vectorized code is great and everything should be data-oriented." This is a separate conversation and I personally love working directly with whatever intrinsics you hand me.

[^bool4]: I can see why `bool4` exists. It is mostly about reducing surprise: if comparing two `float` yields a `bool`, comparing two `float4` should yield a `bool4`. However, its existence and use is a massive slap in the face for any vectorized instruction set, and it requires a custom compiler (Burst) to un-screw this situation again and get back to using masks.