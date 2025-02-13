---
layout: post
title: Getting stack traces for SEH exceptions
excerpt:
tags: []
---

I wanted to leave a note about SEH exceptions ([MSDN](https://learn.microsoft.com/en-us/cpp/cpp/structured-exception-handling-c-cpp)) and getting callstacks because when I first saw it, the behavior really tripped me up. For the uninitiated: On Windows, there is a built-in mechanism to handle faults like access faults (e.g. accessing a bad pointer). It goes by the name of "Structured Exception Handling", or SEH for short. When a fault happens, an exception is triggered that you can then handle. "Exception" here doesn't necessarily mean "C++ `std::exception`". If you compile your program with neither `/EHsc` nor `/EHa`, then you do not have C++ exceptions enabled but SEH still exists. Otherwise SEH will be converted into regular C++ exceptions. I'm interested in the case where C++ exceptions are disabled. If you are unlucky enough to use CMake, you can for example do this to disable exceptions:
```
# Remove exception handling support on MSVC.
string(REPLACE "/EHsc" "" CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS})
string(REPLACE "/EHa" "" CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS})
```

The way that you handle an SEH exception is shown below. Pay special attention to the exception filter ([MSDN](https://learn.microsoft.com/en-us/cpp/cpp/writing-an-exception-filter)), which allows you to filter when your exception handler should run:
```cpp
int SEHFilter(int exceptionCode, struct _EXCEPTION_POINTERS* exceptionInfo)
{
    // The return code determines whether we run the handler or continue the search for another handler.
    return EXCEPTION_EXECUTE_HANDLER;
}

void MyCode()
{
    __try // open a guarded section
    {
        // your code here
    }
    __except (SEHFilter(GetExceptionCode(), GetExceptionInformation()))
    {
        // Your exception handler here. Could be empty!
    }
}
```

The exception filter is generally optional, but you may only call `GetExceptionInformation` and `GetExceptionCode` in the filter.

So how do we use this to print out a stacktrace when something goes horribly wrong? The first idea might be to put something into the exception handler, but this gives you a stacktrace of the handler itself, not of the place where the exception occurred. However, the exception handler _filter_ still runs on the same stack that caused the fault. That makes perfect sense once you know about it, but it took me a while to realize this. So we can write code like this:

```cpp

static const char* GetExceptionName(int exceptionCode)
{
    switch (exceptionCode)
    {
    case EXCEPTION_ACCESS_VIOLATION: return "ACCESS_VIOLATION";
    case EXCEPTION_DATATYPE_MISALIGNMENT: return "DATATYPE_MISALIGNMENT";
    case EXCEPTION_BREAKPOINT: return "BREAKPOINT";
    case EXCEPTION_SINGLE_STEP: return "SINGLE_STEP";
    case EXCEPTION_ARRAY_BOUNDS_EXCEEDED: return "ARRAY_BOUNDS_EXCEEDED";
    case EXCEPTION_FLT_DENORMAL_OPERAND: return "FLOAT_DENORMAL_OPERAND";
    case EXCEPTION_FLT_DIVIDE_BY_ZERO: return "FLOAT_DIVIDE_BY_ZERO";
    case EXCEPTION_FLT_INEXACT_RESULT: return "FLOAT_INEXACT_RESULT";
    case EXCEPTION_FLT_INVALID_OPERATION: return "FLOAT_INVALID_OPERATION";
    case EXCEPTION_FLT_OVERFLOW: return "FLOAT_OVERFLOW";
    case EXCEPTION_FLT_STACK_CHECK: return "FLOAT_STACK_CHECK";
    case EXCEPTION_FLT_UNDERFLOW: return "FLOAT_UNDERFLOW";
    case EXCEPTION_INT_DIVIDE_BY_ZERO: return "INTEGER_DIVIDE_BY_ZERO";
    case EXCEPTION_INT_OVERFLOW: return "INTEGER_OVERFLOW";
    case EXCEPTION_PRIV_INSTRUCTION: return "PRIVILEGED_INSTRUCTION";
    case EXCEPTION_IN_PAGE_ERROR: return "IN_PAGE_ERROR";
    case EXCEPTION_ILLEGAL_INSTRUCTION: return "ILLEGAL_INSTRUCTION";
    case EXCEPTION_NONCONTINUABLE_EXCEPTION: return "NONCONTINUABLE_EXCEPTION";
    case EXCEPTION_STACK_OVERFLOW: return "STACK_OVERFLOW";
    case EXCEPTION_INVALID_DISPOSITION: return "INVALID_DISPOSITION";
    case EXCEPTION_GUARD_PAGE: return "GUARD_PAGE_VIOLATION";
    case EXCEPTION_INVALID_HANDLE: return "INVALID_HANDLE";
    }
    return "UNKNOWN_EXCEPTION_CODE";
}

int SEHFilter(int exceptionCode, struct _EXCEPTION_POINTERS* exceptionInfo)
{
    // Get the current RIP
    void* rip = (void*)exceptionInfo->ContextRecord->Rip;
    Debug_PrintStacktrace(rip, "Failed with exception %s (0x%08X)", GetExceptionName(exceptionCode), exceptionCode);
    return EXCEPTION_EXECUTE_HANDLER; // or alternatively EXCEPTION_CONTINUE_SEARCH to let the exception play out
}
```

We extract the current instruction pointer and then use some code to extract a stack trace (see e.g. [here]({% post_url 2024-08-15-more-callstacks %})). We know that the instruction pointer of the instruction that raised the exception is in that stacktrace, and we throw away all frames before we see that address in the trace. Those frames belong to the SEH filter and its infrastructure infrastructure.

I do not know how this behaves with multiple nested exception handlers. In my code I have only one SEH exception handler: it just prints out the error and then intentionally crashes the program. I'd suspect that with multiple nested handlers (where you take the stacktrace in one of the outer handlers) it still just works, but I have not tried it.