# =====================================================================
#  a0802 · Rotations and bit tests: rol/ror, bt/bts/btr
# =====================================================================
#
#  A rotation is a shift in which the bits shifted out are not lost
#  but come back in from the other side:
#
#      rol rax, cl    — rotate left      (rotl in hash functions, cryptography)
#      ror rax, cl    — rotate right
#
#  C3 (like C) has no dedicated rotate operator: you write
#  (x << n) | (x >> (64 - n)), and the compiler recognizes the idiom and emits rol.
#  The count is again only a constant or CL.
#
#  Bit tests:
#
#      bt  dst, i     — CF = bit i of dst
#      bts dst, i     — CF = bit i, then bit i := 1   (test-and-set)
#      btr dst, i     — CF = bit i, then bit i := 0   (test-and-reset)
#      btc dst, i     — CF = bit i, then the bit is inverted
#
#  If dst is a register, the index is taken modulo 64. But if dst is
#  MEMORY and the index is a register, the processor treats memory as a BIT
#  STRING of unlimited length: `bt qword ptr [rdi], rsi` with rsi = 200
#  tests bit 200 - 192 = 8 of the word [rdi + 24]. Handy for bitsets!
#  (The price: this form is microcoded, ~10 uops; compilers avoid it
#  and compute the word address themselves: i >> 6 and i & 63.)
#
#  The result is in the CF flag. To turn the flag into a 0/1 number:
#
#      setc al          # al = CF   (this is setcc, more in chapter 13)
#      movzx eax, al    # zero the remaining bits of eax
#
#  TASK: complete the functions marked TODO.
#      rotl64(x, n), rotr64(x, n)       — rotations
#      bitset_test(set, i)              — return bit i (0/1)
#      bitset_set(set, i)               — set the bit, return the OLD value
#      bitset_clear(set, i)             — clear the bit, return the OLD value
#
    .intel_syntax noprefix
    .text

# ulong rotl64(ulong x /*rdi*/, ulong n /*rsi*/)
    .globl rotl64
rotl64:
    mov rax, rdi
    mov rcx, rsi
    rol rax, cl
    ret

# ulong rotr64(ulong x, ulong n)
    .globl rotr64
rotr64:
    mov rax, rdi
    # TODO: rotate right by n
    ret

# CInt bitset_test(ulong* set /*rdi*/, ulong i /*rsi*/)
    .globl bitset_test
bitset_test:
    bt qword ptr [rdi], rsi
    xor eax, eax            # TODO: return CF (setc + movzx); this xor doesn't belong here
    ret

# CInt bitset_set(ulong* set, ulong i)
    .globl bitset_set
bitset_set:
    # TODO: bts + return the old bit value
    xor eax, eax
    ret

# CInt bitset_clear(ulong* set, ulong i)
    .globl bitset_clear
bitset_clear:
    # TODO: btr + return the old bit value
    xor eax, eax
    ret

    .section .note.GNU-stack,"",@progbits
