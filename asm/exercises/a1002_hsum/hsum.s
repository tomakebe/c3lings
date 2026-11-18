# =====================================================================
#  a1002 · Horizontal sum and the loop "tail"
# =====================================================================
#
#  A vectorized array sum: keep 4 partial sums in one register and add
#  4 elements per iteration:
#
#      acc = {0,0,0,0}
#      for (i = 0; i + 4 <= n; i += 4) acc += a[i..i+3]
#
#  At the end, the 4 elements of acc must be added together — a
#  "horizontal" operation that SIMD doesn't like. The classic (SSE):
#
#      movhlps xmm1, xmm0     # xmm1[0,1] = xmm0[2,3]
#      addps   xmm0, xmm1     # xmm0[0] = a0+a2, xmm0[1] = a1+a3
#      movaps  xmm1, xmm0
#      shufps  xmm1, xmm1, 1  # xmm1[0] = xmm0[1]   (imm: 2 bits per lane)
#      addss   xmm0, xmm1     # xmm0[0] = a0+a1+a2+a3
#
#  (There is haddps, but it is slower than this pair: 3 uops, 2 of them shuffles.)
#
#  Then comes the "tail": the remaining n % 4 elements, scalar (addss).
#  Without the tail the function only works for n divisible by 4 — a common bug.
#
#  Note: the vector sum adds the elements IN A DIFFERENT ORDER than a
#  simple loop. For float the result may differ in the last bits — which
#  is why the compiler won't vectorize such a loop by itself without -O5
#  (fast-math). The tests use integer values whose sum is exact.
#
#  TASK:
#      hsum4(v)       — sum of 4 floats from memory
#      sum_f32(a, n)  — sum of n floats, any n >= 0
#
    .intel_syntax noprefix
    .text

# float hsum4(float* v)
    .globl hsum4
hsum4:
    movups xmm0, [rdi]
    movhlps xmm1, xmm0
    addps xmm0, xmm1
    # TODO: one more shuffle and add
    ret

# float sum_f32(float* a /*rdi*/, long n /*rsi*/)
    .globl sum_f32
sum_f32:
    xorps xmm0, xmm0        # acc
    xor eax, eax            # i
    # TODO: main loop by 4, horizontal sum, scalar tail
    ret

    .section .note.GNU-stack,"",@progbits
