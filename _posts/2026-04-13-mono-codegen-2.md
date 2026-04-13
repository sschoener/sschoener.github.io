---
layout: post
title: What I learned from improving Unity's Mono codegen, part 2
excerpt:
tags: []
---

My [current sidequest]({% post_url 2026-03-31-better-mono %}) is to improve the codegen for Unity games (and the editor) running on Mono. This post is a continuation of [last week's post]({% post_url 2026-04-07-mono-codegen-1 %}) about this journey.

## To LLVM or not to LLVM?
The first decision I had to make was what to actually do about any of this. Unity's Mono has a very much WIP path for routing codegen through LLVM. This would likely provide much more comprehensive optimizations and better codegen than I can build manually. Then again, that is what Unity's Burst already doing by routing IL through LLVM's IR and generate code that way. For Burst, this is slow and heavy-handed.

The alternative is to write the optimization passes themselves. In retrospect, this was a choice between "pick up the janitorial duties of hooking up LLVM" or "do the actually interesting bits myself." I am not sure why I ever hesitated. I am quite happy with this choice, as I would rather learn more about writing an optimizing compiler in general rather than getting intimately familiar with whatever build and plumbing problems an LLVM migration would throw at me.

That's a common theme in my work: not having dependencies is not just simpler, but also more fun. You replace a dreadful problem (dependency management) with a joyful one (the cool thing you actually want to do).

## x64 or Mono IR?
A similar choice presented itself when I had to decide where to add optimization passes in the pipeline. My original thinking was that I would like to insert passes as late as possible: In the later stages of the pipeline, we are just dealing with x64 assembly, and I am very comfortable with that. It felt like a natural place to work, and it would avoid having to learn much about Mono's internals.

This was ultimately not what I ended up doing. First, working with the backend taught me a bunch of things about Mono and made me comfortable enough to attack earlier parts of the pipeline. Second, the later you remove some junk from codegen, the more time it has to do damage. If you already know that something is redundant in the first step, then don't wait until the fifteenth to remove it. Third, later stages carry less information and make your life harder: It is much easier to reason about "these two locals, who are guaranteed to be separate" vs. "these two byte ranges, which may or may not overlap."

## Aliasing, again and again
It turns out that almost all the optimizations I am interested in require decent "alias analysis", which is fancy speak for reasoning about whether two pointers reference the same data. Do you want to turn a byte-by-byte memcpy into a chunked memcpy? Better check that source and destination don't overlap. Want to remove a struct copy? Better figure out whether someone modifies the original data after we have copied it, and that mostly means figuring out whether any store-to-memory goes through a pointer that aliases the original data. Want to remove a store to memory? Better check that nobody is loading it through a pointer that aliases with the store target.

Alias analysis is much harder late in the codegen pipeline: on a concrete machine, you have to prove that two byte ranges can't possibly overlap. In an abstract model, two local variables do not overlap *by definition*. I ended up building two different aliasing models, one for x64 instructions and one for Mono's abstract model, and in retrospect I should have just built the latter, because it is easier and more powerful.

I have also noticed that my relationship to `__restrict` and Unity's `[NoAlias]` has changed. Previously I always thought about them as "I know better than the compiler" whereas now I think of them more empathetically: "let me help that poor compiler with a gift", because there is often so little you can do about aliasing.

There are still some optimizations that naturally need to live in the x64 backend, like for example cleaning up after the register allocator: We lowered both virtual register 5 ("vreg 5") and vreg 28 to RAX, and we use both to set something to zero. In the abstract, we can't optimize away setting vreg 28 to zero (because vreg 28 is a fresh vreg and needs some value). But once we know that both vreg 5 and vreg 28 are mapped to RAX, we may realize that RAX is already zero (from vreg 5) by the time we re-use it as vreg 28, so we can stop re-zeroing it.

As a concrete example, take this IR:
```
xzero R69 <-
storex_membase [%rbp + 0xffffff90] <- R69
xzero R72 <-
storex_membase [%rbp + 0xffffffa0] <- R72
xzero R22 <-
xzero R24 <-
```
Register assignment does this:
```
R69 -> xmm0
R72 -> xmm0
R22 -> xmm0
R24 -> xmm1
```

The naive codegen then does this:
```
pxor    xmm0, xmm0
movups  xmmword ptr [rbp - 0x70], xmm0
pxor    xmm0, xmm0
movups  xmmword ptr [rbp - 0x60], xmm0
pxor    xmm0, xmm0
pxor    xmm1, xmm1
```
Note that `pxor xmm0, xmm0` is XORing `xmm0` with itself and hence produces 0. A little bit smarter codegen instead does this:
```
pxor    xmm0, xmm0
movups  xmmword ptr [rbp - 0x70], xmm0
movups  xmmword ptr [rbp - 0x60], xmm0
pxor    xmm1, xmm1
```

Alias analysis is easier when there is no overlap, sharing is easier once overlap has been introduced. So each part of the IR pipeline has its place.

## Dead Store Elimination is hard
Another shift in perspective came from how I approached the relationships between optimization passes. My first thought was to keep optimization passes relatively "maximal": every pass does as much as it can locally. This was a sensible starting point, because I didn't know enough about this space to do any better. This approach has two problems: first, it's inefficient, and second, you multiply the hard parts.

The inefficiency is easy to explain: Most passes need to build some sort of model of what happens during program execution: "oh, you stored the number 15 here and now you reload it. We can just directly load the number you stored instead of going through memory!" Or they might need to compute aliasing information like "at this point in the program, vreg 16 holds the address of local variable 8, offset by 4 bytes."

Computing this information ad-hoc is expensive; in the worst case scenario you constantly walk instruction streams backwards to reconstruct information. It is much more efficient to compute what you need once and then propagate it forward through the function you are considering.

For "hard parts multiplying": The most fragile step I have found is "dead store elimination." You want to conclude that nobody ever reads from the memory that you have written, so you might as well not write it. This is very relevant in Mono's model for removing redundant writes to temporaries. This is inherently a non-local operation: you need to know that *nobody, nowhere* accesses the memory you are writing.

There are many places where it is easy to eliminate redundant loads, which could lead to dead stores. But wiring up the proofs required for dead store elimination in all of these places turned out to be a fool's errand. Dead store elimination is the hard part, so do not multiply it. My rule ended up being that there must only be a single pass that does dead store elimination and all other passes just freely leave potentially dead stores behind.

---

Next week's part 3 will be about exceptions, stack usage, and some good uses of LLMs in this space. 