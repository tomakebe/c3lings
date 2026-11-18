# =====================================================================
#  a0804 · Iterating over set bits: blsr, blsi, tzcnt
# =====================================================================
#
#  Classic bit tricks, each of which has its own instruction in BMI1:
#
#      x & (x - 1)     clear the lowest set bit                 blsr dst, src
#      x & -x          keep only the lowest set bit             blsi dst, src
#      x ^ (x - 1)     mask up to and incl. the lowest set bit  blsmsk dst, src
#      ~x & y                                                   andn dst, x, y
#
#  blsr sets ZF if the result is 0, and CF if src was 0.
#  Hence the "power of two" check: x != 0 && (x & (x-1)) == 0.
#
#  The most useful technique is iterating over all set bits of a mask in
#  O(number of ones) rather than in 64 iterations:
#
#      while (x != 0) {
#          i = tzcnt(x);    // index of the lowest set bit
#          ...process i...
#          x = blsr(x);     // and drop it
#      }
#
#  This is how components in an ECS are iterated by archetype mask, free
#  slots in an allocator, chessboard squares in bitboards, and so on.
#
#  TASK: write the functions (TODO).
#      is_pow2(x)                 — 1 if x is a power of two, otherwise 0
#      lowest_bit(x)              — x & -x
#      sum_bit_indices(x)         — the sum of the indices of all set bits
#      collect_bits(x, out)       — write the indices of the set bits
#                                   (in ascending order) into out[] as bytes,
#                                   return their count
#
    .intel_syntax noprefix
    .text

# CInt is_pow2(ulong x /*rdi*/)
    .globl is_pow2
is_pow2:
    xor eax, eax
    test rdi, rdi
    jz 1f                   # 0 is not a power of two
    blsr rcx, rdi
    # TODO: if rcx == 0, return 1 (`test` + `sete al` will do)
1:
    ret

# ulong lowest_bit(ulong x)
    .globl lowest_bit
lowest_bit:
    mov rax, rdi            # TODO: a single BMI1 instruction
    ret

# ulong sum_bit_indices(ulong x)
    .globl sum_bit_indices
sum_bit_indices:
    xor eax, eax            # sum
    # TODO: loop: while rdi != 0 — rcx = tzcnt(rdi), rax += rcx, rdi = blsr(rdi)
    ret

# ulong collect_bits(ulong x /*rdi*/, char* out /*rsi*/)
    .globl collect_bits
collect_bits:
    # TODO: the whole thing. rax is the count of indices written
    xor eax, eax
    ret

    .section .note.GNU-stack,"",@progbits
