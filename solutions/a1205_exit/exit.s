# =====================================================================
#  a1205 · Terminating the process: exit_group
# =====================================================================
#
#  A process terminates with a system call:
#      exit        (60)  — terminates only the current THREAD
#      exit_group  (231) — terminates all threads of the process; this is
#                          what _exit() in libc does
#  The argument (rdi) is the exit code 0..255. The call does not return.
#
#  An important subtlety: a "raw" exit_group does none of what a normal
#  return from main does: it doesn't flush stdio buffers, doesn't call
#  destructors/atexit, doesn't free memory (the last isn't needed anyway —
#  the kernel reclaims everything itself). That's why the driver flushes
#  stdout BEFORE calling finish. Forget that and unwritten output is lost.
#
#  After the exit_group syscall it's customary to put `ud2` or `hlt` — in
#  case the "non-returning" call does return after all (say, the number is
#  wrong): better to crash than to execute garbage.
#
#  TASK: finish(msg, len) — write the message to stdout (write) and
#  terminate the process with code 0 via exit_group.
#
    .intel_syntax noprefix
    .text
    .globl finish
finish:
    mov rdx, rsi
    mov rsi, rdi
    mov edi, 1
    mov eax, 1
    syscall
    xor edi, edi
    mov eax, 231
    syscall
    ud2

    .section .note.GNU-stack,"",@progbits
