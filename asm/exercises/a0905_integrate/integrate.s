# =====================================================================
#  a0905 · Calling a function from assembly with floating-point arguments
# =====================================================================
#
#  Midpoint rectangle rule:
#      h = (b - a) / n
#      integral ~= h * sum_{i=0}^{n-1} f(a + (i + 0.5) * h)
#
#  The main difficulty is calling f through a pointer (`call rbx`):
#
#    1. ALL xmm registers are caller-saved. After `call`, xmm0 holds f's
#       result, and the other xmm registers may contain anything. So the sum,
#       a and h must be kept in memory (on the stack) or... in integer
#       callee-saved registers (rbx, rbp, r12-r15) via movq r64, xmm.
#       System V has no callee-saved xmm registers at all (Windows x64 does).
#    2. Integer callee-saved registers (rbx, r12..r15) can be used for
#       f, n, i — but they must be saved in the prologue and restored in the epilogue.
#    3. Before `call`, rsp must be a multiple of 16. On function entry
#       rsp ≡ 8 (mod 16) (the return address). Count your pushes and sub rsp.
#
#  A suggested layout (you may do it differently):
#      push rbx; push r12; push r13         ; 3*8 + 8 (ret) = 32 — a multiple of 16
#      sub rsp, 32                          ; [rsp]=a, [rsp+8]=h, [rsp+16]=sum
#      ...                                  ; still a multiple of 16 — safe to call
#      add rsp, 32; pop r13; pop r12; pop rbx; ret
#
#  For (i + 0.5): cvtsi2sd xmm0, i; addsd with the constant 0.5 from .rodata.
#
#  TASK: write integrate(f /*rdi*/, a /*xmm0*/, b /*xmm1*/, n /*rsi*/).
#  f must be called exactly n times. The expected output is in checks/.
#
    .intel_syntax noprefix
    .section .rodata
    .p2align 3
half:
    .double 0.5

    .text
    .globl integrate
integrate:
    # TODO: the whole thing
    xorps xmm0, xmm0
    ret

    .section .note.GNU-stack,"",@progbits
