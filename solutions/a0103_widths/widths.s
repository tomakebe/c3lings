# =====================================================================
#  a0103 · Register widths: 64, 32, 16, 8 bits
# =====================================================================
#
#  Every general-purpose register has "windows" of different widths:
#
#      64     32     16    8 (low)
#      rax    eax    ax    al          (and ah = bits 8..15 for a/b/c/d)
#      rdi    edi    di    dil
#      rsi    esi    si    sil
#      r8     r8d    r8w   r8b   ... and so on up to r15
#
#  Write rules (IMPORTANT, this is a favorite source of bugs):
#    * writing a 32-bit register (eax) ZEROES the upper 32 bits of rax;
#    * writing a 16- or 8-bit one (ax, al) does NOT touch the other bits.
#
#  To widen a small value into a bigger register there are:
#    movzx eax, dil     — zero-extend: pad with zeros (unsigned);
#    movsx rax, dil     — sign-extend: replicate the sign bit;
#    movsxd rax, edi    — sign-extend 32 -> 64 (for int -> long).
#  (You don't need movzx into a 64-bit destination: movzx eax, ... already
#  zeroes the top of rax by the first rule.)
#
#  One more ABI trap: if an argument has type `int` (32 bits), the
#  caller puts it in edi, and the upper 32 bits of rdi are UNDEFINED —
#  there may be garbage or zeros, but certainly not a sign extension.
#  So `mov rax, rdi` for an int argument is a bug.
#
#  TASK: fix four functions:
#    asm_low32(x)  — the low 32 bits of x (unsigned);
#    asm_low8(x)   — the low byte of x (unsigned, 0..255);
#    asm_sext8(x)  — the low byte of x as a signed number (-128..127);
#    asm_sext32(x) — int x, extended to long.
#  The program will print
#      low32=55667788 low8=88 sext8=-120 sext32=-5
#
    .intel_syntax noprefix
    .text

    .globl asm_low32
asm_low32:
    mov eax, edi
    ret

    .globl asm_low8
asm_low8:
    movzx eax, dil
    ret

    .globl asm_sext8
asm_sext8:
    movsx rax, dil
    ret

    .globl asm_sext32
asm_sext32:
    movsxd rax, edi
    ret

    .section .note.GNU-stack,"",@progbits
