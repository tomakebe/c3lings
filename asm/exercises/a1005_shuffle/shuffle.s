# =====================================================================
#  a1005 · Shuffles: pshufd and pshufb
# =====================================================================
#
#  Data is often laid out "in the wrong order". SIMD shuffles:
#
#      pshufd xmm0, xmm1, imm8   — 4 dwords: result lane i = xmm1[(imm >> 2i) & 3]
#                                  imm is written in binary "right to left":
#                                  0b00_01_10_11 = 0x1B — reversal (3,2,1,0)
#      shufps xmm0, xmm1, imm8   — the same for float, but lanes 2,3 come from xmm1
#                                  and lanes 0,1 from xmm0
#      pshufb xmm0, xmm1         — (SSSE3) byte i = xmm0[xmm1[i] & 15],
#                                  or 0 if the top bit of xmm1[i] is 1.
#                                  An arbitrary permutation of 16 bytes via a table!
#
#  pshufb is a Swiss army knife: swapping color channels, changing byte
#  order, a 16-entry table lookup (fast popcount, base64 and UTF-8
#  validation are built on it).
#
#  Converting RGBA -> BGRA (swap bytes 0 and 2 in each pixel):
#  the pshufb mask = 2,1,0,3, 6,5,4,7, 10,9,8,11, 14,13,12,15 — 4 pixels
#  per instruction. The mask goes in .rodata (aligned to 16 if you want
#  to use it as pshufb's memory operand).
#
#  TASK:
#      reverse4(v)              — reverse 4 ints in place (pshufd)
#      rgba_to_bgra(px, count)  — count pixels (any number >= 0):
#                                 4 pixels at a time via pshufb, scalar tail
#                                 (e.g. mov eax, [px]; bswap eax; ror eax, 8
#                                 — think about what that does; or byte by byte)
#
    .intel_syntax noprefix
    .section .rodata
    .p2align 4
bgra_mask:
    .byte 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15   # TODO: this is the identity permutation

    .text

# void reverse4(int* v)
    .globl reverse4
reverse4:
    movdqu xmm0, [rdi]
    pshufd xmm0, xmm0, 0b11100100   # TODO: this imm doesn't permute anything
    movdqu [rdi], xmm0
    ret

# void rgba_to_bgra(char* px /*rdi*/, long count /*rsi*/)
    .globl rgba_to_bgra
rgba_to_bgra:
    movdqa xmm1, [rip + bgra_mask]
    # TODO: loop over 4 pixels (16 bytes), then a tail of one pixel at a time
    ret

    .section .note.GNU-stack,"",@progbits
