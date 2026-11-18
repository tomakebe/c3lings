# =====================================================================
#  a1403 · Unrolling + branchless: minimum and maximum in one pass
# =====================================================================
#
#  The whole function. The naive version with branches mispredicts on
#  random data: a "new minimum" shows up less and less often, but
#  irregularly. The branchless version with cmov never mispredicts, but
#  it creates a dependency chain: each cmovl depends on the previous
#  minimum (cmp + cmov = 2 cycles per element per chain).
#
#  So split things up here too: unroll by 2 elements with TWO pairs of
#  accumulators (min0/max0 for even, min1/max1 for odd), and merge them
#  at the end. This halves the chain length per element.
#
#  (The really fast way is SIMD: pminsd/pmaxsd on 4-8 elements at a
#  time. Try it once you have the scalar version working.)
#
#  TASK: minmax(a /*rdi*/, n /*rsi*/, out_min /*rdx*/, out_max /*rcx*/),
#  n >= 1. Store the minimum in *out_min and the maximum in *out_max.
#  No conditional branches inside the loop body (the loop branch is fine).
#
    .intel_syntax noprefix
    .text
    .globl minmax
minmax:
    push rbx
    mov r11, rcx                # out_max (rcx will be needed for the index)
    mov eax, [rdi]              # min0
    mov r8d, eax                # max0
    mov r9d, eax                # min1
    mov r10d, eax               # max1
    mov ecx, 1                  # i
    lea rbx, [rsi - 1]          # while i < n - 1 there is a pair
    jmp 2f
1:
    mov esi, [rdi + rcx*4]
    cmp esi, eax
    cmovl eax, esi
    cmp esi, r8d
    cmovg r8d, esi
    mov esi, [rdi + rcx*4 + 4]
    cmp esi, r9d
    cmovl r9d, esi
    cmp esi, r10d
    cmovg r10d, esi
    add rcx, 2
2:
    cmp rcx, rbx
    jl 1b
    # merge the pairs
    cmp r9d, eax
    cmovl eax, r9d
    cmp r10d, r8d
    cmovg r8d, r10d
    # tail: at most one element
    cmp rcx, rbx
    jne 3f
    mov esi, [rdi + rcx*4]
    cmp esi, eax
    cmovl eax, esi
    cmp esi, r8d
    cmovg r8d, esi
3:
    mov [rdx], eax
    mov [r11], r8d
    pop rbx
    ret

    .section .note.GNU-stack,"",@progbits
