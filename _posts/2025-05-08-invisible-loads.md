---
layout: post
title: Invisible loads and why I like free-standing functions
excerpt:
tags: []
---

I have been grappling with a really silly C++ problem for a long time: I don't like member functions, but I need to write member functions to get a decent programming UX. Member functions give me two things: scoping and discoverability. Scoping is the lesser of the two, because my C++ code already does not use private/public. Discoverability is the big one: I can type `x.F` and the IDE will suggest `x.Func()`. Nice! "But real programmers only use vim and shun IDEs." Welcome, fellow ~~Unreal~~ ~~imaginary~~ regular programmers. You're safe here, and please take both a "vim sucks" and a "I hate emacs" badge when you leave: they are great conversation starters for talking to "real" programmers.

So why do I not like member functions? Invisible loads. Take this example here:

```cpp
struct X {
    int64_t Size;

    void DoThing() 
    {
        for (int64_t k = 0; k < Size; k++) {
            // ...
        }
    }
};
```

Note how this actually is
```cpp
void DoThing(X* that) {
    for (int64_t k = 0; k < that->Size; k++) {
        // ...
    }
}
```

It looks like we are accessing a local variable, but we are actually telling the compiler to reload `this->Size` in every loop iteration. When I say this the common replies are:
 * "Why don't you just use a prefix for members? `m_Size`?" - That helps, but it still does not insert the friction of having to type `this->m_Size`. Friction is a tool to discourage people from doing stuff they should not do without thinking about it (see [this post]({% post_url 2024-09-16-get-people-to-do-the-right-thing %})).
 * "Should people really think about this?" - In some software domains, they absolutely should. I don't know your context, but your answer will obviously depend on that. I am saying "I don't like this", not "this is a universal truth."
 * "Does the compiler not automatically get rid of the load?" - Well, sometimes. Maybe. Unless you call a function and the compiler can't rule out that it changes this field. Or maybe your function gets big and someone hardcoded a limit into the compiler for it to just give up on large functions.
 * "Does it even make a difference?" - It depends! First, doing it in one place that is frequently called can totally make a difference. I made some changes to animation code in a widely used engine, and eliminating redundant loads across the board had massive impacts (~10%) and greatly improved codegen. Second, doing it *everywhere* surely also makes a difference. I recently made this sort of change in just one pattern (of many) in some codegen, and binary sizes dropped by 50kb.

I have recently also looked at the options that are available to help the compiler to understand when it is safe to hoist a load, i.e. only do it once. Consider this loop, where we call a function that is not inlined:
```cpp
void DoThing(X* that) {
    for (int64_t k = 0; k < that->Size; k++) {
        FuncThatIsNotInlined(k);
    }
}
```

It's perfectly possible that `FuncThatIsNotInlined` has access to the value of `that` and can mutate it. For example:
```cpp
static X* gPtr;

void CallThing(X* that){
    gPtr = that;
    DoThing(that);
}

void FuncThatIsNotInlined(int64_t k)
{
    if (k > 0 && gPtr)
        gPtr->Size += 17;
}
```

First, here are some things that *do not* help: `DoThing(const X* that)` doesn't help, because `const` is easily cast away and just means that *you* can't change it, not that nobody else can. `DoThing(__restrict X* that)` doesn't help in this case, because `__restrict` only tells the compiler that your pointer does not alias in the current scope. Globally, it could still alias.

The things that do help are:
 * inlining, because it gives the compiler more information about what a function is doing,
 * LTO/LTCG, because it leads to more inlining,
 * function attributes that tell the compiler some important properties outside of inlining,

Both MSVC and Clang/GCC have attributes that help to a degree.

## MSVC
MSVC has a `__declspec(noalias)` that you can put on function declarations, like this:
```cpp
__declspec(noalias) void FuncThatIsNotInlined(int64_t k);
```
Find it [on MSDN here](https://learn.microsoft.com/en-us/cpp/cpp/noalias?view=msvc-170). From there:

> `noalias` means that a function call doesn't modify or reference visible global state and only modifies the memory pointed to directly by pointer parameters (first-level indirections).

If `FuncThatIsNotInlined` is marked as `noalias`, then the compiler knows that it may not reference global state. You can see the small codegen difference [on Godbolt](https://godbolt.org/#g:!((g:!((g:!((h:codeEditor,i:(filename:'1',fontScale:14,fontUsePx:'0',j:1,lang:c%2B%2B,selection:(endColumn:21,endLineNumber:1,positionColumn:21,positionLineNumber:1,selectionStartColumn:21,selectionStartLineNumber:1,startColumn:21,startLineNumber:1),source:'%23include+%3Ccinttypes%3E%0A%0Avoid+FuncThatIsNotInlined(int64_t+k)%3B%0A__declspec(noalias)+void+FuncThatIsNotInlined_NoAlias(int64_t+k)%3B%0A%0Astruct+X+%7B%0A++++int64_t+Size%3B%0A%7D%3B%0A%0Avoid+DoThing(X*+that)%0A%7B%0A++++for+(int64_t+k+%3D+0%3B+k+%3C+that-%3ESize%3B+k%2B%2B)%0A++++++++FuncThatIsNotInlined(k)%3B%0A%7D%0A%0Avoid+DoThing2(X*+that)%0A%7B%0A++++for+(int64_t+k+%3D+0%3B+k+%3C+that-%3ESize%3B+k%2B%2B)%0A++++++++FuncThatIsNotInlined_NoAlias(k)%3B%0A%7D'),l:'5',n:'0',o:'C%2B%2B+source+%231',t:'0')),k:46.402564938593635,l:'4',n:'0',o:'',s:0,t:'0'),(g:!((h:compiler,i:(compiler:vcpp_v19_43_VS17_13_x64,filters:(b:'0',binary:'1',binaryObject:'1',commentOnly:'0',debugCalls:'1',demangle:'0',directives:'0',execute:'1',intel:'0',libraryCode:'0',trim:'1',verboseDemangling:'0'),flagsViewOpen:'1',fontScale:14,fontUsePx:'0',j:1,lang:c%2B%2B,libs:!(),options:/O2,overrides:!(),selection:(endColumn:1,endLineNumber:1,positionColumn:1,positionLineNumber:1,selectionStartColumn:1,selectionStartLineNumber:1,startColumn:1,startLineNumber:1),source:1),l:'5',n:'0',o:'+x64+msvc+v19.43+VS17.13+(Editor+%231)',t:'0'),(h:compiler,i:(compiler:clang2010,filters:(b:'0',binary:'1',binaryObject:'1',commentOnly:'0',debugCalls:'1',demangle:'0',directives:'0',execute:'1',intel:'0',libraryCode:'0',trim:'1',verboseDemangling:'0'),flagsViewOpen:'1',fontScale:14,fontUsePx:'0',j:2,lang:c%2B%2B,libs:!(),options:'-fms-extensions+-O3',overrides:!(),selection:(endColumn:1,endLineNumber:1,positionColumn:1,positionLineNumber:1,selectionStartColumn:1,selectionStartLineNumber:1,startColumn:1,startLineNumber:1),source:1),l:'5',n:'0',o:'+x86-64+clang+20.1.0+(Editor+%231)',t:'0')),k:53.59743506140637,l:'4',n:'0',o:'',s:0,t:'0')),l:'2',n:'0',o:'',t:'0')),version:4): the repeated load is gone.

## Clang/GCC
Clang and GCC have the attributes `__attribute__((const))` and `__attribute__((pure))` (see [docs](https://gcc.gnu.org/onlinedocs/gcc/Common-Function-Attributes.html)). Const functions are closest to what a mathematical function is: the result only depends on the direct value of the parameters (i.e. no pointer dereferencing, no global state), and it does not affect the state of the program. In particular, it doesn't make sense for a const function to return `void` or to take any pointer parameters, because you aren't allowed to read them (...unless you know that the pointed to values never changes). Pure functions are a bit more useful: they may take pointer parameters and read the values pointed to.

The MSVC `__declspec(noalias)` is not directly comparable to either of the Clang/GCC attributes. The MSVC attribute allows you to modify whatever parameters may point to, the latter don't. However, `noalias` forbids you from referencing global state, whereas that is not actually ruled out with the GCC attributes, as long as reading the global state doesn't make a difference.

C23 contains two attributes that are related to this: `[[unsequenced]]` and `[[reproducible]]`. If these names make no sense to you, rest assured that this is not your fault. The definitions for all of these attributes are subtle (I am not ruling out getting stuff wrong here as well) and they are slightly more general versions of `const` and `pure`, respectively. I found the proposal [Unsequenced functions](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2887.htm) by Étienne Alepins and Jens Gustedt quite readable.

## Does that help?
If you play around with these attributes, you will find that in small, isolated cases they do help. However, in larger functions it is almost impossible to ensure that all functions can be marked up like this: Maybe a function touches global state and is not pure, but you still know that _this particular thing_ is not changed. The GCC `const` attribute in particular is so restrictive that I have not encountered cases where you would not just make the entire function `inline` and put it into a header. (I'm sure others have!)

I wish there was a magic attribute that you could pepper around in your codebase and magically solve this problem, but having dealt with this for a while now, I have not been able to formulate what it should be. The information you need to convey is often of the form "this specific thing does not change from this point on." What if it contains pointers? Are their targets included? To what depth? etc. Another common scenario is "This function may change things on the first call, but it is still idempotent and repeated calls can be dropped."

In the end, I always found that it is the least amount of pain to just manually eliminate the redundant reads and move on with your life.