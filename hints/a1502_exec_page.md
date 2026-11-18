Keep code and len in callee-saved registers (push rbx/r12/r13 at the start — and pop at the end on ALL exit paths).
mmap: rdi = 0, rsi = len, rdx = 3, r10 = 0x22, r8 = -1, r9 = 0, eax = 9. Error check: `cmp rax, -4096; ja`.
Copy: rdi = page, rsi = code, rcx = len, `rep movsb`. Then mprotect(page, len, 5) — number 10.
jit_free: munmap = 11, the arguments are already in place.
