---
layout: post
title: So there's also GetFileInformationByHandleEx
excerpt:
tags: []
---

I somehow stumbled into the niche of "how to enumerate files on Windows." Let's take a moment to regret my life choices together, before we return to our scheduled program of "yet another API I didn't know about." Jokes aside, I mentioned last time that writing is a great way to learn, and this has again proven true: Writing about [FIND_FIRST_EX_LARGE_FETCH]({% post_url 2024-06-09-find-first-large-fetch %}) lead to learning and writing about [NtQueryDirectoryFileEx]({% post_url 2024-06-24-find-files-internals %}), and this lead to [Jeremy Laumon](https://mastodon.gamedev.place/@jerem) telling me about `GetFileInformationByHandleEx` ([MSDN](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getfileinformationbyhandleex)), which combines the form factor of a proper Win32 API with explicit control over buffer sizes.

Let me show me how you use it, based on the usage in [Jeremy's awesome Asset Cooker project](https://github.com/jlaumon/AssetCooker/blob/f4f0cbfe0984175e321fe5ab9b574220b5ae92de/src/FileSystem.cpp#L365):

```cpp
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

HANDLE dirHandle = CreateFileW((wchar_t*)fullPath.Data,
    FILE_LIST_DIRECTORY,
    FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
    nullptr,
    OPEN_EXISTING,
    FILE_FLAG_BACKUP_SEMANTICS,
    0
);
constexpr DWORD BufferSize = 64 * 1024;
uint8_t buffer[BufferSize];
if (!GetFileInformationByHandleEx(dirHandle, FileIdExtdDirectoryRestartInfo, buffer, BufferSize))
{
    // We should always get at least "." and ".." entries for the directory.
    // If we go here, you've got a weird error to work through.
    ASSERT(false, "Failed to list initial files, error %d", GetLastError());
    return;
}
FILE_ID_EXTD_DIR_INFO* fileInfo = (FILE_ID_EXTD_DIR_INFO*)buffer;
while (true)
{
    // do something with your file here!

    if (fileInfo->NextEntryOffset != 0)
    {
        // Go to the next file.
        fileInfo = (FILE_ID_EXTD_DIR_INFO*)((uint8_t*)fileInfo +fileInfo->NextEntryOffset);
    }
    else
    {
        // Check whether there are more files to fetch.
        if (!GetFileInformationByHandleEx(dirHandle, FileIdExtdDirectoryInfo, buffer, BufferSize))
        {
            const DWORD error = GetLastError();
            if (error == ERROR_NO_MORE_FILES)
                break;
            ASSERT(false, "Failed to list files, error %d", GetLastError());
        }
        fileInfo = (FILE_ID_EXTD_DIR_INFO*)buffer;
    }
}
```

The clear upside of this over `NtQueryDirectoryFileEx` is ergonomics. That lower level API however still supports async I/O, which `GetFileInformationByHandleEx` does not. Behind the scenes `GetFileInformationByHandleEx` seems to do not much else than call `NtQueryDirectoryFileEx` immediately, and I have not observed a meaningful performance difference between the two methods. They both of course beat out `FindFileEx` if you have actually huge directories that benefit from larger buffers.

I'm cautiously optimistic that this is my last post on this topic, so I wanted to give a few notes about C# as well. It looks like C# uses `NtQueryDirectoryFile` directly ([DotNet Github](https://github.com/dotnet/runtime/blob/58e1a7e6e499da2cd502bebb326497795101783f/src/libraries/System.Private.CoreLib/src/System/IO/Enumeration/FileSystemEnumerator.Windows.cs#L86)) with a standard buffer size of 4K. You can use a larger buffer size by directly using `FileSystemEnumerator<...>` with a custom `EnumerationOption` argument ([MSDN](https://learn.microsoft.com/en-us/dotnet/api/system.io.enumerationoptions?view=net-8.0)) that allows you to set a custom buffer size. Their documentation suggests that they consider 16K a big buffer, which makes me think that `FindFileEx` probably uses that size when you use the `FIND_FIRST_EX_LARGE_FETCH` flag.
