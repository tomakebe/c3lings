# =====================================================================
#  a1201 · The write system call
# =====================================================================
#
#  Everything a program does with the outside world (files, the screen,
#  memory, threads) ultimately goes through the kernel — system calls. libc
#  and the C3 standard library are just wrappers. On x86-64 Linux a call is
#  made with the `syscall` instruction:
#
#      rax  — call number (write = 1, read = 0, exit_group = 231, ...)
#      rdi, rsi, rdx, r10, r8, r9 — arguments 1..6
#           (note: the 4th is r10, NOT rcx as in ordinary functions!)
#      result — in rax
#      syscall clobbers rcx (the return address is written there) and r11
#      (rflags). The kernel preserves all other registers.
#
#  ssize_t write(int fd, const void* buf, size_t count)
#      fd 1 is stdout. Returns the number of bytes written.
#
#  Call numbers are in /usr/include/asm/unistd_64.h or `ausyscall --dump`.
#
#  The arguments of our function sys_write(fd, buf, len) are already in rdi,
#  rsi, rdx — exactly where the kernel expects them. All that's left is the
#  number and the instruction itself.
#
#  TASK:
#      sys_write(fd, buf, len)  — a direct write call
#      write_cstr(s)            — write a zero-terminated string to stdout
#                                 (compute the length yourself), return
#                                 the result of write
#
    .intel_syntax noprefix
    .text

# long sys_write(CInt fd /*edi*/, char* buf /*rsi*/, long len /*rdx*/)
    .globl sys_write
sys_write:
    mov eax, 1
    syscall
    ret

# long write_cstr(char* s /*rdi*/)
    .globl write_cstr
write_cstr:
    xor edx, edx
1:
    cmp byte ptr [rdi + rdx], 0
    je 2f
    inc rdx
    jmp 1b
2:
    mov rsi, rdi
    mov edi, 1
    mov eax, 1
    syscall
    ret

    .section .note.GNU-stack,"",@progbits
