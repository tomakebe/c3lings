# =====================================================================
#  a0803 · Counting bits: popcnt, lzcnt, tzcnt
# =====================================================================
#
#  Three "count the bits" instructions (all 1 uop, latency ~1-3 cycles):
#
#      popcnt dst, src   — number of set bits                (POPCNT)
#      lzcnt  dst, src   — number of leading zeros           (LZCNT/ABM)
#      tzcnt  dst, src   — number of trailing zeros          (BMI1)
#
#  For src = 0, lzcnt and tzcnt return the operand width (64) and set CF.
#
#  Their old relatives — bsr/bsf (bit scan reverse/forward) — return the
#  INDEX of the highest/lowest set bit, and for src = 0 they leave dst
#  UNDEFINED (in practice, untouched) and set ZF. The relationship:
#
#      bsr(x) = 63 - lzcnt(x)       (x != 0)
#      bsf(x) = tzcnt(x)            (x != 0)
#
#  Pitfall: tzcnt is encoded as `rep bsf`. An old processor without BMI1
#  will silently execute it as bsf — with a different result for zero. So
#  before using BMI/LZCNT you check cpuid (here we have everything).
#
#  Another (historical) pitfall: on Intel before Cannon Lake, popcnt/lzcnt/tzcnt
#  had a "false dependency" on the destination register. Compilers insert
#  `xor eax, eax` before `popcnt rax, rdi` to break it.
#
#  Useful formulas:
#      floor(log2(x))   = 63 - lzcnt(x)                      (x >= 1)
#      next_pow2(x)     = 1 << (64 - lzcnt(x - 1))           (x >= 2)
#                         and next_pow2(1) = 1 is a special case, because
#                         lzcnt(0) = 64, and a shift by 64 modulo 64 = a shift by 0 —
#                         ...which, surprisingly, gives 1 << 0 = 1. Lucky!
#
#  TASK: complete the functions (TODO).
#      asm_popcount(x), asm_ctz(x) (ctz(0) = 64),
#      asm_log2_floor(x) (x >= 1), asm_next_pow2(x) (x >= 1, x <= 2^63)
#
    .intel_syntax noprefix
    .text

    .globl asm_popcount
asm_popcount:
    xor eax, eax
    # TODO: popcnt
    ret

    .globl asm_ctz
asm_ctz:
    bsf rax, rdi            # TODO: bsf works incorrectly for zero
    ret

    .globl asm_log2_floor
asm_log2_floor:
    lzcnt rax, rdi
    # TODO: turn the leading-zero count into the index of the highest bit
    ret

    .globl asm_next_pow2
asm_next_pow2:
    # TODO: 1 << (64 - lzcnt(x - 1))
    mov rax, rdi
    ret

    .section .note.GNU-stack,"",@progbits
