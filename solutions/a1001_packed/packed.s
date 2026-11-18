# =====================================================================
#  a1001 · SIMD: packed SSE operations
# =====================================================================
#
#  An xmm register is 128 bits, i.e. 4 floats (or 2 doubles, 16 bytes,
#  8 shorts, 4 ints, 2 longs). Packed instructions process all elements
#  at once — "single instruction, multiple data" (SIMD):
#
#      addps xmm0, xmm1     4 float additions in one instruction
#      mulps, subps, divps, sqrtps, minps, maxps   ...
#      addpd                2 double additions
#
#  Loading/storing 16 bytes:
#      movaps xmm, [mem]   — the address MUST be a multiple of 16, else segfault
#      movups xmm, [mem]   — any address (just as fast on modern CPUs
#                            if the data actually is aligned)
#  The same goes for the memory operand of addps/mulps: `addps xmm0, [rdi]`
#  requires alignment! With unaligned data, movups into a register first.
#
#  "Broadcasting" a scalar to all 4 elements in SSE is done with a
#  shuffle:  shufps xmm1, xmm1, 0   — all 4 elements = element 0.
#  (AVX has vbroadcastss.)
#
#  TASK:
#      add4(dst, a, b)              — dst[0..3] = a[0..3] + b[0..3]
#      scale4(v, k)                 — v[0..3] *= k   (k in xmm0)
#      add_arrays(dst, a, b, n)     — n is a multiple of 4; addresses are NOT aligned
#
    .intel_syntax noprefix
    .text

# void add4(float* dst /*rdi*/, float* a /*rsi*/, float* b /*rdx*/)
    .globl add4
add4:
    movups xmm0, [rsi]
    movups xmm1, [rdx]
    addps xmm0, xmm1
    movups [rdi], xmm0
    ret

# void scale4(float* v /*rdi*/, float k /*xmm0*/)
    .globl scale4
scale4:
    movups xmm1, [rdi]
    shufps xmm0, xmm0, 0
    mulps xmm1, xmm0
    movups [rdi], xmm1
    ret

# void add_arrays(float* dst, float* a, float* b, long n /*rcx*/)
    .globl add_arrays
add_arrays:
    xor eax, eax
    jmp 2f
1:
    movups xmm0, [rsi + rax*4]
    movups xmm1, [rdx + rax*4]
    addps xmm0, xmm1
    movups [rdi + rax*4], xmm0
    add rax, 4
2:
    cmp rax, rcx
    jl 1b
    ret

    .section .note.GNU-stack,"",@progbits
