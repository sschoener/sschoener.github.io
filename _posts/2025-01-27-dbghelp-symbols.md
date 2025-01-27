---
layout: post
title: How to use DbgHelp to download symbol files
tags: []
---

_Hey! You can find me on [Mastodon](https://mastodon.gamedev.place/@sschoener) and [Bluesky](https://bsky.app/profile/sschoener.bsky.social)!_

I could not find a guide online for how to use DbgHelp to download symbols for a binary on disk on Windows. It seemed like a relatively obvious question, hence I decided to record the answer in the hopes that more people use this to write debugger-shaped software. We should first understand what steps DbgHelp is actually doing.

A binary file (exe, dll) that was built with debug information will contain some data as to which file contains the debug data. In modern days, the debug information is usually in an external PDB file (we'll ignore everything else for now). The PE file format has an optional [debug directory (MSDN)](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#debug-directory-image-only), which contains a time stamp, a version and type of the debug info (usually set to `CODEVIEW`, meaning PDB -- see the [types on MSDN](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#debug-type)), and a pointer to more data that is specific to the type of debug info. For modern PDBs, this pointer points to a place that will hold a short header of 4 bytes: "RSDS" for PDB7.0 or "NB10" for PDB2.0 files. For PDB7.0, this is followed by a GUID (16 bytes), an "age" value (4 bytes), and a zero-terminated path to a PDB file. The path looks like ASCII. For PDB2.0 the format is slightly different. The page DebugInfo.com has all the details  on their excellent [Matching Debug Information page](https://www.debuginfo.com/articles/debuginfomatch.html#debuginfosepfile).

The GUID and age are the actual identifiers for a PDB, besides the file name. The first obvious thing to then do is to check the path that we just found in the binary and see whether it is a match: Open the PDB and check whether the GUID and age match. (For PDB2.0, a 4 byte identifier is used instead of a GUID.)

If that is no match, then we need to find the PDB file elsewhere. This is where the "symbol search path" comes into play. This can either be set manually or constructed from some environment variables (see the documentation for [SymInitializeW on MSDN](https://learn.microsoft.com/en-us/windows/win32/api/dbghelp/nf-dbghelp-syminitializew) for details about these variables). The symbol search path can be confusing because it does *not* just specify where to search. You can just specify different paths and separate them with `;`, but there are also some special identifiers. For example, instead of a path you could add `SRV*https://msdl.microsoft.com/download/symbols` to specify that you want to also search a symbol server with a given URL. You can also add `cache*C:\SymbolCache` to specify where symbols should generally be cached. The precise syntax for the symbol search path can be found on [Symbol path for Windows debuggers on MSDN](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/symbol-path).

So then we need to do this: Check the symbol cache, then check all the symbol search paths, and then also query all the symbol servers. Checking the search paths is simple, because we just need to find a PDB of the right name and the right signature and then match it. Querying the cache is also simple: If we are looking for say `kernel32.pdb`, then we look in the cache for a `kernel32.pdb` directory. If we find it, check if there is a subdirectory with the name `<GUID><AGE>` for our particular version and then use the PDB file in there. (For PDB2.0, it's `<SIGNATURE><AGE>`). For example, my `kernel32.dll` has age 1 and uses the GUID `1B72224D-37B8-1792-2820-0ED8994498B2`. This means we check the directory `1B72224D37B8179228200ED8994498B21`. So we'd expect to find a file `C:\SymbolCache\kernel32.pdb\1B72224D37B8179228200ED8994498B21\kernel32.pdb`.

That leaves us with querying the symbol servers. The protocol is very simple. You can observe the HTTP requests that go out to the symbol server when you use DbgHelp. With a small caveat, we query the symbol server in the same way that we query the cache: e.g. we send an HTTP GET request to
```
https://msdl.microsoft.com/download/symbols/kernel32.pdb/1B72224D37B8179228200ED8994498B21/kernel32.pdb
```
and download that file and store it in our cache as `kernel32.pdb` in that same folder. The caveat here is that we also first query for a file `index2.txt` (HTTP GET to `https://msdl.microsoft.com/download/symbols/index2.txt`). Its contents are completely irrelevant, but if it exists, we query for a slightly different path: we take the first two letters of the binary an insert it into the path in the beginning. Concretely, we would check `ke/kernel32.pdb/1B72224D37B8179228200ED8994498B21/kernel32.pdb`, for example. This behavior is described in [Symbol Store Folder Tree on MSDN](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/symbol-store-folder-tree).

That's all there is to it, for all I can tell. All of these steps can be handled by `dbghelp.dll` and `symsrv.dll`, which need to be accessible by your program. You can read about downloading a specific version of them on the [Debug Help Library page on MSDN](https://learn.microsoft.com/en-us/windows/win32/debug/debug-help-library). But from all of the above it is also pretty clear that you could very reasonably _not_ use `dbghelp` at all! You need to open and understand PE files (that's well documented), be able to download via HTTP, and open and read PDB files (use [RawPDB](https://github.com/MolecularMatters/raw_pdb), or another sane library of your choice).

You may want to roll your own solution here because `dbghelp.dll` is not threadsafe and does so much more than just download symbol files. A future post might detail the solution that I have made for this; it is not a lot of code but it is annoying to write.

Here is code for a small program that takes a binary file and a symbol cache as inputs and then uses DbgHelp to download the symbols. Note that this program does _not_ look for local files, even though we get a file path. That part should be easy! You need to link against `dbghelp.lib`.

Some notes:
 * I added a debug callback. It will print out useful information from DbgHelp (and even download progress). Note that we return `FALSE` by default. That is important, because if we return `TRUE` for a `CBA_DEFERRED_SYMBOL_LOAD_CANCEL` message, we immediately cancel the download we just started. Don't ask me how long it took me to figure that out.
 * The callback is actually called with some progress information that you can use to update your own progress bar somewhere.
 * This code may miss some cleanup in error conditions. The program shuts down immediately in this case, but in a bigger application you should add that.

```cpp
#define WIN32_LEAN_AND_MEAN
#include "Windows.h"

#define DBGHELP_TRANSLATE_TCHAR

#include "DbgHelp.h"
#include "inttypes.h"
#include "stdio.h"

// For the different action codes, check
// https://learn.microsoft.com/en-us/windows/win32/api/dbghelp/nc-dbghelp-psymbol_registered_callback
BOOL CALLBACK DebugCallback(HANDLE process, ULONG actionCode, ULONG64 callbackData, ULONG64 userContext) {
    if (actionCode == CBA_DEBUG_INFO) {
        printf("[DbgHelp] %ws", (const wchar_t*)callbackData);
        return TRUE;
    }
    else if (actionCode == CBA_EVENT) {
        PIMAGEHLP_CBA_EVENT evt = (PIMAGEHLP_CBA_EVENT)callbackData;
        printf("[DbgHelp] %ws", evt->desc);
        return TRUE;
    }
    return FALSE;
}

// This program attempts to download the PDB file for the given binary file.
// The file will be stored in the symbol cache.
int wmain(int argc, wchar_t** args)
{
    if (argc < 3)
    {
        printf("Invalid usage: not enough parameters\n");
        printf("Usage: \n");
        printf("symfetch <path-to-binary> <symbol-cache>");
        return 1;
    }
    const wchar_t* inputPath = args[1];
    const wchar_t* symbolCache = args[2];

    // If we don't set a search path, DebugHelp will use a default path constructed from environment variables.
    wchar_t symbolSearchPath[1024];
    swprintf_s(symbolSearchPath, L"cache*%s;SRV*https://msdl.microsoft.com/download/symbols", symbolCache);

    HANDLE process = GetCurrentProcess();
    // Initialize the symbol handler
    if (!SymInitializeW(process, symbolSearchPath, FALSE)) {
        printf("Failed to initialize symbol handler. Error: %d\n", GetLastError());
        return 1;
    }

    SymSetOptions(SYMOPT_EXACT_SYMBOLS | SYMOPT_DEBUG);
    SymRegisterCallback64(process, DebugCallback, 0);

    // This loads the binary to retrieve the GUID/Signature/Age/PDB Path.
    // We should first look at the PDB path returned here, but we skip this for this example.
    SYMSRV_INDEX_INFOW info{};
    info.sizeofstruct = sizeof(SYMSRV_INDEX_INFOW);
    bool result = SymSrvGetFileIndexInfoW(inputPath, &info, 0);
    if (!result)
    {
        printf("Failed to find binary info. Error: %d\n", GetLastError());
        return 1;
    }

    // Buffer to store the located PDB file path
    wchar_t pdbPath[1024] = { };

    // Use SymFindFileInPath to locate and download the PDB file. First check what data we need to put in.
    void* id;
    DWORD idType;
    GUID zero{};
    if (memcmp(&info.guid, &zero, sizeof(zero)) == 0) {
        id = &info.sig;
        idType = SSRVOPT_DWORDPTR;
    }
    else {
        id = &info.guid;
        idType = SSRVOPT_GUIDPTR;
    }

    bool found = SymFindFileInPathW(
        process,
        NULL,
        info.pdbfile,
        id,
        info.age,
        0,
        idType,
        pdbPath,
        NULL,
        NULL
    );

    SymCleanup(process);

    if (found) {
        printf("PDB file located: %ws\n", pdbPath);
        return 0;
    }
    else {
        printf("Failed to locate PDB file. Error: %d\n", GetLastError());
        return 1;
    }
}
```

{% include clickable-image.html %}