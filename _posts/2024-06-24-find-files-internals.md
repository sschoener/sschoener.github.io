---
layout: post
title: How to use NtQueryDirectoryFileEx instead of FindFirstFile
excerpt:
tags: []
---

I [recently]({% post_url 2024-06-09-find-first-large-fetch %}).recently covered `FIND_FIRST_EX_LARGE_FETCH` for `FindFirstFileExW`, which instructs the function to use a larger buffer for listing (or searching) files in a directory, thus saving on expensive trips down to the I/O device. Before I could even fully articulate the thought that it ought to be possible to control the entire buffer in userspace, [Per Vognsen](https://mastodon.gamedev.place/deck/@pervognsen@mastodon.social) had already suggested using `NtQueryDirectoryFileEx` for exactly that purpose. (That's one reason why I write things down: It's a great way to learn more.)

`NtQueryDirectoryFileEx` is an interesting function: It is not part of the actual Win32 API, but it is still well-documented and exposed. The reason for this is that the function is part of the Windows Driver Kit. The [NtQueryDirectoryFileEx MSDN page](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntifs/nf-ntifs-ntquerydirectoryfileex) puts the function into the "Kernel" section of the documentation, but that does not matter for us.

The first question you may have is "is it safe to call this lower level API?" I am by no means an expert on this, but [Pavel Yosifovich's](https://scorpiosoftware.net/) books document this behavior:

- Windows exposes its kernel calls as exports from `ntdll.dll`. This is a userspace DLL and all processes load this DLL (with some irrelevant exceptions for special process types that you can't manually create).
- Functions in `ntdll.dll` just setup some parameters and then use `syscall` to trap into the actual kernel code.
- Kernel functions come in two flavors, `Nt` (nutty) and `Zw` (zweet)[^flavors]. The two flavors mostly share the same implementation and behave identical when called from userspace, but when called from the kernel you should call the `Zw` variant: It will know that the parameters come from trusted kernel space, which can save some validation and remapping.
- It hence seems reasonable to assume that the `Nt` version is exposed to userspace on purpose, because otherwise what's the point.

All of this is to say that `NtQueryDirectoryFileEx` and many other functions are established, exposed, callable, and well-documented parts of the effective API surface Windows provides. So yes, it's safe to call it.

Which brings us to the second question: How do you call it? One option is to get the Windows Driver Kit and use the headers provided there, then link against `ntdll`. A second option is to instead use the headers from the [phnt project](https://github.com/winsiderss/phnt), which documents core Windows APIs. A third option is to say "eh, I don't need any of that" and see how far you get by just copying together the minimum set of things you need to use the core functionality:

```cpp
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

// link against ntdll
#pragma comment( lib, "ntdll" )

// https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/wdm/ns-wdm-_io_status_block?redirectedfrom=MSDN
typedef struct _IO_STATUS_BLOCK {
  union {
    NTSTATUS Status;
    PVOID    Pointer;
  };
  ULONG_PTR Information;
} IO_STATUS_BLOCK, *PIO_STATUS_BLOCK;

// https://learn.microsoft.com/en-us/windows/win32/api/ntdef/ns-ntdef-_unicode_string
typedef struct _UNICODE_STRING {
  USHORT Length;
  USHORT MaximumLength;
  PWSTR  Buffer;
} UNICODE_STRING, *PUNICODE_STRING;

// See the handy table linked on the page below to learn where these values comes from.
// https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/using-ntstatus-values
constexpr NTSTATUS STATUS_NO_MORE_FILES = 0x80000006;
constexpr NTSTATUS STATUS_NO_SUCH_FILE = 0xC000000F;

extern "C" {
    NTSYSCALLAPI NTSTATUS NTAPI NtQueryDirectoryFileEx(
        HANDLE FileHandle,
        HANDLE Event,
        // This here is PIO_APC_ROUTINE, but we don't use APCs and just set it to null.
        PVOID ApcRoutine,
        PVOID ApcContext,
        PIO_STATUS_BLOCK IoStatusBlock,
        // The struct for this depends on what information you need. All documented here:
        // https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntifs/nf-ntifs-ntquerydirectoryfileex
        PVOID FileInformation,
        ULONG Length,
        // This is FILE_INFORMATION_CLASS, which I am not going to paste here.
        // https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/wdm/ne-wdm-_file_information_class
        DWORD FileInformationClass,
        ULONG QueryFlags,
        // Your puns here.
        PUNICODE_STRING FileName
    );
}
```

That's not too bad. Now you need to pick a file information class (e.g. `FileDirectoryInformation`) and look up its output struct, like this:

```cpp
typedef struct _FILE_DIRECTORY_INFORMATION
{
    ULONG NextEntryOffset;
    ULONG FileIndex;
    LARGE_INTEGER CreationTime;
    LARGE_INTEGER LastAccessTime;
    LARGE_INTEGER LastWriteTime;
    LARGE_INTEGER ChangeTime;
    LARGE_INTEGER EndOfFile;
    LARGE_INTEGER AllocationSize;
    ULONG FileAttributes;
    ULONG FileNameLength;
    WCHAR FileName[1];
} FILE_DIRECTORY_INFORMATION;
```

Finally, we can use `NtQueryDirectoryFileEx` like this:

```cpp
// We need to first get a handle to the directory we want to list files in.
HANDLE dirHandle = CreateFileW(YOUR_DIRECTORY_PATH_HERE,
    FILE_LIST_DIRECTORY,
    FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
    nullptr,
    OPEN_EXISTING,
    FILE_FLAG_BACKUP_SEMANTICS,
    0
);

// You probably want to allocate this buffer somewhere outside the stack.
uint8_t buffer[1024 * 64];
// This is one of the flags we can pass to the function, it causes the scan to start from scratch.
constexpr DWORD SL_RESTART_SCAN = 0x1;
constexpr DWORD FileDirectoryInformation = 0x1;
IO_STATUS_BLOCK statusBlock;
ZeroMemory(&statusBlock, sizeof(statusBlock));

NTSTATUS status = NtQueryDirectoryFileEx(
    dirHandle, 0, nullptr, nullptr,
    &statusBlock, buffer, sizeof(buffer),
    FileDirectoryInformation,
    SL_RESTART_SCAN,
    nullptr
);
const size_t bytesWritten = (size_t)statusBlock.Information;
if (bytesWritten == 0 || status == STATUS_NO_SUCH_FILE) {
    // No file entries found -- this is impossible in this case because we did not
    // specifiy a search string, so we'll find '.' and '..' at the very least.
    CloseHandle(dirHandle);
    return;
}
ASSERT(status >= 0, "NtQueryDirectoryFileEx failed");

FILE_DIRECTORY_INFORMATION* file = (FILE_DIRECTORY_INFORMATION*)buffer;
while (true) {
    // Do something with the file here!

    if (file->NextEntryOffset != 0) {
        file = (FILE_DIRECTORY_INFORMATION*)(((uint8_t*)file) + file->NextEntryOffset);
    } else {
        // Now just call the function again. The state of the search is implictly tied
        // to the handle we are using for the directory.
        NTSTATUS status = NtQueryDirectoryFileEx(
                dirHandle, 0, nullptr, nullptr,
                &statusBlock, buffer, sizeof(buffer),
                FileDirectoryInformation,
                0,
                nullptr
        );
        if (status == STATUS_NO_MORE_FILES) {
            // we're done!
            break;
        }
        ASSERT(status >= 0, "NtQueryDirectoryFileEx failed while getting more files");
        file = (FILE_DIRECTORY_INFORMATION*)Buffer;
    }
}

CloseHandle(dirHandle);
```

That's all there is to it. It's really not all that bad. The speed-up you'll see from this of course depends on whether you benefit from larger buffers. Larger buffers beyond a certain point only benefit you when you have directories with many entries. Another benefit is that this function can run async (including with I/O completion ports), but I have not tried that myself.

[^flavors]: That is of course just non-sense. The `Nt` prefix should be pretty obvious, but MSDN goes out of its way to establish that `Zw` does _not_ mean _zweet_ on their [What Does the Zw Prefix Mean? page](https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/what-does-the-zw-prefix-mean-).
