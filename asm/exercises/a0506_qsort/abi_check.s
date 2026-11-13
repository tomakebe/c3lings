# =====================================================================
#  Проверочный стенд (harness). НЕ РЕДАКТИРУЙТЕ этот файл.
# =====================================================================
#
#  abi_call(fn, a, b, c, d)  — вызывает fn(a, b, c, d), предварительно
#      положив «канарейки» в callee-saved регистры rbx, rbp, r12–r15.
#      После возврата проверяет, что они не изменились и что rsp
#      вернулся на место. Нарушения копятся в abi_errors().
#
#  harness_trash()  — вызывается из C3-колбэков: проверяет, что стек
#      был выровнен по 16 байт перед `call`, и портит все
#      caller-saved регистры (как это вправе сделать любая функция).
#
#  abi_errors()  — битовая маска: 1 = испорчен callee-saved регистр,
#      2 = не восстановлен rsp, 4 = невыровненный стек при вызове.
#
    .intel_syntax noprefix

    .bss
    .p2align 3
errors:    .zero 8
saved_rsp: .zero 8

    .text
    .globl abi_errors
abi_errors:
    mov rax, [rip + errors]
    ret

    .globl abi_call
abi_call:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rax, rdi
    mov rdi, rsi
    mov rsi, rdx
    mov rdx, rcx
    mov rcx, r8
    movabs rbx, 0x1111111111111111
    movabs rbp, 0x2222222222222222
    movabs r12, 0x3333333333333333
    movabs r13, 0x4444444444444444
    movabs r14, 0x5555555555555555
    movabs r15, 0x6666666666666666
    mov [rip + saved_rsp], rsp
    call rax
    cmp rsp, [rip + saved_rsp]
    je 1f
    or qword ptr [rip + errors], 2
    mov rsp, [rip + saved_rsp]
1:
    movabs rcx, 0x1111111111111111
    cmp rbx, rcx
    jne 2f
    movabs rcx, 0x2222222222222222
    cmp rbp, rcx
    jne 2f
    movabs rcx, 0x3333333333333333
    cmp r12, rcx
    jne 2f
    movabs rcx, 0x4444444444444444
    cmp r13, rcx
    jne 2f
    movabs rcx, 0x5555555555555555
    cmp r14, rcx
    jne 2f
    movabs rcx, 0x6666666666666666
    cmp r15, rcx
    je 3f
2:
    or qword ptr [rip + errors], 1
3:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

    .globl harness_trash
harness_trash:
    mov rax, rsp
    and eax, 15
    cmp eax, 8
    je 1f
    or qword ptr [rip + errors], 4
1:
    movabs rax, 0xBADBADBADBADBAD0
    mov rcx, rax
    mov rdx, rax
    mov rsi, rax
    mov rdi, rax
    mov r8, rax
    mov r9, rax
    mov r10, rax
    mov r11, rax
    ret

    .section .note.GNU-stack,"",@progbits
