---
layout: post
title: How does the Windows linker handle exported data?
excerpt:
tags: []
---

I recently had to understand the details of what happens when on Windows you have a global variable in a DLL and try to use it from another. I did not find this spelled-out anywhere, so let's change that.

If you want to export an integer with the name `gMyGlobalValue` from a DLL you do this:
```cpp
extern "C" __declspec(dllexport) int gMyGlobalValue;
```
On the side where you use it, you do this:
```cpp
extern "C" __declspec(dllimport) int gMyGlobalValue;
```
When you run your program, this happens: There is a well-known position in your program, and the OS-loader will put the address of `gMyGlobalValue` from the DLL into that well-known position, and then you can use that address to access the value from the DLL in your program.

This works when you work in C/C++, but if you happen to just get an object file without much control over its creation (...don't ask how I got here), then we need to use a different way: we can't add `__declspec(dllexport)` or `__declspec(dllimport)`. We can emulate all of this with some work on the exporting side and some work on the importing side.

For the exporting side, we can pass an exports definitions file to the linker (see [MSDN](https://learn.microsoft.com/en-us/cpp/build/exporting-from-a-dll-using-def-files?view=msvc-170)). The exports definition file would look like this:
```
EXPORTS
    gMyGlobalValue DATA
```
The crucial bit is the `DATA` keyword here.

On the importing side, we need to make sure that the linker does NOT look for `gMyGlobalValue` but for `__imp_gMyGlobalValue`. Then things just magically start working.

Why is this needed? The linker commonly deals with _functions_, not data. So when you export something and don't specify `DATA`, then the linker assumes this is a function. For functions, the linker does not just put the address of the function to call into a well-known position, but it also generates an _import thunk_: This is a simple function that contains nothing but an indirect jump to the imported function, using the address at the well-known position. So you have two symbols for your import: there is the well-known position, called `__imp_gMyGlobalValue`, and the import thunk, called just `gMyGlobalValue`. Specifying `DATA` in the exports defintion file just tells the linker that it does not need to generate an import thunk.

On the importing side, we need to specifically use `__imp_gMyGlobalValue`: if we used `gMyGlobalValue`, any code that uses the imported value would in effect treat the instructions in the import thunk as a pointer to an integer, which is _extra_ fun to debug. And that's all there is to it.