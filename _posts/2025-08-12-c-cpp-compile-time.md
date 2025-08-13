---
layout: post
title: Does C compile faster than C++?
excerpt:
tags: []
---

I recently found myself wondering whether it is faster to compile C than C++. On some level, the answer to this is an obvious "yes": You can't accidentally summon ~~cthulhu~~ a SFINAE monster in your C code, for example.

But my question is a little bit more naive. What if I take code that is valid in both C and C++ and compile it as C once and then once as C++? Clearly, this isn't possible _in general_, but we can at least come up with some toy scenarios where it *is* possible. What difference is that going to make? C is still a "simpler" language, does that buy us anything? Or asked differently: If I already avoid most of C++, but still rely on some C++ features that force all of my code to be C++, what kind of tax am I paying for that? -- I should also point out that there are plenty of people spending a lot of time working on languages and toolchains that are much faster than anything I am measuring here. I am not interested in establishing some benchmarks for the maximum possible speed you can compile C as; I am merely curious and like to poke around.

For this purpose, I have written a small C# script that supports a handful of code generation scenarios and then compiles them with both MSVC (from VS17.14.7) and Clang 19. The generated code is not representative of "real" code, so take the results with a good grain of salt. There is usually a parameter `N` that controls the size of the generated code (`N = 1000, 2000, 4000, 8000, 16000`). For each scenario, I have compiled the code 30 times as C and C++, with `/Od` and `/O2`. The idea of comparing two different optimization levels is that as a compiler noob, I would expect the difference between C and C++ to mostly manifest in the frontend, and higher optimization levels should lead to more time spent in the backend... so maybe differences would be smaller. Or maybe not! I'm not an expert on this.

You can find the script [here](https://github.com/sschoener/c-vs-cpp-compile-times). Note that a part of it is Windows specific: we have to setup a compilation environment to invoke the compiler, and doing this for every run is expensive. So I ended up taking the measurements inside of a bash script.

The different scenarios:
 * `Empty`: We compile an empty file.
 * `Funcs`: Generating lots of functions that take an integer and just return it immediately, then call them all.
 * `FreeFunc`: We generate lots of calls to a function that takes a struct by pointer.
 * `CppMemberFunc`: Like the previous, but that free function is now a member function. This obviously doesn't work in C, but I wanted to see how it fares against a free standing function.
 * `NoOverload`: Declare `N` types and a corresponding free function that takes the type by pointer.
 * `CppOverload`: Like the previous, except that all of the functions now have the same name.
 * `ReturnByPointer`: Returns a trivial struct (containing just an `int`) by pointer.
 * `ReturnByValue`: Returns a trivial struct by value.

The details of the code for the different scenarios are [here](https://github.com/sschoener/c-vs-cpp-compile-times/blob/9ba361a484695438504ed0ac8199104dc910849b/Program.cs#L307).

# Findings
All times are given in seconds. I don't aim to perform any sort of deep statistics besides applying an interocular trauma test.

You can find the summary data [here](https://github.com/sschoener/c-vs-cpp-compile-times/blob/main/complete.csv) in CSV format, if you want to play with it. I have found it helpful to look at the data in a pivot table.

Some general findings: First, when compiling with `/Od`, Clang is marginally faster than MSVC (23.26s vs. 24.54s summed total across all medians). With `/O2` on the other hand, Clang is much slower than MSVC (51.20s vs. 35.59s total). They also produce different code, of course.


|      | Od    | O2     |
|------|------:|-------:|
|Clang |23.26s | 51.20s |
|MSVC  |24.54s | 35.39s |
{: .center-table}

Second, adding a few thousand functions to the same overload set in C++ is a bad idea, regardless of compiler. Who could have guessed! I've stopped beyond `N=4000`. With 4000 overloads, Clang-O2 already takes 6.3s to compile this. Interestingly, MSVC fares slightly better when handling unrealistically large overload sets. (I doubt this has any effect in reality, to be honest.)

Third, there is virtually no difference between `CppMemberFunc` and `FreeFunc`, on either compiler. I thought this was an interesting case to include because in C the name of the function is already sufficient to figure out what to call, whereas in C++ you have to know what type you are invoking it on.

## C vs C++
Compiling the same code as C is almost always faster than compiling it as C++, and the few cases where it is slower I can't tell that from noise. The difference between C and C++ is much smaller on Clang than on MSVC.

|      | C,Od  | C++,Od | C,O2   | C++,O2 |
|------|------:|-------:|-------:|-------:|
|Clang |6.54s  |  7.24s | 19.15s | 19.80s |
|MSVC  |6.98s  |  9.62s | 12.11s | 15.40s |
{: .center-table}

For MSVC, a large driver of the difference between C and C++ compile times is the `ReturnByValue` scenario, which is compiled ca. two times faster as C than as C++ for some values of `N`. This is not entirely surprising, because value copies are just much simpler in C. For Clang, there are small differences everywhere. I do not think that they are just noise, because they almost always skew towards C. But it's not exactly clear cut.

I would have loved to end this exploration by looking at a more "real world" example, but as you can imagine it is not exactly simple to find a C project that just happens to also compile as C++. As it stands, this set of experiments has already sufficiently satisfied my curiosity.