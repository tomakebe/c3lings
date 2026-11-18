# =====================================================================
#  a0102 · Arguments arrive in registers
# =====================================================================
#
#  In the System V ABI the first six integer (and pointer) arguments
#  are passed in registers, strictly in this order:
#
#      1st  rdi        4th  rcx
#      2nd  rsi        5th  r8
#      3rd  rdx        6th  r9
#
#  Mnemonic: "Diane's Silk Dress Costs $8 9" (rDi, rSi, rDx, rCx, r8, r9).
#  The seventh and later arguments go on the stack — that's chapter 05.
#
#  All arguments here are `long` (64 bits), so we work with the full
#  64-bit registers: rdi, not edi; r9, not r9d. The result goes in rax.
#
#      mov rax, rdi      # copy the 1st argument into the result register
#
#  Note: `mov` copies, it doesn't move — the value stays in rdi.
#  And `mov` never touches the flags.
#
#  TASK: each function must return the argument named in its name.
#  asm_first is already written as an example. The program will print
#      first=10 second=20 fourth=40 sixth=60
#
    .intel_syntax noprefix
    .text

    .globl asm_first
asm_first:
    mov rax, rdi
    ret

    .globl asm_second
asm_second:
    mov rax, rdi            # TODO: the second argument is not in rdi
    ret

    .globl asm_fourth
asm_fourth:
    mov rax, rdi            # TODO
    ret

    .globl asm_sixth
asm_sixth:
    mov eax, edi            # TODO: both the register and the width are wrong
    ret

    .section .note.GNU-stack,"",@progbits
