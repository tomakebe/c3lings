# Chapter 12. Calling Linux system calls directly

Your program lives in a user-mode "sandbox": it cannot read the disk,
draw a pixel, get memory, or even exit on its own. All of that is done by
the operating system kernel at the program's request — through **system
calls**. `printf`, `malloc`, `fopen`, `io::printn`, `mem::new` — these are
all wrappers that eventually execute the `syscall` instruction.

In this chapter we strip away the wrappers and talk to the kernel directly.
We need this to understand what really sits behind the standard library,
how `strace` and sandboxes (seccomp) work, and to write a JIT in chapter 15
(`mmap` + `mprotect`).

Exercises: `a1201`–`a1205`.

## 1. How a system call works

The `syscall` instruction (x86-64):

1. saves the `rip` of the next instruction in `rcx`, and `rflags` in `r11`;
2. switches the processor into kernel mode (ring 0) and jumps to the
   address in the `LSTAR` MSR — the kernel entry point;
3. the kernel takes the call number from `rax` and the arguments from
   registers, does the work, puts the result in `rax` and returns with the
   `sysret` instruction.

The Linux x86-64 convention:

| | Register |
|---|---|
| call number | `rax` |
| arguments 1–6 | `rdi`, `rsi`, `rdx`, **`r10`**, `r8`, `r9` |
| result | `rax` |
| clobbered | `rcx`, `r11` (and, of course, `rax`) |
| preserved | everything else, including xmm |

The difference from an ordinary function call is that the fourth argument
goes in `r10` instead of `rcx`, since `rcx` is taken by the return address.
Arguments are never passed on the stack (6 at most).

Cost: the transition into the kernel and back alone is on the order of
50–100 ns on a modern processor (more with Spectre/Meltdown mitigations:
KPTI switches page tables). That is hundreds of times more expensive than
a function call — which is why standard libraries **buffer** output and
allocate memory in large chunks.

Some "calls" (`clock_gettime`, `gettimeofday`, `getcpu`) are implemented by
the kernel without entering the kernel — via the vDSO, a tiny library the
kernel maps into the address space of every process.

The old 32-bit mechanism is `int 0x80`, with numbers from a different table
and arguments in `ebx, ecx, edx, ...`. Don't use it in 64-bit code (it
truncates pointers to 32 bits).

## 2. The most useful calls

| Number | Name | Signature |
|---|---|---|
| 0 | `read` | `(fd, buf, count) → bytes` |
| 1 | `write` | `(fd, buf, count) → bytes` |
| 2 | `open` | `(path, flags, mode) → fd` (modern libcs use `openat` = 257) |
| 3 | `close` | `(fd) → 0` |
| 9 | `mmap` | `(addr, len, prot, flags, fd, off) → addr` |
| 10 | `mprotect` | `(addr, len, prot) → 0` |
| 11 | `munmap` | `(addr, len) → 0` |
| 12 | `brk` | `(addr) → new end of heap` |
| 39 | `getpid` | `() → pid` |
| 60 | `exit` | `(code)` — terminates the thread |
| 231 | `exit_group` | `(code)` — terminates the process |
| 228 | `clock_gettime` | `(clk, timespec*)` |
| 202 | `futex` | the basis of mutexes and condvars |
| 56/435 | `clone`/`clone3` | creating threads and processes |

The full table: `/usr/include/asm/unistd_64.h`, `man 2 syscalls`,
`man 2 syscall` (the section on conventions for all architectures). The
numbers differ between architectures (on aarch64 `write` = 64)!

## 3. Errors and errno

The kernel returns an error as a **negative number** `-errno` in the range
`[-4095, -1]`. Everything else is success. The check is a single unsigned
instruction:

```asm
    syscall
    cmp  rax, -4096
    ja   .error           ; rax ∈ [-4095, -1] (unsigned — the largest numbers)
```

Why not `test rax, rax; js`? Because some successful results look
negative: `mmap` on systems with a large address space, `lseek` with a huge
offset, `getpriority`.

The `errno` variable is purely a **library** convention. libc turns
`-EBADF` into `return -1` + `errno = 9`. And each thread has its own
`errno` (thread-local; in glibc via the `fs` segment). Common codes:

| errno | Code | Meaning |
|---|---|---|
| EPERM | 1 | permission denied |
| ENOENT | 2 | no such file |
| EINTR | 4 | interrupted by a signal — retry |
| EBADF | 9 | bad file descriptor |
| EAGAIN | 11 | try again later (non-blocking I/O) |
| ENOMEM | 12 | out of memory |
| EFAULT | 14 | bad pointer (the kernel can't read/write through it) |
| EINVAL | 22 | invalid argument |
| ENOSYS | 38 | no such call |

Note `EFAULT`: if you pass the kernel a garbage pointer, you won't get a
segfault — the kernel carefully checks the address and returns an error.
But if you dereference the same pointer yourself — SIGSEGV.

## 4. write and buffering

```asm
; long sys_write(int fd, char* buf, long len)
sys_write:
    mov eax, 1
    syscall
    ret
```

The function's arguments are already in `rdi`, `rsi`, `rdx` — exactly where
the kernel expects them. glibc's wrappers look almost the same (plus errno
handling and thread cancellation).

The trap is **buffering**. The standard library accumulates output in a
buffer and hands it to the kernel in large portions. If you mix `io::print`
and a direct `write`, the order of lines in the output may not match the
order of the calls. In C3, `io::printn`/`io::printfn` flush the stdout
buffer after each line, while `io::print`/`io::printf` do not. A reliable
rule: before a direct system call, do `(void)io::stdout().flush();`.

`write` may write **less** than requested (a short write to a pipe or
socket, interruption by a signal). A correct wrapper repeats the call in a
loop until it has written everything or gets a real error. For `EINTR` —
just retry.

## 5. Memory: mmap, mprotect, munmap

```asm
; void* page_alloc(long len)
page_alloc:
    mov  rsi, rdi          ; len
    xor  edi, edi          ; addr = NULL — let the kernel choose
    mov  edx, 3            ; PROT_READ | PROT_WRITE
    mov  r10d, 0x22        ; MAP_PRIVATE | MAP_ANONYMOUS
    mov  r8, -1            ; fd = -1
    xor  r9d, r9d          ; offset = 0
    mov  eax, 9
    syscall
    cmp  rax, -4096
    ja   1f
    ret
1:  xor  eax, eax          ; error → NULL
    ret
```

| Constant | Value |
|---|---|
| `PROT_NONE / READ / WRITE / EXEC` | 0 / 1 / 2 / 4 |
| `MAP_SHARED / PRIVATE` | 0x01 / 0x02 |
| `MAP_FIXED` | 0x10 |
| `MAP_ANONYMOUS` | 0x20 |
| `MAP_NORESERVE` | 0x4000 |
| `MAP_POPULATE` | 0x8000 |

What you need to know:

* Memory is handed out in **pages** (4096 bytes; there are also "huge"
  pages of 2 MiB/1 GiB). The address is page-aligned, and the length is
  rounded up.
* Anonymous memory is **guaranteed to be zeroed** — the kernel cannot hand
  you someone else's data.
* Memory is allocated **lazily**: `mmap` only reserves a range of addresses.
  The physical page appears on first access (a page fault, ~1 µs,
  including zeroing). So you can reserve 64 GiB of address space for an
  arena and pay only for what you touch — a favorite trick of engine
  allocators.
* `mprotect` changes the permissions of already-allocated pages; the
  address must be page-aligned (otherwise `EINVAL`).
* A page that is `PROT_WRITE|PROT_EXEC` at the same time is a security
  hole. The W^X rule: first write the code (RW), then switch to RX. That's
  how all JIT compilers work (chapter 15). On some systems (SELinux,
  OpenBSD, macOS with hardened runtime) W+X is forbidden altogether.
* glibc's `malloc` uses `brk` for small blocks and `mmap` for large ones
  (> 128 KiB by default).

## 6. Terminating the process

`exit_group(code)` (231) terminates all threads of the process; `exit` (60)
terminates only the current thread (that's how threads created with
`clone` exit). libc's `_exit()` function is `exit_group`. libc's `exit()`,
on the other hand, first calls the `atexit` handlers, flushes the stdio
buffers and only then calls `exit_group`. A direct system call does none of
that: if something is sitting in the stdout buffer, it is lost.

The exit code is the low 8 bits: `exit_group(256)` gives code 0.

## 7. A program with no libc at all

For completeness — a minimal program that needs neither libc nor the C3
runtime:

```asm
    .intel_syntax noprefix
    .section .rodata
msg:    .ascii "hello, kernel\n"
    .set msg_len, . - msg     # constant BEFORE use (see below)

    .text
    .globl _start
_start:                       # entry point: rsp points to argc
    mov  eax, 1               # write
    mov  edi, 1
    lea  rsi, [rip + msg]
    mov  edx, msg_len
    syscall
    mov  eax, 231             # exit_group(0)
    xor  edi, edi
    syscall
```

```
cc -nostdlib -static -o hello hello.s && ./hello
```

A subtlety of GNU as in Intel syntax: a symbol that is not yet defined at
the point of use is treated as a **memory address**, and `mov edx, msg_len`
turns into a load from memory at address 14 — segfault. That's why the
`.set` comes before the `mov`; or write `mov edx, OFFSET msg_len`
explicitly.

The binary will take a few kilobytes. On entry to `_start`, the stack holds
`argc`, `argv[]`, `NULL`, `envp[]`, `NULL`, then the auxv vector — that's
everything the kernel passes to the program.

## 8. Tools

* `strace ./prog` — shows every system call with its arguments and result.
  `strace -c` — statistics. Try it on any exercise in the course: you'll
  see `mmap`/`mprotect` at startup (the loader), `write` when printing,
  and `exit_group` at the end.
* `ltrace` — the same for library function calls.
* `/proc/self/maps` — the process memory map (what is mapped, and with
  which permissions).
* `man 2 <call>` — documentation for each call.

## 9. Pitfalls

* The fourth argument is `r10`, not `rcx`.
* `syscall` clobbers `rcx` and `r11` — don't keep live values there.
* An error is `[-4095, -1]`; the check is unsigned (`ja`).
* Output order when mixing buffered output with direct `write`.
* Short writes and `EINTR`.
* `exit_group` doesn't flush buffers.
* Call numbers depend on the architecture.

## Self-check questions

1. Which registers carry the number and the arguments of a system call?
   How does this differ from a function call, and why?
2. Which registers does `syscall` clobber?
3. How do you tell an error from a successful result? Why can't you just
   check the sign?
4. Where is `errno` stored, and who sets it — the kernel or the library?
5. Why can output from `io::print` and from a direct `write` get mixed up?
6. How does `exit` differ from `exit_group`? And libc's `exit()` from
   `_exit()`?
7. Why does an `mmap` of 1 GiB complete instantly? When is physical memory
   actually allocated?
8. What is W^X, and why doesn't a JIT keep code in RWX pages?

## Further reading

* `man 2 syscall`, `man 2 mmap`, `man 2 mprotect`, `man 7 vdso`.
* Linux kernel: `arch/x86/entry/entry_64.S` and
  `arch/x86/entry/syscalls/syscall_64.tbl` — the entry point and the call
  table.
* Michael Kerrisk, *The Linux Programming Interface* — chapters 3 (system
  calls) and 49 (mmap).
* Intel SDM Vol. 2 — `SYSCALL`/`SYSRET`; Vol. 3 — modes and MSRs.
* "A Whirlwind Tutorial on Creating Really Teensy ELF Executables for
  Linux" (Brian Raiter) — how to make a 45-byte binary.
* Ulrich Drepper, "What Every Programmer Should Know About Memory",
  section 4 (virtual memory).
