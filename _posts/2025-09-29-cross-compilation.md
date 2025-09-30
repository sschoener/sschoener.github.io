---
layout: post
title: What can go wrong in cross compilation
excerpt:
tags: []
---

I have been unfortunate enough to embark on a journey of C++ cross-compilation, by choice nonetheless. In my case, I use clang to compile _on_ a Linux machine to get binaries _for_ a Windows machine. This is surprisingly approachable nowadays. I do not want to bore you with the details of how to set this up but will rather bore you with the details of what can go wrong once you have it all set up.

I want to specifically highlight three different things that I have found while unsuccessfully trying to cross-compile [OpenUSD](https://github.com/PixarAnimationStudios/OpenUSD). OpenUSD is my guinea pig for cross-compilation, because it is non-trivial, useful software with some platform abstractions in place. It also has a bunch of dependencies, and I had a brief high when I realized that OpenSubdiv just cleanly cross-compiles without any issues. While I am using OpenUSD as an example, I don't mean this as "oh, look, it's broken." I'd rather say that it shows the subtleties of cross-compilation and that at some point, unless you explicitly test for it, it is unlikely to "just work." (And I put zero blame on the awesome people that support and maintain OpenUSD.)

A first problem appears when a codebase plays it loose with "compiler vs. OS." Here is a [concrete example](https://github.com/PixarAnimationStudios/OpenUSD/blob/60a8d58c3953a005e604c4f760caa018a90ae846/pxr/base/arch/attributes.h#L244) from OpenUSD:

```cpp
#elif defined(ARCH_COMPILER_GCC) || defined(ARCH_COMPILER_CLANG)

// The used attribute is required to prevent these apparently unused functions
// from being removed by the linker.
#   define ARCH_CONSTRUCTOR(_name, _priority) \
        __attribute__((used, section(".pxrctor"), constructor((_priority) + 100))) \
        static void _name()
#   define ARCH_DESTRUCTOR(_name, _priority) \
        __attribute__((used, section(".pxrdtor"), destructor((_priority) + 100))) \
        static void _name()

#elif defined(ARCH_OS_WINDOWS)
    
#    include "pxr/base/arch/api.h"
    
// Entry for a constructor/destructor in the custom section.
    __declspec(align(16))
    struct Arch_ConstructorEntry {
        ...
```

Note how we first have a branch that checks "is this clang?" followed by an else-if that checks "is this Windows?" This is suspicious: What if we are compiling for Windows and are using clang? The check for clang isn't really wrong, because we are using a clang/gcc specific attribute here: `__attribute__(constructor)`. The corresponding compilation unit `attributes.cpp` however *does not* check for the compiler, because if we can use the `constructor` attribute, then we don't need a custom implementation. We instead just check for `ARCH_OS_WINDOWS` ([here](https://github.com/PixarAnimationStudios/OpenUSD/blob/60a8d58c3953a005e604c4f760caa018a90ae846/pxr/base/arch/attributes.cpp#L257)) and assume the type `Arch_ConstructorEntry` is defined. So the compiler takes the Windows branch in `attributes.cpp` and compilation fails, because it took the non-Windows branch in the header.

For the next problem, let's start with a pop-quiz around [this line](https://github.com/PixarAnimationStudios/OpenUSD/blob/60a8d58c3953a005e604c4f760caa018a90ae846/pxr/base/arch/stackTrace.cpp#L21). What's wrong with this:
```cpp
#include <Winsock2.h>
```
Do you see the very mundane problem? Well, that header doesn't exist in the Windows SDK on Linux. There's only `WinSock2.h`, and Linux's file system is case-sensitive. On Windows, both will work. There is unfortunately no rhyme or reason to how files in the Windows SDK are named. Let's look at lib files! There is `WebServices.lib`, and `websocket.lib`. There is `wecapi.lib`, and there is `wdsClientAPI.lib`. And to add insult-to-injury, they sometimes also capitalize the extension, as in `User32.Lib`. This is especially infuriating when you pass `-lUser32` to the linker, and your linker only looks for `User32.lib`, and not the upper-case `User32.Lib` version. Congratulations, universe: you win again. You (as in "you, the reader", not as in "you, the universe") can either create symlinks for these or patch the source code to match the actual spelling. As you can imagine, there are a lot of instances of this problem. This is of course a losing battle if there is no mechanism in place to ensure this doesn't constantly break.


Finally, here is a third subtle problem, exemplified by [this piece](https://github.com/PixarAnimationStudios/OpenUSD/blob/60a8d58c3953a005e604c4f760caa018a90ae846/pxr/base/arch/demangle.cpp#L24) from OpenUSD, where we fail to include a header:
```cpp
#if defined(_AT_LEAST_GCC_THREE_ONE_OR_CLANG)
#include <cxxabi.h>
#endif
```

Clang ships with this header, yet we can't include it. My first thought was "aha! This header is in the standard library you are using, so it is not technically compiler dependent!" but that's not the full truth either. Besides the C standard library and the C++ standard library, there is the C++ ABI library, and clang has [a helpful page](https://clang.llvm.org/docs/Toolchain.html#c-abi-library) about this. Ultimately, what C++ ABI library you have depends on what C++ standard library you are using:

> The version of the C++ ABI library used by Clang will be the one that the chosen C++ standard library was linked against.

So in this case neither checking a compiler define nor a platform define is sufficient: you really need to check what standard library you are using, and in my case I am using clang to build against the ~~state-sponsored~~ Microsoft standard library. For this specific header, a check for `defined(_LIBCPP_VERSION) || defined(__GLIBCXX__)` is likely what you'd want.

As a final bonus quirk, note that when clang is used for cross-compilation, then it defines both `__clang__` and `_MSC_VER`. This is because Windows targets on Clang by default set `-fms-compatibility` (see [clang manual](https://clang.llvm.org/docs/UsersManual.html#microsoft-extensions)). Fun! To my surprise, this does not cause infinite breakage everywhere or even in OpenUSD, but it sure does confuse some compiler macros.

My takeaway from this adventure so far is pure amazement for how anything cross-compiles, at all, and a new appreciation for all of the moving parts beyond "compiler" and "target platform."