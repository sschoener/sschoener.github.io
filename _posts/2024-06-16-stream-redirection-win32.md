---
layout: post
title: How to redirect stdout using Win32, async
excerpt:
tags: []
---

I am writing a small program that needs (wants?) to start a thousand little other processes and capture their output. I am taking this as an opportunity to finally learn more about async I/O on Windows. I have never used async I/O on Windows without a wrapper (C# makes this very easy, for example) so it is high time I actually understand a bit more about the entire stack involved here.

I am using named pipes to redirect the output of the processes, but all of what I am saying here about async I/O is essentially also applicable to regular file I/O. In fact, the Win32 API for the most part does not distinguish between where you are reading from or writing to. A named pipe is then simply a buffer that some process can write to and another process can read from in a streaming fashion. This is done using the regular `ReadFile` / `WriteFile` functions. The idea is then to give the writer-end of the pipe to the process we spawn and then read from the reader-end. An important detail here is that by default all of these reads and writes are blocking and a write in particular may wait indefinitely when the intermediate buffer is full, unless both sides of the pipe are specifically setup to handle non-blocking pipes (which irritatingly is a separate concept from async I/O - [MSDN's Named Pipe Type, Read, and Wait Modes page](https://learn.microsoft.com/en-us/windows/win32/ipc/named-pipe-type-read-and-wait-modes) specifically tells you not to use non-blocking pipes as they are merely there for compatibility reasons). It seems pretty likely to me that most programs do not treat their stdout as a non-blocking pipe. As such it is necessary to actually read from stdout to ensure that the process you launched does not get stuck. If you do this synchronously you need at least two threads per process (one for stdout, one for stderr) to handle this. That's why I am looking at asynchronous I/O.

Async I/O on Windows means that you can call `ReadFile` and `WriteFile` but they return before the actual underlying I/O operation is finished. You indicate that you want async operations by setting their last parameter (a pointer to an `OVERLAPPED` struct) to a non-null value. But then how do you know when the operation is done? There are a bunch of different mechanisms for that:

- Asynchronous procdure calls (APC) are the least attractive options. They allow you to specify a callback that gets invoked some time after the I/O operation is actually done. I do not see any reason to recommend using APCs, and they mostly seem like a historical artifact (please educate me otherwise). The big downside of APCs are that they can only be invoked on the thread that initiated the I/O call, so that begs the question as to _when_ they get called: We can't just interrupt the thread at arbitrary points to run some callback. Instead, these APCs are invoked when your thread enters an "alertable wait state." You do this by calling for example `SleepEx` or one of the waiting functions such as `WaitForSingleObjectEx`. This [MSDN page on APCs](https://learn.microsoft.com/en-us/windows/win32/sync/asynchronous-procedure-calls) has more information. So in order to do non-blocking I/O with APCs, you need to block your thread (or regularly call `SleepEx` with a time of zero to check whether there are APCs to execute). Luckily you are unlikely to use APCs by mistake because you have to use `ReadFileEx` for this.
- Events objects are the first alternative, but also not what seems to be broadly recommended. To use this, you specify an event object (created using [CreateEvent](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-createeventw), for example) that shall be signalled when the I/O operation is done by setting a field in the `OVERLAPPED` struct. Then you can have another thread wait for that event handle. This would allow you to create a bunch of events and have a dedicated I/O thread wait for these events to become signalled and then do some I/O. This is fine, but there is a more specialized solution for this use-case, and that's the preferred option:
- I/O completion ports are what you really should be using. An I/O completion port works in much the same way as an event, except it is purpose-built for this particular use-case and claimed to be more efficient. To use an I/O completion port, you bind your file handle to the completion port and then have any thread (or even multiple) wait on the completion port and run whatever callbacks you need to run when the I/O operation is complete.

Instead of having our own threads wait for completion ports, we can also make use of the thread pool that Windows provides. It has native support for I/O completion ports. You do not need to manually initialize a thread pool, the default thread pool will create threads as needed. I am going to use this approach here, but using your own threads is not much harder.

Now for the actual implementation. My code is based on [Creating a Child Process with Redirected Input and Output](https://learn.microsoft.com/en-us/windows/win32/procthread/creating-a-child-process-with-redirected-input-and-output) from MSDN, but their example does not work with async I/O. Note that the code below does not handle errors meaningfully and is leaking handles on failure.

First, we need to create a pipes to redirect stdout and stderr. We cannot use the `CreatePipe` function, because the anonymous pipe it creates does not support async I/O. Instead we will manually create a named pipe in `CreateAsyncPipe` and get its read handle. Then we open that pipe for writing using `CreateFileW`. The handle that we get that way is then inherited by the process we create and set as its stdout (or stderr) handle:

```cpp
static void CreateAsyncPipe(HANDLE* outRead, HANDLE* outWrite)
{
    // Create a pipe. The "instances" parameter is set to 2 because we call this function twice below.
    // In a more realistic scenario, you should maybe generate a unique name to emulate anonymous pipes,
    // because otherwise you fail when this function is called multiple times.
    const wchar_t* pipeName = L"\\\\.\\pipe\\MyRedirectionPipe";
    constexpr DWORD Instances = 2;
    // Create the named pipe. This will return the handle we use for reading from the pipe.
    HANDLE read = CreateNamedPipeW(
        pipeNameExt,
        // Set FILE_FLAG_OVERLAPPED to enable async I/O for reading from the pipe.
        // Note that we still need to set PIPE_WAIT.
        PIPE_ACCESS_INBOUND | FILE_FLAG_OVERLAPPED,
        PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
        Instances,
        // in-bound buffer size
        4096,
        // out-going buffer size
        0,
        // default timeout for some functions we're not using
        0,
        nullptr
    );
    ASSERT(read != INVALID_HANDLE_VALUE, "Failed to create named pipe (error %d)", GetLastError());

    // Now create a handle for the other end of the pipe. We are going to pass that handle to the
    // process we are creating, so we need to specify that the handle can be inherited.
    // Also note that we are NOT setting FILE_FLAG_OVERLAPPED. We could set it, but that's not relevant
    // for our end of the pipe. (We do not expect async writes.)
    SECURITY_ATTRIBUTES saAttr;
    saAttr.nLength = sizeof(SECURITY_ATTRIBUTES);
    saAttr.bInheritHandle = TRUE;
    saAttr.lpSecurityDescriptor = NULL;
    HANDLE write = CreateFileW(pipeNameExt, GENERIC_WRITE, 0, &saAttr, OPEN_EXISTING, 0, 0);
    ASSERT(write != INVALID_HANDLE_VALUE, "Failed to open named pipe (error %d)", GetLastError());
    *outRead = read;
    *outWrite = write;
}

static void StartProcess(wchar_t* cmd, const wchar_t* dir, HANDLE* outReadStdOut, HANDLE* outReadStdErr, HANDLE* outProc)
{
    // Setup pipes to redirect stdout and stderr.
    HANDLE stdOutRead, stdOutWrite;
    CreateAsyncPipe(&stdOutRead, &stdOutWrite);
    HANDLE stdErrRead, stdErrWrite;
    CreateAsyncPipe(&stdErrRead, &stdErrWrite);

    PROCESS_INFORMATION procInfo;
    ZeroMemory(&procInfo, sizeof(procInfo));
    STARTUPINFO startupInfo;
    ZeroMemory(&startupInfo, sizeof(startupInfo));

    // Set handles and flags to indicate that we want to redirect stdout/stderr.
    startupInfo.cb = sizeof(startupInfo);
    startupInfo.hStdError = stdErrWrite;
    startupInfo.hStdOutput = stdOutWrite;
    startupInfo.dwFlags = STARTF_USESTDHANDLES;

    BOOL success = CreateProcessW(
        nullptr,
        cmd, // for some interesting reason, this cannot be a const pointer
        nullptr,
        nullptr,
        TRUE, // this indicates that we want to inherit handles
        0,
        nullptr,
        dir,
        &startupInfo,
        &procInfo
    );
    ASSERT(success, "Failed in CreateProcessW (error %d)", GetLastError());

    // Now we can must close the write-handles for our pipes. The write handle has been inherited by the
    // subprocess, and if we don't close these handles the writing end of the pipe is staying open indefinitely.
    // Then our read-calls would keep waiting even when the child process has already exited.
    CloseHandle(stdOutWrite);
    CloseHandle(stdErrWrite);

    // Avoid leaking the thread handle.
    CloseHandle(procInfo.hThread);

    *outProc = procInfo.hProcess;
    *outReadStdOut = stdOutRead;
    *outReadStdErr = stdErrRead;
}
```

Now we still need to setup the actual reading from the pipes. The general flow here is as follows:

- We create some struct `FileReadBuffer` to hold all of our intermediate information. We setup the thread pool to call a custom function `FileReadComplete` once the async I/O request on our file handle is done by calling `CreateThreadpoolIo`.
- We call `ReadFile` and set the last argument to an instace of `OVERLAPPED`, which indicates that this is an async read. This call returns `false` if the I/O is happening async, and there are a bunch of error conditions that we need to handle.
- When the read operation is done, we check whether we have reached the end of the stream (in which case the error should be set to `ERROR_BROKEN_PIPE`) and if not we schedule another read.

The only additional detail to this flow is that we also add a timer that we can have the thread pool wait on. The docs for `ReadFile` specifically call out that you could get an error for when there are too many async I/O operations in flight, and in this case we wait and try again later.

```cpp
struct FileReadBuffer
{
    OVERLAPPED Overlapped;
    // Some buffer to read into
    void* Buffer;
    size_t BufferSize;
    // The handle to the file or pipe.
    HANDLE FileHandle;
    PTP_IO Io;
    PTP_TIMER Timer;
};

static void ScheduleFileRead(FileReadBuffer* readBuffer) {
    // Prepare the threadpool for an I/O request on our handle.
    StartThreadpoolIo(readBuffer->Io);
    BOOL success = ReadFile(
        readBuffer->FileHandle,
        readBuffer->Buffer,
        readBuffer->BufferSize,
        nullptr,
        &readBuffer->Overlapped
    );
    if (!success ) {
        DWORD error = GetLastError();
        if (error == ERROR_IO_PENDING) {
            // Async operation is in progress. This is NOT a failure state.
            return;
        }
        // Since we have started an I/O request above but nothing happened, we need to cancel it.
        CancelThreadpoolIo(readBuffer->Io);

        if (error == ERROR_INVALID_USER_BUFFER || error == ERROR_NOT_ENOUGH_MEMORY) {
            // Too many outstanding async I/O requests, try again after 10 ms.
            // The timer length is given in 100ns increments, negative values indicate relative
            // values. FILETIME is actually an unsigned value. Sigh.
            constexpr int ToMicro = 10;
            constexpr int ToMilli = 1000;
            constexpr int64_t Delay = -(10 * ToMicro * ToMilli);
            FILETIME timerLength{};
            timerLength.dwHighDateTime = (Delay >> 32) & 0xFFFFFFFF;
            timerLength.dwLowDateTime = Delay & 0xFFFFFFFF;
            SetThreadpoolTimer(readBuffer->Timer, &timerLength, 0, 0);
            return;
        }
        CloseThreadpoolTimer(readBuffer->Timer);
        CloseThreadpoolIo(readBuffer->Io);
        if (error == ERROR_BROKEN_PIPE)
        {
            // YOUR CODE HERE
            // We've read the entire thing, what now?
            return;
        }
        ASSERT(error == ERROR_OPERATION_ABORTED, "ReadFile async failed, error code %d", error);
    }
}

static void CALLBACK FileReadComplete(
    PTP_CALLBACK_INSTANCE instance,
    void* context,
    void* overlapped,
    ULONG ioResult,
    ULONG_PTR numBytesRead,
    PTP_IO io
    )
{
    FileReadBuffer* readBuffer = (FileReadBuffer*)context;
    if (ioResult == ERROR_OPERATION_ABORTED) {
        // This can happen when someone manually aborts the I/O request.
        CloseThreadpoolTimer(readBuffer->Timer);
        CloseThreadpoolIo(readBuffer->Io);
        return;
    }
    const bool isEof = ioResult == ERROR_HANDLE_EOF || ioResult == ERROR_BROKEN_PIPE;
    ASSERT(isEof || ioResult == NO_ERROR, "Got error result %u while handling I/O callback", ioResult);

    // YOUR CODE HERE
    // E.g. enqueue the numBytesRead bytes in readBuffer->Buffer to some other buffer.

    if (isEof) {
        CloseThreadpoolTimer(readBuffer->Timer);
        CloseThreadpoolIo(readBuffer->Io);

        // YOUR CODE HERE
        // We've read the entire thing, what now?
    } else {
        // continue reading
        ScheduleFileRead(readBuffer);
    }
}

static void InitFileReadBuffer(FileReadBuffer* readBuffer, HANDLE handle, void* buffer, size_t bufferSize)
{
    ZeroMemory(readBuffer, sizeof(*readBuffer));
    readBuffer->Buffer = buffer;
    readBuffer->BufferSize = bufferSize;
    readBuffer->FileHandle = handle;
    readBuffer->Io = CreateThreadpoolIo(handle, &FileReadComplete, readBuffer, nullptr);
    ASSERT(readBuffer->Io, "CreateThreadpoolIo failed, error code %d", GetLastError());

    // This local struct just exists so I can declare a function here that we can pass to the timer below.
    struct Tmp {
        static void CALLBACK RetryScheduleFileRead(
            PTP_CALLBACK_INSTANCE instance,
            void* context,
            PTP_TIMER wait
        ) {
            ScheduleFileRead((FileReadBuffer*)context);
        }
    };

    readBuffer->Timer = CreateThreadpoolTimer(&Tmp::RetryScheduleFileRead, readBuffer, nullptr);
    ASSERT(readBuffer->Timer, "CreateThreadpoolTimer failed, error code %d", GetLastError());
}
```

Putting it all together, you can start a process and schedule an async read from stdout like so:

```cpp
HANDLE stdOut, stdErr, proc;
StartProcess(command, workingDir, &stdOut, &stdErr, &proc);

// Keep these buffers alive until all read operations have finished
uint8_t* buffer = new uint8_t[4096];
FileReadBuffer* fileRead = new FileReadBuffer();
InitFileReadBuffer(fileRead, stdOut, buffer, 4096);
ScheduleFileRead(fileRead);
```

While I would really love to conclude this post with some notes about the performance of this approach (compared to using events, for example), there is nothing to report yet: my program is unsurprisingly mostly bottle-necked by starting up many small processes, and any I/O timings are just noise compared to that.
