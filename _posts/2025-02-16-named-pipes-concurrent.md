---
layout: post
title: Short note about concurrent access to named pipes
excerpt:
tags: []
---

I have just been bitten by some behavior of named pipes on Windows and I could not find it documented anywhere.

TL;DR: Do not use synchronous reads and writes concurrently in the same process on a duplex pipe. Make the read async, then continue to write synchronously if you need to.

Here is the setup. I have a named pipe in duplex mode used from two processes. The pipe is set to blocking and was created in process 1. Process 1 reads from the pipe asynchronously and occasionally writes to it synchronously. Process 2 opened the pipe using `CreateFile` and has one thread that continuously polls the pipe using synchronous reads, and another thread that occasionally wants to write to that pipe synchronously. That thread gets stuck, the `WriteFile` call blocks. This happens even though there is someone on the other side, continuously emptying the pipe by reading from it.

Here is an explanation for why this happens: `CreateFile` was called without `FILE_FLAG_OVERLAPPED`. Careful reading of MSDN reveals `If this flag is not specified, then I/O operations are serialized` (see [CreateFileA MSDN](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilea)). It makes perfect sense for files, but did not match my apparently incorrect mental model for pipes. If you get into this situation, you will notice that the `WriteFile` call finishes just when you get the polling thread to read something from the pipe: the I/O operations are serialized. The reading thread continuously issues synchronous `ReadFile` calls, and those only return when there is something to read. The concurrent `WriteFile` calls only go through once that `ReadFile` has returned.

Curious behavior can be observed if you open the pipe with `FILE_FLAG_OVERLAPPED`, but keep everything else the same (i.e. you do not actually pass `OVERLAPPED` to `ReadFile` and `WriteFile`). In this case the `WriteFile` operation finishes immediately, and the concurrent `ReadFile` returns early (successfully!) with 0 bytes read, at least sometimes. You are likely to still see hangs. The fix for this is to move the `ReadFile` to actually use an `OVERLAPPED` structure.
