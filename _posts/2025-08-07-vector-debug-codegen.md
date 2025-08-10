---
layout: post
title: Vector types and debug performance
excerpt:
tags: []
---

For reasons, I have found myself writing a vector math library. Like [Aras some time ago](https://aras-p.info/blog/2024/09/14/Vector-math-library-codegen-in-Debug/) I've found an unpleasant surprise when looking at the debug performance of some vector types.

There is no point repeating what Aras already wrote, but I have some additional data points. My concrete example uses `float3` (3D), where I would still like to use vector instructions, but none of this here is actually `float3` specific.

I only care about Clang, or more specifically Clang 19, which you can get via Visual Studio 2022. My setup is X64 on Windows.

I ended up doing this investigation because I had written a little sample particle simulation and decided to improve it by adding a vector math library. The particle simulation just used scalar code, no `float3` struct in sight. Adding the vector math library did improve performance of optimized builds, but completely fell off a cliff in non-optimized debug builds.

This was unexpected. Did I not avoid all of the obviously bad things? My code, for example, does not contain templates (which among other compile time magic is one of the factors that makes the performance unpredictable in the case that Aras discusses). Vector math isn't going to change, ever, and I need just `(float|int)(2|3|4)`. It's way more important to have readable, sensible code and duplicate that 6 times than to have a single template. But alas, that was not enough to save me from performance woes.

When I say `float3`, I mean struct like this:
```cpp
struct float3 {
    float x, y, z, pad;
};
```
It's actually the size of 4 floats, and for storage we may want to use a packed format, but computations absolutely need to happen with a width of 4, as that is the most commonly supported vector length.

My concrete test case is code like this, which I have taken verbatim from code I had written earlier with my brain intentionally switched off. It's important that the vector math library is decent even if you *don't* think about whether you first multiply all scalars and *then* the vector or not, for example. The code goes over 64k particles, and then 10 centers of gravity, and calculates some gravity-inspired velocity update.
```cpp
float dx = cPos.x - pos.x;
float dy = cPos.y - pos.y;
float dz = cPos.z - pos.z;

float squared = dx * dx + dy * dy + dz * dz;
// float* centerMass
float f = centerMass[c] / squared;

float distance = sqrtf(squared);
if (distance < 10)
    distance = 10;

dx *= f * dx / distance;
dy *= f * dy / distance;
dz *= f * dz / distance;

// This is assuming a time step of 1/60
vel.x += dx / 60;
vel.y += dy / 60;
vel.z += dz / 60;
```
There is some opportunity for vectorization, but also a bunch of scalar code.

I have experimented with ten different setups:
 1. purely scalar code where `float3` is used for storage, but for nothing else (`VEC_SCALAR`)
 2. purely scalar code with operators on `float3`, and the operators are free functions (`VEC_OP`)
 3. purely scalar code with operators on `float3`, and the operators are member functions (`VEC_OP_MEMBER`)
 4. raw SSE, where `float3` is defined to be `__m128` (`VEC_SSE_RAW`)
 5. SSE where `float3` is a struct that contains a union of `__m128` and `x, y, z, pad` (`VEC_SSE`), and we directly operate on the `__m128` with intrinsics
 6. as in the previous scenario, but with operators (`VEC_SEE_OP`)
 7. as in the previous scenario, but the operators use the `vectorcall` calling convention (`VEC_SEE_OP_VEC`)
 8. as in the previous scenario, but are also member functions (`VEC_SEE_OP_VEC_MEM`)
 9. using Clang's built in vector types, OpenCL flavored (`VEC_BUILTIN_OCL`)
 10. using Clang's built in vector types, GCC flavored (`VEC_BUILTIN_GCC`)
 11. using Clang's built in vector types, OpenCL flavored, in a struct (`VEC_BUILTIN_OCL_WRAP`)

In all cases, all the operators are marked as always-inline. You can find the test code [here](https://github.com/sschoener/vector-math-codegen/).

Some words about the unexpected entries:
 * Clang has a various different inbuilt vector types which all offer a slightly different interface, but they come with operators already. For example, OpenCL-like vectors are defined like this:
```cpp
typedef float float3 __attribute__((ext_vector_type(3), __aligned__(16)));
static_assert(sizeof(float3) == 4 * sizeof(float), "Unexpected vector size");
```
 * `vectorcall` is a custom calling convention on Windows for functions that take many vector register arguments. That is *clearly* not the case here, but I wanted to see whether anything happens anyway: The docs ([MSDN](https://learn.microsoft.com/en-us/cpp/cpp/vectorcall?view=msvc-170)) mention _homogeneous vector aggregate_ (HVA) values as something that might benefit, and our `float3` should qualify.
 * I added member vs. non-member function because I had no idea whether `vectorcall` on a member-function was even valid in the first place.

Let me lead with the results. We have five scenarios to compare: `-O0`, `-O1`, `-O2`, `-O0` but we no longer force inlining of all the operators involved, and then also `-Og`. `-Og` is "optimize but keep debuggable". As of writing `-Og` is identical to `-O1` in terms for optimization passes, but it also sets `-fextend-variable-liveness=all` -- everything else is identical[^clang-og]. I explicitly pass those to Clang via `-Xclang -O1`, since Visual Studio uses the `clang-cl` frontend. The reported value is the mean time taken for one loop of my benchmark, in microseconds. **This is a microbenchmark. Don't read too much into the specific numbers.** Also note that this is of course measuring a whole bunch of things that are NOT about vector code (like the scalar code we always have, loops, etc.).

|Setup   |O0|O1|O2|O0, no inlining|Og|O0/O1 speedup
|--------|-:|-:|-:|-:|-:|-:|
|VEC_SCALAR|4077|3001|2973|4159|3094|1.33
|VEC_OP|8315|2979|3014|8669|3061|2.79
|VEC_OP_MEMBER|8571|3003|2985|8476|3076|2.85
|VEC_SSE_RAW|5575|1527|1535|5564|1585|3.65
|VEC_SSE|6415|1553|1540|6459|1597|4.13
|VEC_SSE_OP|19694|1541|1532|26292|1609|12.82
|VEC_SSE_OP_VEC|19801|1536|1536|21269|1573|12.89
|VEC_SSE_OP_VEC_MEM|20226|1547|1547|21336|1564|13.07
|VEC_BUILTIN_OCL|2932|1534|1536|2892|1570|1.91
|VEC_BUILTIN_GCC|2910|1512|1521|2914|1594|1.92
|VEC_BUILTIN_OCL_WRAP|16477|1463|1485|19328|1570|11.26

What can we learn from this?
 * There is no real difference between `-Og`, `-O1` and `-O2` for this code.
 * There *is* a way of writing vector code where the debug version is just as fast as an optimized scalar version: builtin vector types.
 * While using SSE intrinsics is not free, just using raw intrinsics is not the worst choice for debug performance. It's nowhere near their intended speed, unfortunately. Combining them with operators however is a guarantee for pain in Debug builds. The middle ground of putting the SSE type into a struct also comes at a cost.
 * However, the real cost comes from using operators: As soon as we wrap the otherwise really decent builtin types in a struct and use operators, we hit a performance cliff.
 * `vectorcall` does help, but only if you don't inline. That's expected. It has no practical value here, since in reality we will always want to inline these functions. It also works on member functions, and using member functions makes no difference here in any scenario.

The builtin vector types are an interesting option. I have learned a couple of things about them:
 * If you use intrinsics, odds are you are already using builtin vectors. This is how `_mm_add_ps` is defined for me (`DEFAULT_FN_ATTRS` includes `__always_inline__`). This is *already* using builtin vector types of the GCC variety.

```cpp
typedef float __v4sf __attribute__((__vector_size__(16)));
typedef float __m128 __attribute__((__vector_size__(16), __aligned__(16)));

static __inline__ __m128 __DEFAULT_FN_ATTRS _mm_add_ps(__m128 __a, __m128 __b)
{
  return (__m128)((__v4sf)__a + (__v4sf)__b);
}
```
 * The main reason not to use builtin vector types is that you have now completely given up control of the interface of your vector types. This might be OK in your scenario.
 * A secondary reason not to use builtin vector types is that none of the IDEs I have tried (VS2022, CLion) actually supported them fully. VS2022 did a bit better than CLion. The latter just does not know about the operators that the inbuilt vector types support. The former doesn't recognize `v.x` as a valid way to access the first component of an OpenCL vector. You can sort-of work around this by stubbing out an implementation like this, but it's not great:

```cpp
#if defined(__INTELLISENSE__) || defined(__clang_analyzer__) || defined(__JETBRAINS_IDE__)
struct float4 {
    float x, y, z, w;
    float4 operator+(const float4& rhs);
};
#else
typedef float float4 __attribute__((ext_vector_type(4)));
#endif
```
 * The OpenCL variety of built-in vectors does not enjoy great documentation, unfortunately. The GCC variety doesn't support using `v.x` to get the first field of the vector. Neither struck me as a lovingly crafted implementation.

---

Next, I want to talk about *why* things are so much slower in unoptimized builds. Let us look at some codegen.

For all scenarios with operators, the biggest culprit is that we now tend to create a lot of temporary objects, and even with inlining these objects don't completely disappear. Let's pick on this line here specifically:
```cpp
delta = f * delta / distance;
```
In `VEC_OP`, you can see that the results of `f * delta` and `(f * delta) / distance` do exist. `f * delta` lives at `rsp+138h`, and the result of the division is at `rsp+148h`. Then we copy that into delta as `rsp+158h`:
```cpp
delta = f * delta / distance;
14CF  movss        xmm0, dword ptr [rsp+4Ch]
14D5  movss        xmm1, dword ptr [rsp+50h]
14DB  lea          rax, [rsp+138h]
14E3  mov          qword ptr [rsp+120h], rax
14EB  lea          rax, [rsp+158h]
14F3  mov          qword ptr [rsp+118h], rax
14FB  movss        dword ptr [rsp+114h], xmm1
1504  movss        xmm1, dword ptr [rsp+114h]
150D  mov          rax, qword ptr [rsp+118h]
1515  mulss        xmm1, dword ptr [rax]
// store result of first multiplication in rsp+138h
1519  movss        dword ptr [rsp+138h], xmm1
1522  movss        xmm1, dword ptr [rsp+114h]
152B  mov          rax, qword ptr [rsp+118h]
1533  mulss        xmm1, dword ptr [rax+4h]
1538  movss        dword ptr [rsp+13Ch], xmm1
1541  movss        xmm1, dword ptr [rsp+114h]
154A  mov          rax, qword ptr [rsp+118h]
1552  mulss        xmm1, dword ptr [rax+8h]
1557  movss        dword ptr [rsp+140h], xmm1
1560  xorps        xmm1, xmm1
1563  movss        dword ptr [rsp+144h], xmm1
156C  lea          rax, [rsp+148h]
1574  mov          qword ptr [rsp+108h], rax
157C  movss        dword ptr [rsp+104h], xmm0
1585  lea          rax, [rsp+138h]
158D  mov          qword ptr [rsp+F8h], rax
1595  mov          rax, qword ptr [rsp+F8h]
159D  movss        xmm0, dword ptr [rax]
15A1  divss        xmm0, dword ptr [rsp+104h]
// store result of first division in rsp+148h
15AA  movss        dword ptr [rsp+148h], xmm0
15B3  mov          rax, qword ptr [rsp+F8h]
15BB  movss        xmm0, dword ptr [rax+4h]
15C0  divss        xmm0, dword ptr [rsp+104h]
15C9  movss        dword ptr [rsp+14Ch], xmm0
15D2  mov          rax, qword ptr [rsp+F8h]
15DA  movss        xmm0, dword ptr [rax+8h]
15DF  divss        xmm0, dword ptr [rsp+104h]
15E8  movss        dword ptr [rsp+150h], xmm0
15F1  xorps        xmm0, xmm0
15F4  movss        dword ptr [rsp+154h], xmm0
// copy from rsp+148h to rsp+158h
15FD  mov          rax, qword ptr [rsp+148h]
1605  mov          qword ptr [rsp+158h], rax
160D  mov          rax, qword ptr [rsp+150h]
1615  mov          qword ptr [rsp+160h], rax
161D  lea          rax, [rsp+128h]
1625  mov          qword ptr [rsp+F0h], rax
162D  movss        xmm0, dword ptr [__real@42700000 (402ch)]
1635  movss        dword ptr [rsp+ECh], xmm0
163E  lea          rax, [rsp+158h]
1646  mov          qword ptr [rsp+E0h], rax
```
To be clear, it is neither surprising nor bad that these values exist. That is likely what you want from an unoptimized build. It just goes to show that the culprit here really is passing (or mostly returning) structs by value.

I also want to show the unoptimized codegen for the builtin vector types for that line:
```cpp
delta = f * delta / distance;
1296  movss        xmm0, dword ptr [rsp+4Ch]
129C  shufps       xmm0, xmm0, 0h
12A0  movaps       xmm1, xmmword ptr [rsp+60h]
12A5  mulps        xmm0, xmm1
12A8  movss        xmm1, dword ptr [rsp+48h]
12AE  shufps       xmm1, xmm1, 0h
12B2  divps        xmm0, xmm1
12B5  movaps       xmmword ptr [rsp+60h], xmm0
```
This is better than using SSE intrinsics, because as noted above, these so-called SSE intrinsics _are not intrinsic_. They are functions that take and return things by value, and they create copies that we then pass around:
```cpp
delta = _mm_div_ps(_mm_mul_ps(_mm_set1_ps(f), delta), _mm_set1_ps(distance));
// copy float argument f around
12EB  movss        xmm0, dword ptr [rsp+48h]
12F1  movss        dword ptr [rsp+1ECh], xmm0
12FA  movss        xmm0, dword ptr [rsp+1ECh]
1303  shufps       xmm0, xmm0, 0h
// copy result of _mm_set1_ps around
1307  movaps       xmmword ptr [rsp+1D0h], xmm0
130F  movaps       xmm1, xmmword ptr [rsp+1D0h]
1317  movaps       xmm2, xmmword ptr [rsp+60h]
// copy float argument distance around etc.
131C  movss        xmm0, dword ptr [rsp+4Ch]
1322  movss        dword ptr [rsp+1CCh], xmm0
132B  movss        xmm0, dword ptr [rsp+1CCh]
1334  shufps       xmm0, xmm0, 0h
1338  movaps       xmmword ptr [rsp+1B0h], xmm0
1340  movaps       xmm0, xmmword ptr [rsp+1B0h]
1348  movaps       xmmword ptr [rsp+200h], xmm2
1350  movaps       xmmword ptr [rsp+1F0h], xmm0
1358  movaps       xmm0, xmmword ptr [rsp+1F0h]
1360  movaps       xmm2, xmmword ptr [rsp+200h]
1368  mulps        xmm0, xmm2
136B  movaps       xmmword ptr [rsp+180h], xmm1
1373  movaps       xmmword ptr [rsp+170h], xmm0
137B  movaps       xmm0, xmmword ptr [rsp+170h]
1383  movaps       xmm1, xmmword ptr [rsp+180h]
138B  divps        xmm0, xmm1
138E  movaps       xmmword ptr [rsp+60h], xmm0
```

One final question I'd like to answer is this: why is `VEC_SSE` so much faster than `VEC_BUILTIN_OCL_WRAP`? In both cases, we are essentially putting a vector type into a struct and keep copying 4 floats. The main difference is that `VEC_SSE` directly operates on the contents of the struct (and copies that content), whereas `VEC_BUILTIN_OCL_WRAP` copies the struct itself.

Here is a sample from `VEC_BUILTIN_OCL_WRAP`:
```cpp
vel += delta / 60;
1461  mov          qword ptr [rsp+F8h], rcx
1469  mov          dword ptr [rsp+F0h], __avx10_version (42700000h)
1474  mov          qword ptr [rsp+E8h], rax
147C  mov          rax, qword ptr [rsp+E8h]
1484  movaps       xmm0, xmmword ptr [rax]
1487  movaps       xmm1, xmmword ptr [rsp+F0h]
148F  shufps       xmm1, xmm1, 0h
1493  divps        xmm0, xmm1
1496  movaps       xmmword ptr [rsp+130h], xmm0
149E  lea          rax, [rsp+130h]
14A6  mov          qword ptr [rsp+C8h], rax
14AE  lea          rax, [rsp+190h]
14B6  mov          qword ptr [rsp+C0h], rax
14BE  mov          rax, qword ptr [rsp+C8h]
14C6  movaps       xmm0, xmmword ptr [rax]
14C9  mov          rax, qword ptr [rsp+C0h]
14D1  addps        xmm0, xmmword ptr [rax]
14D4  movaps       xmmword ptr [rax], xmm0
```
Compare this to the same in `VEC_SSE`:
```cpp
vel.vec = _mm_add_ps(vel.vec, _mm_div_ps(delta.vec, _mm_set1_ps(60)));
13A5  mov          dword ptr [rsp+170h], __avx10_version (42700000h)
13B0  movaps       xmm0, xmmword ptr [rsp+170h]
13B8  shufps       xmm0, xmm0, 0h
13BC  movaps       xmmword ptr [rsp+160h], xmm0
13C4  movaps       xmm1, xmmword ptr [rsp+160h]
13CC  movaps       xmm0, xmmword ptr [rsp+60h]
13D1  movaps       xmmword ptr [rsp+130h], xmm1
13D9  movaps       xmmword ptr [rsp+120h], xmm0
13E1  movaps       xmm1, xmmword ptr [rsp+120h]
13E9  divps        xmm1, xmmword ptr [rsp+130h]
13F1  movaps       xmm0, xmmword ptr [rsp+220h]
13F9  movaps       xmmword ptr [rsp+1F0h], xmm1
1401  movaps       xmmword ptr [rsp+1E0h], xmm0
1409  movaps       xmm0, xmmword ptr [rsp+1E0h]
1411  addps        xmm0, xmmword ptr [rsp+1F0h]
1419  movaps       xmmword ptr [rsp+220h], xmm0
```
Note how `VEC_SSE` consistently uses the XMM registers, whereas `VEC_BUILTIN_OCL_WRAP` constantly bounces back and forth: copy using general purpose registers, math via XMM registers. That's likely where the slowdown comes from. I have not managed to avoid this (I have tried removing the union, for example, and that doesn't help at all).


For the particular use-case I needed, I ended up going with wrapping Clang's vector types in a struct. Yes, the debug performance is terrible. Yes, that means that debug builds need to run with `-Og`. But if you want to retain control over the interface of your `float3` type, then that's the best option I have found. I hope I can one day write a note about how `-Og` is actually great for debuggability, but as it stands I have not run those experiments yet.

[^clang-og]: You can see the difference in command-line by doing comparing the output of these two commands: `clang -Og -### input.cpp` vs `clang -O1 -### input.cpp`. You can compare the enabled optimization passes and their arguments by likewise comparing these two: `-Og -mllvm -debug-pass=Structure input.cpp` vs. `-O1 -mllvm -debug-pass=Structure input.cpp`.  Both is very easy on CompilerExplorer.