# =====================================================================
#  a1202 · System call errors and errno
# =====================================================================
#
#  The Linux kernel reports an error by returning a NEGATIVE code in rax:
#  -EBADF (-9), -EFAULT (-14), -EINVAL (-22), -ENOMEM (-12)...
#  A value in the range [-4095, -1] is an error; everything else is a
#  normal result (for example, mmap may return a "large" address that is
#  negative as a signed number, but it is > -4096).
#
#  libc turns this into the familiar POSIX convention:
#      if ((unsigned long)rax > -4096UL) { errno = -rax; return -1; }
#  In libc, errno is a variable in TLS (each thread has its own). We use a
#  plain global variable last_errno, declared below in .bss.
#
#  The "unsigned greater than -4096" comparison is a single instruction:
#      cmp rax, -4096
#      ja  error          # ja is an unsigned comparison!
#
#  Note: the kernel NEVER touches errno itself — it is purely a library
#  convention. And on success errno does not change.
#
#  TASK:
#      checked_write(fd, buf, len) — write; on error set last_errno = -rax,
#                                    return -1
#      checked_close(fd)           — close (number 3), the same way
#
    .intel_syntax noprefix
    .bss
    .p2align 2
    .globl last_errno
last_errno:
    .zero 4

    .text

# long checked_write(CInt fd, char* buf, long len)
    .globl checked_write
checked_write:
    mov eax, 1
    syscall
    # TODO: check for an error and store errno
    ret

# long checked_close(CInt fd)
    .globl checked_close
checked_close:
    # TODO
    xor eax, eax
    ret

    .section .note.GNU-stack,"",@progbits
