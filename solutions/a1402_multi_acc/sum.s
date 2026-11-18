# =====================================================================
#  a1402 · Dependency chains and multiple accumulators
# =====================================================================
#
#  The simplest sum:
#      1: add rax, [rdi + rcx*8]
#         inc rcx
#         cmp rcx, rsi
#         jl 1b
#  Each add waits for the result of the previous one — this is a
#  DEPENDENCY CHAIN. Its speed is limited by the LATENCY of add: 1 cycle
#  per element. Even though the processor can execute 3-4 adds per cycle
#  (THROUGHPUT) and 2-3 loads per cycle.
#
#  The fix is several independent accumulators:
#      s0 += a[i]; s1 += a[i+1]; s2 += a[i+2]; s3 += a[i+3];
#  Four chains run in parallel; at the end s0+s1+s2+s3, then the tail.
#  As a bonus, unrolling the loop reduces overhead (inc/cmp/jl per 4
#  elements instead of one).
#
#  For integers the order of addition doesn't matter (overflow wraps the
#  same way). For floats it does (chapter 10), so the compiler won't do
#  this on its own without fast-math. With floating point the gain is
#  even larger: addsd latency is ~3-4 cycles and 2 can issue per cycle
#  => up to 8 accumulators.
#
#  Rule: loop time >= max(length of the longest dependency chain per
#  iteration * its latency, number of µops / pipeline width, load on the
#  busiest port). This is "bottleneck analysis" (see uiCA, llvm-mca).
#
#  TASK: complete sum_i64(a, n) — 4 accumulators (rax, r8, r9, r10),
#  unrolled by 4, then add up the accumulators and handle the tail.
#
    .intel_syntax noprefix
    .text
    .globl sum_i64
sum_i64:
    xor eax, eax
    xor r8d, r8d
    xor r9d, r9d
    xor r10d, r10d
    xor ecx, ecx
    lea rdx, [rsi - 3]
    jmp 2f
1:
    add rax, [rdi + rcx*8]
    add r8,  [rdi + rcx*8 + 8]
    add r9,  [rdi + rcx*8 + 16]
    add r10, [rdi + rcx*8 + 24]
    add rcx, 4
2:
    cmp rcx, rdx
    jl 1b
    add rax, r8
    add r9, r10
    add rax, r9
    jmp 4f
3:
    add rax, [rdi + rcx*8]
    inc rcx
4:
    cmp rcx, rsi
    jl 3b
    ret

    .section .note.GNU-stack,"",@progbits
