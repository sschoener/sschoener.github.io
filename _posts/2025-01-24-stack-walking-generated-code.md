---
layout: post
title: Stack-Walking and generated code
tags: []
---

_Hey! You can find me on [Mastodon](https://mastodon.gamedev.place/@sschoener) and [Bluesky](https://bsky.app/profile/sschoener.bsky.social)!_

Last summer I looked at capturing callstacks ([here]({% post_url 2024-08-13-callstacks %}) and [here]({% post_url 2024-08-15-more-callstacks %})) and ultimately landed on using `RtlCaptureStackBackTrace`. I had a short note saying that `StackWalk64` was a slower alternative and that I had not found cases in which they disagreed. Now I have!

I am currently working with inserting hooks into other processes, for debugging purposes: my use case is that I want to understand what function of an API surface is called where (yes, there are flaws with that idea), which is what my hooks hopefully provide. The hooks should be as well-behaved as possible, and we already saw [recently]{% post_url 2025-01-17-access-violation-aligned-access %} that you have to carefully read the x64 calling conventions to not break things.

My hooks should especially work with stackwalking. My hooks are calling arbitrary other functions, so they are not leaf functions, which means that they need to have unwind information associated with them for stack walking to work. You can find all the details about this on MSDN ([x64 exception handling](https://learn.microsoft.com/en-us/cpp/build/exception-handling-x64?view=msvc-170#unwind-data-for-exception-handling-debugger-support)).

Here is the gist:
 * On x64 Windows, functions must adhere to strict requirements for their prolog, epilog, and everything in between. For example, you are not allowed to push to the stack in the middle of your function (only in the prolog), and if you use `alloca`, you also have to use a framepointer.
 * This allows Windows to get away with a rather minimal set of static unwind data: the code and data required to support stack unwinding for handling exceptions is completely out of the way of your function. Unless you have multiple exception handlers, you only need a single `UNWIND_INFO` struct in your static data.
 * The `UNWIND_INFO` contains a bunch of opcodes for how to unwind your function's stack. It is designed such that you only need to care about your functions prolog. There are three scenarios at runtime:
    1. Unwinding while executing the prolog: Then you only need to execute a subset of the opcodes.
    2. Unwinding while executing the epilog: the stack walking code can detect this because of the strict rules around code structure and just continue to execute the epilog.
    3. Unwinding outside of both: Then you need to execute all of the unwind opcodes.

This means that if you generate code, you also need to generate unwind info for it. This is conceptually simple but very poorly documented. Peter Meerwald-Stadler saves the day with [Windows RtlAddFunctionTable, the missing documentation](https://pmeerw.net/blog/programming/RtlAddFunctionTable.html). The crucial detail is that when you register your unwind information ("add a function table"), you get to choose the "image base", and all your offsets are relative to that base you have chosen. The base is completely arbitary, which I initially found very irritating.

I ended up using `RtlAddGrowableFunctionTable` ([MSDN](https://learn.microsoft.com/en-us/windows/win32/api/winnt/nf-winnt-rtladdgrowablefunctiontable)), which works the same way but is probably more efficient if you have many functions.

So now a few paragraphs in we finally get to the point of this blogpost: Even if you do everything right and your generated code is correct and the unwind information is present, `RtlCaptureStackBackTrace` will not use it.

What I observed in practice:
 * When adding unwind information using either `RtlAddFunctionTable`, `RtlAddGrowableFunctionTable`, or `RtlInstallFunctionTableCallback`, you can validate that it works by querying for your data using `RtlLookupFunctionEntry`.
 * The debugger is going to be able to unwind your function if you registered the data and `RtlLookupFunctionEntry` found it. Similarly, ETW stackwalking is going to work for your function.
 * `RtlCaptureStackBackTrace` will *not* work for your function. It seems to ignore dynamically added function tables. I have stepped through it and it fails to find the dynamic table at all. I do not know why, but it looks like it branches on whether this is loaded code with static tables, and if not it makes minimal effort to find your table but seemingly not enough effort to actually find it.

I am not switching to `StackWalk64` just yet. For the moment, I realized that you can do this and it will work:
```cpp
static int64_t GetBackTrace(int64_t framesToSkip, int64_t backTraceSize, void** outBackTrace)
{
    CONTEXT context;
    RtlCaptureContext2(&context);

    int64_t frameCount = 0;
    UNWIND_HISTORY_TABLE table{};

    while (context.Rip != 0 && context.Rsp != 0)
    {
        if (frameCount >= framesToSkip && frameCount - framesToSkip < backTraceSize) {
            outBackTrace[frameCount - framesToSkip] = (void*)context.Rip;
        }
        frameCount++;

        DWORD64 imageBase;
        RUNTIME_FUNCTION* function = RtlLookupFunctionEntry(context.Rip, &imageBase, &table);

        // If there is no function entry, then this is a leaf function
        if (function == nullptr)
        {
            // Unwind the leaf: RSP points to the old RIP
            context.Rip = *(DWORD64*)context.Rsp;
            context.Rsp += sizeof(DWORD64);
            continue;
        }
        else {
            void* handlerData;
            DWORD64 establisherFrame;
            RtlVirtualUnwind(UNW_FLAG_NHANDLER, (DWORD64)imageBase, context.Rip, function, &context, &handlerData, &establisherFrame, nullptr);
        }
    }
    if (frameCount < framesToSkip)
        return 0;
    return frameCount - framesToSkip;
}
```
I have not quantified how much slower this is than `RtlCaptureStackBackTrace`. I am sure it is slower, but for my current scenario I need the correctness. Note that this function continues to walk the stack even if the output buffer is already full and then returns the required size for a matching buffer.


{% include clickable-image.html %}