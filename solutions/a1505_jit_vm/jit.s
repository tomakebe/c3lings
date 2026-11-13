# Готовые функции для исполняемой памяти (их вы написали в a1502).
# Этот файл НЕ нужно править.
    .intel_syntax noprefix
    .text

# void* jit_make(char* code, long len) — mmap RW, копия, mprotect RX
    .globl jit_make
jit_make:
    test rsi, rsi
    jz 8f
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi
    xor edi, edi
    mov rsi, r13
    mov edx, 3
    mov r10d, 0x22
    mov r8, -1
    xor r9d, r9d
    mov eax, 9
    syscall
    cmp rax, -4096
    ja 9f
    mov rbx, rax
    mov rdi, rbx
    mov rsi, r12
    mov rcx, r13
    rep movsb
    mov rdi, rbx
    mov rsi, r13
    mov edx, 5
    mov eax, 10
    syscall
    test rax, rax
    jnz 9f
    mov rax, rbx
    pop r13
    pop r12
    pop rbx
    ret
9:
    pop r13
    pop r12
    pop rbx
8:
    xor eax, eax
    ret

# long jit_free(void* p, long len)
    .globl jit_free
jit_free:
    mov eax, 11
    syscall
    ret

    .section .note.GNU-stack,"",@progbits
