# =====================================================================
#  a1302 · Branchless algorithms: counting and binary search
# =====================================================================
#
#  1. Counting elements less than pivot. The branch "if (a[i] < p) count++"
#     on random data is guessed right half the time. Without a branch:
#
#         cmp   dword ptr [rdi + rcx*4], edx
#         setl  r8b
#         add   rax, r8          ; (r8 is zeroed in advance, outside the loop;
#                                 ;  setl only changes the low byte)
#
#     Even more elegant is the carry flag: after `cmp a, p`, CF = 1 if a < p
#     UNSIGNED. That doesn't work for a signed comparison — use setl.
#
#  2. Binary search (lower_bound — the first index i where a[i] >= key).
#     The classic version branches randomly at every step.
#     The branchless version (see Paul Khuong's articles, "Array layouts for
#     comparison-based searching"):
#
#         base = 0; len = n
#         while (len > 1) {
#             half = len / 2
#             if (a[base + half - 1] < key) base += half   // <- cmov
#             len -= half
#         }
#         if (len == 1 && a[base] < key) base++            // last step
#         return base
#
#     Every iteration executes identically, there are no data-dependent jumps —
#     only the loop, whose iteration count = log2(n) (and is predicted
#     perfectly). On large arrays it is sped up further with prefetching.
#
#  TASK:
#      count_less(a, n, pivot)  — no branches in the loop body
#      lower_bound(a, n, key)   — following the scheme above, with cmov
#
    .intel_syntax noprefix
    .text

# long count_less(int* a /*rdi*/, long n /*rsi*/, int pivot /*edx*/)
    .globl count_less
count_less:
    xor eax, eax
    xor ecx, ecx
    xor r8d, r8d
    jmp 2f
1:
    cmp dword ptr [rdi + rcx*4], edx
    setl r8b
    add rax, r8
    inc rcx
2:
    cmp rcx, rsi
    jl 1b
    ret

# long lower_bound(int* a /*rdi*/, long n /*rsi*/, int key /*edx*/)
    .globl lower_bound
lower_bound:
    xor eax, eax            # base
    test rsi, rsi
    jz 9f
    jmp 2f
1:
    mov rcx, rsi
    shr rcx, 1              # half
    lea r8, [rax + rcx]     # base + half
    cmp dword ptr [rdi + r8*4 - 4], edx
    cmovl rax, r8           # a[base+half-1] < key  =>  base += half
    sub rsi, rcx            # len -= half
2:
    cmp rsi, 1
    jg 1b
    # len == 1
    lea r8, [rax + 1]
    cmp dword ptr [rdi + rax*4], edx
    cmovl rax, r8
9:
    ret

    .section .note.GNU-stack,"",@progbits
