---
layout: post
title: How to get thread create/exit callbacks on Windows
excerpt:
tags: []
---

I recently needed to run a callback on thread shutdown and creation, on Windows. For exiting, you can apparently use `FlsAlloc` ([MSDN](https://learn.microsoft.com/en-us/windows/win32/api/fibersapi/nf-fibersapi-flsalloc)), which is a part of the Fiber API. I've tried that, it works. But there are other options!

If you have ever built a DLL on Windows, you will have noticed that you get this handy `BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved)` function for free. This function is called with different reasons: `DLL_(THREAD|PROCESS)_(DETACH|ATTACH)`. Hey, look, we get a callback on thread creation/exit.

This callback makes perfect sense: your DLL might contain thread-local data with dynamic initializers, and something needs to call them per thread. It's not `DllMain` directly that does this work, however: As with regular `main`, there is actually a C Runtime Library (CRT) stub around it[^corollary], called `_DllMainCRTStartup` ([MSDN](https://learn.microsoft.com/en-us/cpp/build/run-time-library-behavior?view=msvc-170#default-dll-entry-point-_dllmaincrtstartup)), which does the actual work.

It turns out that you can get the same callback anywhere else, even outside of DLLs. PE files may contain a `.tls` section, and if they do, then also a TLS directory. The directory describes the data necessary to initialize both simple TLS (where initialization is simply a `memcpy` by the loader) and TLS which requires a callback to initialize. That is exactly what we need and documented [on MSDN here](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#tls-callback-functions).

So, what we need to do:
 * Define a function that mimicks the signature of `DllMain`.
 * Tell the linker that this is a TLS callback, by placing a pointer to that function in a specific section.
 * Ensure that the linker doesn't ignore it. There are a bunch of things we have to do: We have to have a TLS value, and it needs to be used. Then that usage also can't be stripped by the linker. Then we also need to ensure that the linker does not strip our callback.


Full example below:
```c++
#include <cstdio>
#include <windows.h>

// Introduce a bogus TLS value and use it. Note the linker argument to tell the linker that
// this function should not be removed.
#pragma comment(linker, "/INCLUDE:ReadTls")
EXTERN_C int ReadTls() {
    static __declspec(thread) int DummyTlsVar = 0;
    return DummyTlsVar++;
}

// This is the actual callback callback.
static void NTAPI MyCallback(PVOID handle, DWORD reason, PVOID reserved) {
    if (reason == DLL_THREAD_ATTACH) { printf("Thread starting\n"); }
    else if (reason == DLL_THREAD_DETACH) { printf("Thread exiting\n"); }
    else if (reason == DLL_PROCESS_ATTACH) { printf("Process starting\n"); }
    else if (reason == DLL_PROCESS_DETACH) { printf("Process exiting\n"); }
}

// Create the section that the linker is looking for.
#pragma const_seg(".CRT$XLC")

// Put a pointer to the callback into the section, and make sure it is
// not stripped by the linker.
#pragma comment(linker, "/INCLUDE:__MyCallback")
EXTERN_C __declspec(allocate(".CRT$XLC")) PIMAGE_TLS_CALLBACK __MyCallback = MyCallback;
#pragma const_seg()

DWORD WINAPI MyThreadFunc(LPVOID param) {
    printf("Hello from thread\n");
    return 0;
}

int main() {
    printf("Hello from main\n");

    HANDLE thread = CreateThread(NULL, 0, MyThreadFunc, NULL, 0, NULL);
    WaitForSingleObject(thread, INFINITE);
    CloseHandle(thread);
    return 0;
}
```

The output in this case is:
```
Process starting
Hello from main
Thread starting
Hello from thread
Thread exiting
Process exiting
```
Note that you do not get a thread-callback for the main thread. I should also point out that `Process exiting` doesn't always print to console (depending on the build config): While the callback is always executed, it seems to be a silly idea to use `printf` during process shutdown.

[^corollary]: Which also means that if you work without a CRT, then you have to do that work manually. Static ctors work similarly.