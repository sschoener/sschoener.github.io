---
layout: post
title: How to iterate over section data in C++
excerpt:
tags: []
---

[Last time]({% post_url 2025-07-07-thread-callbacks-windows %}), we looked at callbacks you can directly embed into your binaries on Windows that are then called for every thread on start/end. The runtime is using this to initialize thread-locals that require more than just memcpy. Today, we are going to look at a mechanism that can be used to initialize global variables. It's *almost* useful.

On Windows, the initialization of globals is handled by the C runtime library (CRT): it places a small wrapper around your `main` function that runs those initializers. But how does it know what initializers to run? The variables you have to initialize are all over your program.

Here is the trick: the compiler can put pointers to initialization functions into a specific section of your program. That can happen separately in every object file. The linker will collect these symbols and then put them all in the same place. Then another part of your program can iterate over the contents of this section and invoke those function pointers. The only tricky bit is that you need to get the start and end of the section.

This is what this looks like in practice. First we define a macro to easily add a symbol to a section:
```cpp
#if PLATFORM_WINDOWS

#define ADD_TO_SECTION(fn, prefix, sectionName) \
    __declspec(allocate(sectionName "$B")) \
    const void* prefix##fn = (void*)fn

#elif PLATFORM_APPLE

#define ADD_TO_SECTION(fn, prefix, sectionName) \
    __attribute__((used, section("__DATA," sectionName))) \
    const void* prefix##fn = (void*)fn

#elif PLATFORM_LINUX

#define ADD_TO_SECTION(fn, prefix, sectionName) \
    __attribute__((used, section(sectionName))) \
    const void* prefix##fn = (void*)fn

#endif
```

Then we use the macro like this to register two initializers into the `MyInit` section:
```cpp
static void MyInitializer1() {}
static void MyInitializer2() {}

ADD_TO_SECTION(MyInitializer1, init, "MyInit")
ADD_TO_SECTION(MyInitializer2, init, "MyInit")
```
Note how on Windows, we actually say `__declspec(allocate("MyInit$B"))`. The linker interprets this as a section name (`MyInit`) followed by a string that is used for sorting the symbols in memory. Also note that sections usually start with `.`, which I've disregarded here.

Finally, we need to put in some more work to get symbols that represent the start or end of the section:
```cpp
#if PLATFORM_WINDOWS

// On Windows, we need to declare extra symbols that represent the start/end of the section.
// Note the trailing $A and $Z to force sorting in front/back.
extern "C" __declspec(allocate("MyInit$A")) void* MyInitStart = nullptr;
extern "C" __declspec(allocate("MyInit$Z")) void* MyInitEnd = nullptr;

#define SECTION_START(sectionName) (void**)((& sectionName ## Start) + 1)
#define SECTION_END(sectionName) (void**)((& sectionName ## End))

#elif PLATFORM_APPLE

extern void* MyInitStart __asm("section$start$__DATA$MyInit");
extern void* MyInitEnd __asm("section$end$__DATA$MyInit");

#define SECTION_START(sectionName) (void**)((& sectionName ## Start))
#define SECTION_END(sectionName) (void**)((& sectionName ## End))

#else

// ELF files automatically generate symbols __start_SECTION/__end_SECTION.
extern "C" void* __start_MyInit;
extern "C" void* __stop_MyInit;

#define SECTION_START(sectionName) (void**)(&__start_ ## sectionName)
#define SECTION_END(sectionName) (void**)(&__stop_ ## sectionName)

#endif
```

We can then use it like this:
```cpp
int main(int argn, char** argc) {
	void** start = SECTION_START(MyInit);
	void** end = SECTION_END(MyInit);

	Printf("START\n");
	for (void** p = start; p < end; ++p) {
		if (p != nullptr)
			Printf("Value: %p\n", *p);
	}
	Printf("END\n");
	return 0;
}
```

I've tested this code with Clang/lld-link. It's possible that MSVC requires a little bit more work, like adding `#pragma section(MyInit, read)` somewhere and forcing the linker to not discard the symbols (`#pragma comment(linker, "/INCLUDE:symbolname")`).

I should also point out that there are some pitfalls around padding: the linker might add zeros to the end of the section to insert padding, and it may even insert padding between symbols in the section. Raymond Chen has [three](https://devblogs.microsoft.com/oldnewthing/20181107-00/?p=100155) [small](https://devblogs.microsoft.com/oldnewthing/20181108-00/?p=100165) [pieces](https://devblogs.microsoft.com/oldnewthing/20181109-00/?p=100175) on this as well.

Finally, why did I say that this is *almost* useful for initializing globals? Well, it doesn't play nicely with static linking. You may have noticed that we applied `__attribute__((used))` to the initializer. This tells Clang to not drop them during compilation. Unfortunately, linkers exist. (Honestly: linkers! Compilers are bad, yes, but if you really want to ruin your day, you need a linker.) When the linker sees your static library, it will make an attempt to pull in exactly what is needed, and our section data doesn't make the list: nobody is referencing any symbols in it. So initializers specified like this in a static library are just dropped.

On Windows, it seems like the linker will actually keep the section. That, or I got lucky. But Linux and Mac? No, the section is just silently dropped. I have tried various mechanisms around this, but without success. The closest is maybe Clang's [retain attribute](https://clang.llvm.org/docs/AttributeReference.html#retain), which has this blurb in the docs:

> This attribute, when attached to a function or variable definition, prevents section garbage collection in the linker. **It does not prevent other discard mechanisms, such as archive member selection**, and COMDAT group resolution.

(Emphasis mine.) So this specifically does  not help.

The nuclear option around this problem is to use the linker flag `--whole-archive` for every static library that you suspect has relevant data in your custom section. Using the whole archive options means that the linker doesn't perform the archive member selection mentioned above (but it could still eliminate unused data later).

There are multiple issues with `--whole-archive`: First, you now also pull in a lot of data that previously was dropped. So the output is likely larger, unless later steps in the linker happen to prune them again -- but who knows whether that is actually happening. Second, you now need to know which libraries even contain data in your sections. You often can't just apply `--whole-archive` everywhere without suddenly ending up with multiple definitions. This is all very sad, since the beauty of this method for me is that data is collected automatically and nobody had to manually figure out what initializers come from where.

At least on Windows this very section mechanism is also used for the CRT. So how do _they_ do it? Well, first off I never ran into any issues on Windows anyway. Additionally, `link.exe` does have a `/SECTION` flag that you can use to tell it to keep a section, e.g. `/SECTION:.mysection,R`. I have not tried it, because I didn't have any problems in the first place.

With lld on Linux/Mac, there is still the possibility that a custom linker script would help. Linux uses the `.init_array` section for such initializers, and `ld`'s [default linker script](https://gist.github.com/csukuangfj/c4bd4f406912850efcbedd2367ac5f33#file-default-linker-script-txt-L123) explicitly keeps that section alive. However, for `lld` specifically there is no default linker script (it's just some native code instead), and apparently there is no way to say "use default behavior and also run this minimal linker script." My gut instinct says that going down the custom linker script route is going to cause a good bit of pain, so I have not done that.

On a meta note: I would of course much rather talk about how I totally made this work using a combination of obscure linker flags. But documenting dead-ends is just as important.
