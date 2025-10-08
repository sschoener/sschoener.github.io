---
layout: post
title: Hard links, hard times
excerpt:
tags: []
---

On Windows, you can't delete a file while someone else is ~~watching you~~ using it. Or so they say. On Mac or Linux, you can totally delete a file while someone else is using it. This difference has been keeping me busy for a few days. In my concrete scenario, we need to assemble files from data in a cache on disk and be able to swap out those files while someone else is using them.

I have found two ways around this limitation: First, you can use hardlinks. Windows on NTFS supports hardlinks: a file system entry for a file can have multiple paths to it. Windows prevents you from deleting the file system entry, not the hardlinks. Given that the entry stays alive until all hardlinks are gone, we just need to ensure that the hardlink we want to delete is not the last one. In the caching scenario above, this is simple: we just hardlink to the cache entry.

The second approach is to not use `DeleteFile` but to manually implement file deletion. Then you get more options, among them "POSIX file deletion." Here are the steps for this:
 * Open a handle with `CreateFileW(path, DELETE, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, 0, NULL)`.
 * Use `SetFileInformationByHandle` with `FILE_DISPOSITION_INFO_EX` ([MSDN](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntddk/ns-ntddk-_file_disposition_information_ex)). The `FileInformationClass` value for that struct type is `23`. (This is not secret, see [here](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/wdm/nf-wdm-zwsetinformationfile).) On the struct, we need to set flags `FILE_DISPOSITION_DELETE` and `FILE_DISPOSITION_POSIX_SEMANTICS`.
 * Close the handle.

For the cache I'm concerned about, hardlinking seemed like a good solution: We often have many instances of the same file, and just having one version that we hardlink to makes sense. (Files on Windows can only have 1023 hardlinks, so we may have to deal with multiple copies at some point.) It also saves us from the time cost of copying the file around. The downside is that someone can now corrupt their cache (it is content-hashed) by writing to the file in the cache, because they have a hardlink to it.

The cache corruption is actually easy to avoid on the surface: just mark the file read-only! And then, voilà, _nothing is deletable anymore_. Uh, great? So it turns out that Windows does not allow you to delete read-only files, and by "read-only file" it really means "the file system entry AND any hardlink to it." Here is the unfortunate reality: The thing you set read-only is the file system entry and not the hardlink itself, but Windows won't let you delete hardlinks to that read-only entry. In order to delete *any* hardlink to a readonly entry, you have to first make the entry writable. That's even true if after the deletion there are still more hardlinks to that entry. (MSDN has some more details [here](https://learn.microsoft.com/en-us/windows/win32/fileio/hard-links-and-junctions#hard-links).)

This leaves the option of temporarily removing the readonly attribute on the file, and then reapplying the readonly attribute post deletion. The tricky part is that you now need to know what to make readonly again: you just deleted the hardlink to it, how do you find another one? Luckily, there is a slightly simpler way than finding another hardlink that links to the same entry: All of this has been about keeping a handle to a file and then delete it, so let's just keep the handle to the file and reapply the readonly attribute that way! Neat.

In more details:
 * First, open a handle to the file with access set to `FILE_READ_ATTRIBUTES | FILE_WRITE_ATTRIBUTES`.
 * Then query its attributes using `GetFileInformationByHandle` and clear the readonly attribute using `SetFileInformationByHandle`.
 * Keep that handle open!
 * Then open *another* handle to the file and delete it, using the method outlined above. Close that handle.
   * Both the opening and the deletion can spuriously fail with `ERROR_ACCESS_DENIED`. The problem is that resetting the readonly attribute on a file handle may not immmediately propagate to other handles or the disk itself. This means that your new handle still thinks that the file is readonly! In that case, set the file attributes again using `SetFileAttributesW(path, attributes)` and retry the deletion.
 * Now return to the first handle and reapply the readonly attribute. Done!

I have tried to use `DuplicateHandle` to avoid opening two handles separately, but it's seemingly impossible to upgrade to `DELETE` access. You might also wonder "why not use `SetFileAttributesW` immediately?" Well, we have to open a handle in any case, and that's presumably cheaper than always going through the full `SetFileAttributesW` (which evidently does more work, because that seems to ensure that attributes are reflected on all ways to open the file at that path, instead of just applying to a handle which eventually propagates it to the path).

It's worth noting that if you just want to delete a readonly hardlink, there is a simpler solution: Make the file writable, open a handle with `FILE_FLAG_DELETE_ON_CLOSE`, then make the file readonly again and close your handle. I have not been able to get this to work while also using POSIX deletions.

Finally, here is some C# code that implements this:
```csharp
public static class WindowsFileSystemHelpers
{
    [Flags]
    enum FileDispositionFlags : uint {
        DELETE = 0x00000001,
        POSIX_SEMANTICS = 0x00000002,
    }

    [StructLayout(LayoutKind.Sequential)]
    struct FILE_DISPOSITION_INFO_EX {
        public FileDispositionFlags Flags;
    }

    enum FILE_INFO_BY_HANDLE_CLASS : int {
        FileBasicInfo = 0,
        FileDispositionInfoEx = 21
    }
    
    [StructLayout(LayoutKind.Sequential)]
    struct FILE_BASIC_INFO
    {
        public long CreationTime;
        public long LastAccessTime;
        public long LastWriteTime;
        public long ChangeTime;
        public uint FileAttributes;
    }

    [DllImport("kernel32.dll", EntryPoint = "SetFileInformationByHandle", SetLastError = true)]
    static extern bool SetFileInformationByHandle_FileDispositionInfoEx(
        IntPtr hFile,
        FILE_INFO_BY_HANDLE_CLASS fileInfoClass,
        ref FILE_DISPOSITION_INFO_EX fileInfo,
        uint dwBufferSize
    );
    
    [DllImport("kernel32.dll", EntryPoint = "SetFileInformationByHandle", SetLastError = true)]
    static extern bool SetFileInformationByHandle_FileBasicInfo(
        IntPtr hFile,
        FILE_INFO_BY_HANDLE_CLASS fileInfoClass,
        ref FILE_BASIC_INFO fileInfo,
        uint dwBufferSize
    );
    
    [DllImport("kernel32.dll", EntryPoint = "GetFileInformationByHandleEx", SetLastError = true)]
    static extern bool GetFileInformationByHandleEx_FileBasicInfo(
        IntPtr hFile,
        FILE_INFO_BY_HANDLE_CLASS fileInfoClass,
        out FILE_BASIC_INFO lpFileInformation,
        uint dwBufferSize
    );

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr CreateFileW(
        string lpFileName,
        uint dwDesiredAccess,
        uint dwShareMode,
        IntPtr lpSecurityAttributes,
        uint dwCreationDisposition,
        uint dwFlagsAndAttributes,
        IntPtr hTemplateFile
    );

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool SetFileAttributesW(
        string lpFileName,
        uint dwFileAttributes
    );

    [DllImport("kernel32.dll")]
    static extern bool CloseHandle(IntPtr hObject);

    const uint DELETE = 0x00010000;
    const uint FILE_READ_ATTRIBUTES = 0x80;
    const uint FILE_WRITE_ATTRIBUTES = 0x100;
    const uint OPEN_EXISTING = 3;
    const uint FILE_SHARE_READ = 1;
    const uint FILE_SHARE_WRITE = 2;
    const uint FILE_SHARE_DELETE = 4;
    const uint FILE_ATTRIBUTE_READONLY = 0x00000001;
    
    const int ERROR_FILE_NOT_FOUND = 2;
    const int ERROR_PATH_NOT_FOUND = 3;
    const int ERROR_ACCESS_DENIED = 5;

    struct DeletionInner
    {
        public int ErrorCode;
        public int FailurePoint;
    }
    
    static DeletionInner DeleteInner(string longPath, bool allowRetry, uint attributes)
    {
        var handle = CreateFileW(longPath, DELETE, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero);
        if (handle == IntPtr.Zero || handle.ToInt64() == -1)
        {
            int error = Marshal.GetLastWin32Error();
            if (error == ERROR_ACCESS_DENIED && allowRetry)
            {
                SetFileAttributesW(longPath, attributes);
                return DeleteInner(longPath, allowRetry: false, attributes: 0);
            }
            return new DeletionInner
            {
                ErrorCode = Marshal.GetLastWin32Error(),
                FailurePoint = 0,
            };
        }
        var info = new FILE_DISPOSITION_INFO_EX {
            Flags = FileDispositionFlags.DELETE | FileDispositionFlags.POSIX_SEMANTICS
        };
        
        bool deletionWorked = SetFileInformationByHandle_FileDispositionInfoEx(handle, FILE_INFO_BY_HANDLE_CLASS.FileDispositionInfoEx, ref info, (uint)Marshal.SizeOf<FILE_DISPOSITION_INFO_EX>());
        if (!deletionWorked)
        {
            int error = Marshal.GetLastWin32Error();
            CloseHandle(handle);
            if (error == ERROR_ACCESS_DENIED && allowRetry)
            {
                SetFileAttributesW(longPath, attributes);
                return DeleteInner(longPath, allowRetry: false, attributes: 0);
            }

            return new DeletionInner
            {
                ErrorCode = error,
                FailurePoint = 1
            };
        }
        CloseHandle(handle);
        
        return default;
    }
    
    // Allows to delete a readonly file while that file is still opened by someone else.
    // Returns true if the file was actually deleted, false if it wasn't present.
    // This seemingly simple problem is made more complicated by a number of issues:
    //  * Windows doesn't allow you to delete readonly files.
    //  * Windows doesn't easily allow you to delete files that are opened by someone else.
    // This gets further complicated by our usage of hard links: you can remove hardlinks, but not to readonly files.
    // A hardlink itself is however NOT readonly. Only the thing it links to is. So you can't just make the hardlink
    // itself no longer readonly. No, that affects the thing that it links to, and hence *all* its hardlinks. And it's
    // not easy to reset the read-only state, because then we'd need to know how we can now find that file we linked to
    // post-deletion and make it readonly again.
    //
    // Luckily, all of these problems have a solution:
    //  * We open an attribute-only permissions handle to the file and use that handle to then remove the READONLY
    //    attribute. We keep the handle open.
    //  * Then we open a new handle with DELETE permission and use a low-level Windows API to request a POSIX-style
    //    deletion, which means we can delete it while it is still open elsewhere.
    //  * Then we use the previously opened handle to the now deleted file to reset the READONLY attribute.
    // The deletion can still fail, but that is rare. The reason why it fails is that we use the handle-based APIs for
    // setting file attributes, and new handles might not immediately see the new attributes. We can therefore go down
    // the slightly slower route of calling SetFileAttributesW(path), which ensures that any open on that path will see
    // the new attributes. You might think that we could instead duplicate the first handle with DELETE permissions, but
    // Windows doesn't allow that in practice.
    public static bool PosixDeleteReadOnlyFile(string inputPath)
    {
        string longPath = @"\\?\" + Path.GetFullPath(inputPath);

        var handle = CreateFileW(longPath, FILE_READ_ATTRIBUTES | FILE_WRITE_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero);
        if (handle == IntPtr.Zero || handle.ToInt64() == -1)
        {
            int error = Marshal.GetLastWin32Error();
            if (error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND)
                return false;
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), $"Failed to delete file {inputPath}: Failed to open file handle for setting attributes");
        }

        try
        {
            if (!GetFileInformationByHandleEx_FileBasicInfo(handle, FILE_INFO_BY_HANDLE_CLASS.FileBasicInfo, out var basicInfo, (uint)Marshal.SizeOf<FILE_BASIC_INFO>()))
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), $"Failed to delete file {inputPath}: Failed to get file information");

            uint originalAttributes = basicInfo.FileAttributes;
            basicInfo.FileAttributes = originalAttributes & ~FILE_ATTRIBUTE_READONLY;

            if (!SetFileInformationByHandle_FileBasicInfo(handle, FILE_INFO_BY_HANDLE_CLASS.FileBasicInfo, ref basicInfo, (uint)Marshal.SizeOf<FILE_BASIC_INFO>()))
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), $"Failed to delete file {inputPath}: Failed to clear file attributes");

            var result = DeleteInner(longPath, true, basicInfo.FileAttributes);
            
            basicInfo.FileAttributes = originalAttributes;
            if (!SetFileInformationByHandle_FileBasicInfo(handle, FILE_INFO_BY_HANDLE_CLASS.FileBasicInfo, ref basicInfo, (uint)Marshal.SizeOf<FILE_BASIC_INFO>()))
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), $"Failed to delete file {inputPath}: Failed to re-set file attributes");

            if (result.ErrorCode != 0)
            {
                if (result.FailurePoint == 0)
                    throw new System.ComponentModel.Win32Exception(result.ErrorCode, $"Failed to delete file {inputPath}: Failed to open file for deletion");
                else
                    throw new System.ComponentModel.Win32Exception(result.ErrorCode, $"Failed to delete file {inputPath}: Failed to set file deletion");
            }
        }
        finally
        {
            CloseHandle(handle);
        }

        return true;
    }
}
```