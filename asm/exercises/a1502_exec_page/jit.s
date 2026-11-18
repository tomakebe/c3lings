# =====================================================================
#  a1502 · Executable memory: mmap + copy + mprotect
# =====================================================================
#
#  To run generated code, it has to be placed in memory with EXECUTE
#  permission. Ordinary memory (stack, heap, data) does not have it —
#  jumping there causes SIGSEGV (the NX bit in the page table). The W^X scheme:
#
#    1. mmap(NULL, len, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)
#    2. copy the code bytes (rep movsb: rdi = destination, rsi = source, rcx = count)
#    3. mprotect(p, len, PROT_READ|PROT_EXEC)     (5 = 1|4)
#    4. call it as a function through a pointer
#
#  Recall chapter 12: mmap = 9 (the 4th argument goes in r10!), mprotect = 10,
#  munmap = 11; an error is rax in [-4095, -1].
#
#  On x86 there is no need to flush the instruction cache after writing code
#  (the processor itself watches for self-modifying code). On ARM you must
#  (__builtin___clear_cache). This is one more detail that JIT engines hide
#  inside a single function.
#
#  This function will be needed in the following exercises — it is already
#  provided there.
#
#  TASK:
#      jit_make(code, len) — return a pointer to an executable copy of the code
#                            or null (len == 0 or a kernel error)
#      jit_free(p, len)    — munmap, return the kernel's result
#
    .intel_syntax noprefix
    .text

# void* jit_make(char* code /*rdi*/, long len /*rsi*/)
    .globl jit_make
jit_make:
    # TODO
    xor eax, eax
    ret

# long jit_free(void* p, long len)
    .globl jit_free
jit_free:
    # TODO
    mov rax, -38
    ret

    .section .note.GNU-stack,"",@progbits
