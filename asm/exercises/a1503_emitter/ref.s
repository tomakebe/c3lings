# Эталон: те же инструкции, собранные GNU as. Этот файл НЕ нужно править.
    .intel_syntax noprefix
    .text
    .globl ref_code
ref_code:
c0: ret
c1: push rbx
c2: push r12
c3: pop rax
c4: pop r15
c5: movabs rax, 0x1122334455667788
c6: movabs r11, -1
c7: add rax, rcx
c8: add r10, rdx
c9: add rbx, r14
c10: sub rsi, rdi
c11: sub r9, r8
c12: imul rax, rcx
c13: imul r12, rbx
c14: imul rdx, r15
c15:
    .section .rodata
    .p2align 2
    .globl ref_offsets
ref_offsets:
    .long c0 - ref_code, c1 - ref_code, c2 - ref_code, c3 - ref_code, c4 - ref_code, c5 - ref_code, c6 - ref_code, c7 - ref_code, c8 - ref_code, c9 - ref_code, c10 - ref_code, c11 - ref_code, c12 - ref_code, c13 - ref_code, c14 - ref_code, c15 - ref_code

    .section .note.GNU-stack,"",@progbits
