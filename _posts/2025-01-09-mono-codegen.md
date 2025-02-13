---
layout: post
title: Mono codegen - Release vs. Debug 
tags: [unity]
---



I was convinced I had a post somewhere where I compare Mono's codegen for C# as used in Unity between Release and Debug. I was looking for it, so I could send it to a friend, but did not find it. Let's fill that gap.

As we have established [before]({% post_url 2024-11-12-unity-mono-perf %}) Mono is not exactly optimized for competitive codegen, because Mono's main job is compatibility. That last post linked there shows how Mono in particular struggles with value types, even when set to Release. Using a package that I created a long time ago (find [ASM Explorer here](https://github.com/sschoener/unity-asm-explorer-package)), you can look at the generated assembly quite easily.

When you make a build with Unity, you can either use Mono or IL2CPP, which will translate the IL into C++. However, the Unity editor is always running on Mono, and it is very common to run in Debug (for example because you want to debug your C# code in the editor). Unity will always put _all_ C# code into Debug, not just specific pieces of code.

For today, we are going to look at this function:

```csharp
public static class Adder
{
    public static int Add(int a, int b)
    {
        return a + b;
    }
}
```

Let us take a look at the generated code in Release mode:

```
000001846cde4070 48 83 ec 18                    sub rsp, 0x18
000001846cde4074 48 89 0c 24                    mov [rsp], rcx
000001846cde4078 48 89 54 24 08                 mov [rsp+0x8], rdx
000001846cde407d 48 8b c1                       mov rax, rcx
000001846cde4080 03 44 24 08                    add eax, [rsp+0x8]
000001846cde4084 48 83 c4 18                    add rsp, 0x18
000001846cde4088 c3                             ret
```

This is already not great. The arguments "spill" on the stack, which might be a consequence of compiling IL opcodes one-by-one (IL is entirely stack based). But the core of the function is at least visible: it is adding two numbers.

Here is the code when compiling this same code in Debug. Warning, explicit content ahead:
```
00000185f4a46b40 48 83 ec 28                    sub rsp, 0x28
00000185f4a46b44 4c 89 3c 24                    mov [rsp], r15
00000185f4a46b48 48 89 4c 24 18                 mov [rsp+0x18], rcx
00000185f4a46b4d 48 89 54 24 20                 mov [rsp+0x20], rdx
00000185f4a46b52 49 bb d8 54 18 6d fb 7f 00 00  mov r11, 0x7ffb6d1854d8
00000185f4a46b5c 4c 89 5c 24 10                 mov [rsp+0x10], r11          ; write breakpoint trampoline
00000185f4a46b61 49 bb 30 54 18 6d fb 7f 00 00  mov r11, 0x7ffb6d185430
00000185f4a46b6b 4c 89 5c 24 08                 mov [rsp+0x8], r11           ; write singlestep trampoline
00000185f4a46b70 45 33 ff                       xor r15d, r15d
00000185f4a46b73 41 bb 00 00 00 00              mov r11d, 0x0
00000185f4a46b79 4d 85 db                       test r11, r11
00000185f4a46b7c 74 08                          jz 0xf4a46b86                
00000185f4a46b7e 4c 8b 5c 24 08                 mov r11, [rsp+0x8]           ; read singlestep trampoline
00000185f4a46b83 41 ff 13                       call qword [r11]             ; check for singlestep
00000185f4a46b86 90                             nop
00000185f4a46b87 4c 8b 5c 24 10                 mov r11, [rsp+0x10]          ; read breakpoint trampoline
00000185f4a46b8c 4d 8b 1b                       mov r11, [r11]
00000185f4a46b8f 4d 85 db                       test r11, r11
00000185f4a46b92 74 03                          jz 0xf4a46b97                
00000185f4a46b94 41 ff d3                       call r11                     
00000185f4a46b97 41 bb 00 00 00 00              mov r11d, 0x0
00000185f4a46b9d 4d 85 db                       test r11, r11
00000185f4a46ba0 74 08                          jz 0xf4a46baa                
00000185f4a46ba2 4c 8b 5c 24 08                 mov r11, [rsp+0x8]           ; read singlestep trampoline
00000185f4a46ba7 41 ff 13                       call qword [r11]             ; check for singlestep
00000185f4a46baa 90                             nop
00000185f4a46bab 41 bb 00 00 00 00              mov r11d, 0x0
00000185f4a46bb1 4d 85 db                       test r11, r11
00000185f4a46bb4 74 08                          jz 0xf4a46bbe                
00000185f4a46bb6 4c 8b 5c 24 08                 mov r11, [rsp+0x8]           ; read singlestep trampoline
00000185f4a46bbb 41 ff 13                       call qword [r11]             ; check for singlestep
00000185f4a46bbe 90                             nop
00000185f4a46bbf 48 63 44 24 18                 movsxd rax, dword [rsp+0x18]
00000185f4a46bc4 48 63 4c 24 20                 movsxd rcx, dword [rsp+0x20]
00000185f4a46bc9 03 c1                          add eax, ecx
00000185f4a46bcb 4c 8b f8                       mov r15, rax
00000185f4a46bce 41 bb 00 00 00 00              mov r11d, 0x0
00000185f4a46bd4 4d 85 db                       test r11, r11
00000185f4a46bd7 74 08                          jz 0xf4a46be1                
00000185f4a46bd9 4c 8b 5c 24 08                 mov r11, [rsp+0x8]           ; read singlestep trampoline
00000185f4a46bde 41 ff 13                       call qword [r11]             ; check for singlestep
00000185f4a46be1 90                             nop
00000185f4a46be2 49 8b c7                       mov rax, r15
00000185f4a46be5 41 bb 00 00 00 00              mov r11d, 0x0
00000185f4a46beb 4d 85 db                       test r11, r11
00000185f4a46bee 74 08                          jz 0xf4a46bf8                
00000185f4a46bf0 4c 8b 5c 24 08                 mov r11, [rsp+0x8]           ; read singlestep trampoline
00000185f4a46bf5 41 ff 13                       call qword [r11]             ; check for singlestep
00000185f4a46bf8 90                             nop
00000185f4a46bf9 4c 8b 3c 24                    mov r15, [rsp]
00000185f4a46bfd 48 83 c4 28                    add rsp, 0x28
00000185f4a46c01 c3                             ret
```

Wow, what happened here? Can you still find the actual work this function is performing?

Here is what is happening, as far as I understand it: In contrast to a native debugger, you do not debug Mono by carefully placing `int 3` breakpoints. No, it requires a litte more cooperation. At every sequence point in the function (so basically between every IL opcode, and at function start and end), we check for whether there is a breakpoint there by checking R11 (`test r11, r11`) and then invoking special debug behavior through a function pointer. At the very start of the function, those two function pointers are set up. Then during execution the debugger would presumably patch the 4 zero bytes in the `mov r11d, 0x0` instruction preceeding the R11 check to indicate that it should break. There is an additional check for single-stepping. The labelling above and in `ASM Explorer` might be wrong: it is mixing up the singlestepping trampoline with the breakpoint trampoline. But in the big picture, this is irrelevant.

Most of this debug code above will never execute, but that does not mean it is free: it takes active effort to ignore the code, there are tons of new jumps that will mess with branch prediction, etc. Clearly, even if "number of instructions" is a very bad proxy for performance, it should be agreeable that this generated code above is not great. -- Regardless, you can measure this impact. Release builds are just much faster across the board.

For completeness, let's look at an optimized IL2CPP build as well. The code looks like this:

```cpp
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR int32_t Adder_Add_mCA6F2287A5D89D3050A3932750CB8CC867E0A172 (int32_t ___0_a, int32_t ___1_b, const RuntimeMethod* method) 
{
	{
		int32_t L_0 = ___0_a;
		int32_t L_1 = ___1_b;
		return ((int32_t)il2cpp_codegen_add(L_0, L_1));
	}
}
```

with
```cpp
template<typename T, typename U>
inline typename pick_bigger<T, U>::type il2cpp_codegen_add(T left, U right)
{
    return left + right;
}
```

and the compiled output is the very sensible
```
lea eax, [rcx, rdx]
retn
```

For completeness sake, let's also look at what modern dotnet on CoreCLR does to this and what MSVC is doing without optimizations. I am using [SharpLab](https://sharplab.io) to look at the results. In Release, you get this with CoreCLR:

```
Adder.Add(Int32, Int32)
    L0000: lea eax, [rcx+rdx]
    L0003: ret
```

Debug is already quite a bit more verbose. Note that we again seem to be checking for some global flag.
```
Adder.Add(Int32, Int32)
    L0000: push rbp
    L0001: sub rsp, 0x30
    L0005: lea rbp, [rsp+0x30]
    L000a: xor eax, eax
    L000c: mov [rbp-4], eax
    L000f: mov [rbp+0x10], ecx
    L0012: mov [rbp+0x18], edx
    L0015: mov rax, 0x7ffd2f90c258
    L001f: cmp dword ptr [rax], 0
    L0022: je short L0029
    L0024: call 0x00007ffd7f70a200
    L0029: nop
    L002a: mov eax, [rbp+0x10]
    L002d: add eax, [rbp+0x18]
    L0030: mov [rbp-4], eax
    L0033: nop
    L0034: mov eax, [rbp-4]
    L0037: add rsp, 0x30
    L003b: pop rbp
    L003c: ret
```

(Addendum: My friend Alexandre Mutel [points out](https://mastodon.social/@xoofx/113800539551817044) that in addition to the better codegen, CoreCLR is also capable of only compiling _your_ code in Debug, while all of the rest of the C# code in the application can enjoy full optimizations.)

Now, finally, MSVC with `/Od`:

```
int Add(int,int) PROC                                  ; Add
        mov     DWORD PTR [rsp+16], edx
        mov     DWORD PTR [rsp+8], ecx
        mov     eax, DWORD PTR b$[rsp]
        mov     ecx, DWORD PTR a$[rsp]
        add     ecx, eax
        mov     eax, ecx
        ret     0
```

In conclusion: *For this particular trivial example*, the optimized Release version produced by Mono is about the same as the un-optimized code generated by MSVC. The debug version of CoreCLR is still relying on checking some globals, but requires fewer such checks than Mono.

