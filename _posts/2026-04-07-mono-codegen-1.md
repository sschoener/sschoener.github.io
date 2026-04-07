---
layout: post
title: What I learned from improving Unity's Mono codegen, part 1
excerpt:
tags: []
---

My [current sidequest]({% post_url 2026-03-31-better-mono %}) is to improve the codegen for Unity games (and the editor) running on Mono. This post and the next two are about this process and what I learned.

In this post, I am going to give an example of how code flows through Mono during JIT compilation in principle, along with some commentary. We're going to see how Mono's JIT struggles with value types in particular.

The compilation flow from C# to machine code goes through multiple phases. First, the C# is compiled to IL ("intermediate language"). This happens once, offline, and is what you'd usually call C# compilation. The resulting .NET assemblies contain that IL. Then at runtime the JIT compiler translates this IL into IR ("intermediate representation"). While IL is a stack-oriented language, Mono's IR is register-centric. This IR instruction stream goes through multiple rounds of lowering that translates high-level instructions to progressively lower level instructions. This might look like this:
 * you start with "take the top value of the stack and store it in a local variable",
 * this turns into "copy struct from A to B",
 * this turns into "take address of A, put it into virtual register 48, then copy 24 bytes to address of B",
 * this turns into "load 8 bytes from [RBP-0x80] into RAX, store 8 bytes from RAX into [RBP-0xc0]" (repeated three times with different offsets)

The output of this is not insane if your program merely uses pointers and integers, or maybe reference types. It's not great either, and many common optimizations (such as dropping index checks for arrays in loops) are not broadly implemented. Once you start using structs (i.e. C#'s value types), the generated machine code becomes completely bonkers, because there are so many temporary copies that nobody is optimizing away.

Let's revisit this example from last week, where the seemingly innocuous `dot4` function completely blows up.

```csharp
static float4 dot4(float4 xs, float4 ys, float4 zs, float4 mx, float4 my, float4 mz)
{
    return xs * mx + ys * my + zs * mz;
}
```
The IL for this code is here:
```
   IL_0000: ldarg.0
   IL_0001: ldarg.3
   IL_0002: call valuetype float4::op_Multiply(...)
   IL_0007: ldarg.1
   IL_0008: ldarg.s my
   IL_000a: call valuetype float4::op_Multiply(...)
   IL_000f: call valuetype float4::op_Addition(...)
   IL_0014: ldarg.2
   IL_0015: ldarg.s mz
   IL_0017: call valuetype float4::op_Multiply(...)
   IL_001c: call valuetype float4::op_Addition(...)
   IL_0021: ret
```
You can find the unoptimized disassembly in [last week's post]({% post_url 2026-03-31-better-mono %}) -- it's 400 lines (!) worth of instructions.

I am not going to go through all of it, but note that we see a bunch of `cvtss2sd xmm0, xmm0` instructions. These convert between floats and doubles, because Mono internally does all math in doubles. That's the first thing to turn off for this case, as it mostly does not matter fo this math (and neither IL2CPP nor Burst do it), but it simplifies the discussion greatly. Let's continue with double-math disabled already.

The IL is then translated into a high-level IR, which in this case looks like the snippet below, except that the full thing runs to about 200 lines. The big difference in size happens because all of the operations here are inlined. We are going to focus on the first multiplication because that alone is already a lot to take in.

This snippet is the equivalent of doing a single multiplication. We load the two arguments (`vmove`), then we load their single fields (`loadr4_membase`), then we multiply them one-by-one, create a new zeroed local R49, and then we store the components in R49 one-by-one (`storer4_membase_reg`). Then we take that local R49 and move it to another local `R65` before going on to the next operation.
```
 il_seq_point intr il: 0x0
 // copy arguments into local slots
 vmove R27 <- R17
 vmove R28 <- R20
 // load and multiply x
 ldaddr R29 <- R27
 loadr4_membase R30 <- [R29 + 0x0]
 ldaddr R31 <- R28
 loadr4_membase R32 <- [R31 + 0x0]
 r4_mul R33 <- R30 R32 clobbers: 1

 // load and multiply y
 ldaddr R34 <- R27
 loadr4_membase R35 <- [R34 + 0x4]
 ldaddr R36 <- R28
 loadr4_membase R37 <- [R36 + 0x4]
 r4_mul R38 <- R35 R37 clobbers: 1

 // load and multiply z
 ldaddr R39 <- R27
 loadr4_membase R40 <- [R39 + 0x8]
 ldaddr R41 <- R28
 loadr4_membase R42 <- [R41 + 0x8]
 r4_mul R43 <- R40 R42 clobbers: 1

 // load and multiply w
 ldaddr R44 <- R27
 loadr4_membase R45 <- [R44 + 0xc]
 ldaddr R46 <- R28
 loadr4_membase R47 <- [R46 + 0xc]
 r4_mul R48 <- R45 R47 clobbers: 1

 // init output of the operation
 vzero R49 <-
 rmove R52 <- R33
 rmove R53 <- R38
 rmove R54 <- R43
 rmove R55 <- R48
 // store a.x*b.x in output
 ldaddr R56 <- R49
 storer4_membase_reg [R56] <- R33
 // store a.y*b.y in output
 ldaddr R58 <- R49
 storer4_membase_reg [R58 + 0x4] <- R38
 // store a.z*b.z in output
 ldaddr R60 <- R49
 storer4_membase_reg [R60 + 0x8] <- R43
 // store a.w*b.w in output
 ldaddr R62 <- R49
 storer4_membase_reg [R62 + 0xc] <- R48
 // copy output to actual result of the inlined multiplication
 vmove R65 <- R49
```

There are multiple issues here: first is of course the lack of vectorization. But more broadly, it is the `vmove` usage. The `v` in `vmove` is short for `valuetype`, which means that `vmove R27 <- R17` copies a `float4`. It needs to copy from somewhere to somewhere, and that somewhere happens to be the stack, because Mono doesn't know that `float4` could live in an XMM register.

The next IR lowering step expands those 200 lines to roughly 350. Before doing anything useful, this function now materializes two of its arguments onto the stack (to implement the `vmove`). Not because it needs to, but simply because the multiplication operator that we inlined happened to take its arguments by value, so Mono faithfully copies them. All of this is just to get the equivalent of `mulps`:
```
 il_seq_point intr il: 0x0
 // This is vmove R27 <- R17 
 ldaddr R231 <- R17
 ldaddr R232 <- R27
 loadi4_membase R233 <- [R231 + 0x0]
 storei4_membase_reg [R232] <- R233
 loadi4_membase R234 <- [R231 + 0x4]
 storei4_membase_reg [R232 + 0x4] <- R234
 loadi4_membase R235 <- [R231 + 0x8]
 storei4_membase_reg [R232 + 0x8] <- R235
 loadi4_membase R236 <- [R231 + 0xc]
 storei4_membase_reg [R232 + 0xc] <- R236

 // This is vmove R28 <- R20
 ldaddr R237 <- R20
 ldaddr R238 <- R28
 loadi4_membase R239 <- [R237 + 0x0]
 storei4_membase_reg [R238] <- R239
 loadi4_membase R240 <- [R237 + 0x4]
 storei4_membase_reg [R238 + 0x4] <- R240
 loadi4_membase R241 <- [R237 + 0x8]
 storei4_membase_reg [R238 + 0x8] <- R241
 loadi4_membase R242 <- [R237 + 0xc]
 storei4_membase_reg [R238 + 0xc] <- R242

 // This part here is mostly unchanged
 // we're doing the multiplication again
 ldaddr R29 <- R27
 loadr4_membase R30 <- [R29 + 0x0]
 ldaddr R31 <- R28
 loadr4_membase R32 <- [R31 + 0x0]
 r4_mul R33 <- R30 R32 clobbers: 1
 ldaddr R34 <- R27
 loadr4_membase R35 <- [R34 + 0x4]
 ldaddr R36 <- R28
 loadr4_membase R37 <- [R36 + 0x4]
 r4_mul R38 <- R35 R37 clobbers: 1
 ldaddr R39 <- R27
 loadr4_membase R40 <- [R39 + 0x8]
 ldaddr R41 <- R28
 loadr4_membase R42 <- [R41 + 0x8]
 r4_mul R43 <- R40 R42 clobbers: 1
 ldaddr R44 <- R27
 loadr4_membase R45 <- [R44 + 0xc]
 ldaddr R46 <- R28
 loadr4_membase R47 <- [R46 + 0xc]
 r4_mul R48 <- R45 R47 clobbers: 1
 ldaddr R243 <- R49

 // This is the zero-init of the output again
 i8const R244 <- [0]
 storei8_membase_reg [R243] <- R244
 storei8_membase_reg [R243 + 0x8] <- R244
 rmove R52 <- R33
 rmove R53 <- R38
 rmove R54 <- R43
 rmove R55 <- R48
 // now we store the result component by component again
 ldaddr R56 <- R49
 storer4_membase_reg [R56] <- R33
 ldaddr R58 <- R49
 storer4_membase_reg [R58 + 0x4] <- R38
 ldaddr R60 <- R49
 storer4_membase_reg [R60 + 0x8] <- R43
 ldaddr R62 <- R49
 storer4_membase_reg [R62 + 0xc] <- R48

 // This is vmove R65 <- R49
 ldaddr R245 <- R49
 ldaddr R246 <- R65
 loadi4_membase R247 <- [R245 + 0x0]
 storei4_membase_reg [R246] <- R247
 loadi4_membase R248 <- [R245 + 0x4]
 storei4_membase_reg [R246 + 0x4] <- R248
 loadi4_membase R249 <- [R245 + 0x8]
 storei4_membase_reg [R246 + 0x8] <- R249
 loadi4_membase R250 <- [R245 + 0xc]
 storei4_membase_reg [R246 + 0xc] <- R250
```
At this point, only a few lowering steps remain before we reach the final assembly, but notably none of these reduce the instruction stream.

Let's instead turn on at least a subset of the new optimizations I added and see what happens. These optimizations are geared towards reducing stack traffic and temporaries by rewriting the IR itself (both before and after the lowering step that affects `vmove`). We get this much more pleasant result:
```
 il_seq_point intr il: 0x0
 ldaddr R231 <- R17
 loadr4_membase R30 <- [R231 + 0x0]
 ldaddr R232 <- R20
 loadr4_membase R32 <- [R232 + 0x0]
 r4_mul R33 <- R30 R32 clobbers: 1
 loadr4_membase R35 <- [R231 + 0x4]
 loadr4_membase R37 <- [R232 + 0x4]
 r4_mul R38 <- R35 R37 clobbers: 1
 loadr4_membase R40 <- [R231 + 0x8]
 loadr4_membase R42 <- [R232 + 0x8]
 r4_mul R43 <- R40 R42 clobbers: 1
 loadr4_membase R45 <- [R231 + 0xc]
 loadr4_membase R47 <- [R232 + 0xc]
 r4_mul R48 <- R45 R47 clobbers: 1
```
Look, no pointless temporaries! It's not hard to convince yourself that this is equivalent to the original IR. In this specific case, you can also verify by hand that all of the different moves and stores are unnecessary. It is however at least a little bit hard to teach the compiler to do this in general.

The remaining issue is that we are still using scalar multiplication. Once you tell Mono to treat `float4` like a vector type specifically designed for SIMD math, you get this much more pleasant version. The `x` in `loadx` indicates that we are dealing with XMM vector registers and are loading a whole vector at once.
```
 il_seq_point intr il: 0x0
 ldaddr R53 <- R17
 loadx_membase R28 <- [R53 + 0x0]
 ldaddr R54 <- R20
 loadx_membase R29 <- [R54 + 0x0]
 mulps R30 <- R28 R29 clobbers: 1
```
This is as good as it gets for now: We still need to load the `float4` values from memory, because the standard Windows x64 ABI mandates that such big values go through the stack and are passed by reference, even if C# semantically surfaces this as a regular by-value argument. This could be improved by telling Mono about `vectorcall` conventions ([MSDN](https://learn.microsoft.com/en-us/cpp/cpp/vectorcall?view=msvc-170)), which allow passing bigger values in registers directly, but the real fix is that `dot4` should be inlined when used (which the improved Mono of course also does).

To conclude, we have now seen how Mono struggles *a lot* with value types. In math-heavy code, useless temporaries make up a vast chunk of the actual instructions executed. This is amplified further with larger structs, since Mono emits direct calls to `memset` and `memcpy` for these.

In the next part, I am going to talk about what goes into implementing these optimizations in Mono.