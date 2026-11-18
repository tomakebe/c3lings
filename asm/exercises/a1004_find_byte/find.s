# =====================================================================
#  a1004 · Finding a byte: pcmpeqb + pmovmskb + tzcnt
# =====================================================================
#
#  This is how memchr, strlen and parsers like simdjson work:
#
#      movd      xmm1, esi        # c into the low byte
#      pxor      xmm2, xmm2
#      pshufb    xmm1, xmm2       # broadcast byte 0 to all 16 (SSSE3)
#                                 # (in AVX2: vpbroadcastb xmm1, xmm1)
#    loop:
#      movdqu    xmm0, [rdi + i]  # 16 bytes of the string
#      pcmpeqb   xmm0, xmm1       # byte = 0xFF where it matched, else 0x00
#      pmovmskb  eax, xmm0        # 1 bit from each byte -> 16-bit mask
#      test      eax, eax
#      jnz       found            # index = i + tzcnt(eax)
#
#  The very same mask bit iteration from chapter 08! And for counting — popcnt.
#
#  The tail: you can't just read 16 bytes if fewer than 16 remain before
#  the end of the data — you might run past the end of the page and get a
#  segfault. (Real memchr implementations read aligned blocks: an aligned
#  16-byte block never crosses a page boundary. That's legal at the
#  hardware level, but sanitizers don't like it.) We'll keep it simple:
#  blocks of 16 while i + 16 <= n, then a scalar tail.
#
#  Important: pmovmskb puts the mask in eax, while the argument c arrived
#  in sil/esi; c itself is a char, i.e. only the low 8 bits of esi matter.
#
#  TASK:
#      find_byte(s, n, c)   — index of the first occurrence of c, or -1
#      count_byte(s, n, c)  — number of occurrences
#
    .intel_syntax noprefix
    .text

# long find_byte(char* s /*rdi*/, long n /*rsi*/, char c /*dl*/)
    .globl find_byte
find_byte:
    movd xmm1, edx
    pxor xmm2, xmm2
    pshufb xmm1, xmm2       # c in all 16 bytes
    xor eax, eax            # i
    lea rcx, [rsi - 15]
    jmp 2f
1:
    movdqu xmm0, [rdi + rax]
    pcmpeqb xmm0, xmm1
    pmovmskb r8d, xmm0
    # TODO: if the mask is not 0, the answer is rax + tzcnt(mask)
    add rax, 16
2:
    cmp rax, rcx
    jl 1b
    jmp 4f
3:
    cmp byte ptr [rdi + rax], dl
    je 9f
    inc rax
4:
    cmp rax, rsi
    jl 3b
    mov rax, -1
9:
    ret

# long count_byte(char* s, long n, char c)
    .globl count_byte
count_byte:
    # TODO: the whole thing (pcmpeqb, pmovmskb, popcnt + scalar tail)
    xor eax, eax
    ret

    .section .note.GNU-stack,"",@progbits
