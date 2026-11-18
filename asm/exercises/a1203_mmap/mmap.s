# =====================================================================
#  a1203 · Memory straight from the kernel: mmap, mprotect, munmap
# =====================================================================
#
#  All allocators (malloc, C3's allocators, engine arenas) ultimately get
#  memory from the kernel in pages (4 KiB) via mmap:
#
#      void* mmap(void* addr, size_t len, int prot, int flags, int fd, off_t off)
#      number 9; arguments: rdi, rsi, rdx, r10 (!), r8, r9
#
#  For anonymous (not file-backed) memory:
#      addr = 0 (let the kernel choose), prot = PROT_READ|PROT_WRITE = 1|2 = 3,
#      flags = MAP_PRIVATE|MAP_ANONYMOUS = 0x02|0x20 = 0x22, fd = -1, off = 0
#
#  The FOURTH system call argument goes in r10, not rcx: rcx gets clobbered
#  by the syscall instruction itself (rip is saved there). A classic
#  mistake is putting flags in rcx.
#
#  An error is a value in [-4095, -1] (see a1202). It's more convenient for
#  the caller if we return null (as, for example, VirtualAlloc on Windows
#  does; libc's mmap returns MAP_FAILED = (void*)-1).
#
#      int mprotect(void* addr, size_t len, int prot)   number 10
#      int munmap(void* addr, size_t len)               number 11
#  Here we return the kernel's "raw" result (0 or -errno).
#
#  mprotect will be needed in the final chapter: a JIT writes machine code
#  into a page with PROT_READ|PROT_WRITE, then switches it to
#  PROT_READ|PROT_EXEC (W^X — never write and execute at the same time).
#
#  TASK: write three functions.
#      page_alloc(len)            -> pointer, or null on error
#      page_protect(p, len, prot) -> 0 or -errno
#      page_free(p, len)          -> 0 or -errno
#
    .intel_syntax noprefix
    .text

# void* page_alloc(long len /*rdi*/)
    .globl page_alloc
page_alloc:
    # TODO
    xor eax, eax
    ret

# long page_protect(void* p, long len, CInt prot)
    .globl page_protect
page_protect:
    # TODO
    mov rax, -38
    ret

# long page_free(void* p, long len)
    .globl page_free
page_free:
    # TODO
    mov rax, -38
    ret

    .section .note.GNU-stack,"",@progbits
