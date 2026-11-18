# =====================================================================
#  a0904 · Constants in .rodata, sign masks, sqrtsd, Horner's scheme
# =====================================================================
#
#  SSE has no floating-point "immediate" operands: `addsd xmm0, 1.5`
#  does not exist. Constants are placed in a read-only data section and
#  addressed relative to RIP:
#
#          .section .rodata
#          .p2align 3
#      one_half:
#          .double 0.5
#          .text
#          ...
#          mulsd xmm0, qword ptr [rip + one_half]
#
#  (You can also build the constant in an integer register and move it over:
#   mov rax, 0x3FE0000000000000; movq xmm1, rax.)
#
#  Absolute value and negation are done with bit operations on the sign bit
#  (bit 63 for a double):
#      fabs:  andpd xmm0, [mask 0x7FFFFFFFFFFFFFFF]
#      fneg:  xorpd xmm0, [mask 0x8000000000000000]
#  andpd/xorpd are "packed" instructions: they operate on all 128 bits,
#  and their memory operand MUST be 16-byte aligned (otherwise — segfault).
#  So the mask is stored as a 16-byte constant with .p2align 4. This is
#  exactly what GCC and Clang do.
#
#  sqrtsd xmm0, xmm1 — square root, correctly rounded (IEEE 754).
#
#  Horner's scheme: p(x) = c0 + c1 x + c2 x^2 + ... + c_{n-1} x^{n-1}
#      acc = c[n-1]; for i = n-2 downto 0: acc = acc * x + c[i]
#
#  TASK: write the functions.
#      asm_fabs(x), asm_fneg(x)   — using the masks from .rodata (see below)
#      vec2_length(x, y)          = sqrt(x*x + y*y)
#      horner(c, n, x)            (n >= 1)
#      circle_area(r)             = pi * r * r; pi is a constant in .rodata
#                                   (.double 3.141592653589793)
#
    .intel_syntax noprefix
    .section .rodata
    .p2align 4
abs_mask:
    .quad 0x7FFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF
sign_mask:
    .quad 0x8000000000000000, 0x8000000000000000
    # TODO: add the pi constant

    .text

    .globl asm_fabs
asm_fabs:
    # TODO: andpd with abs_mask
    ret

    .globl asm_fneg
asm_fneg:
    # TODO: xorpd with sign_mask
    ret

# double vec2_length(double x /*xmm0*/, double y /*xmm1*/)
    .globl vec2_length
vec2_length:
    # TODO
    ret

# double horner(double* c /*rdi*/, long n /*rsi*/, double x /*xmm0*/)
    .globl horner
horner:
    # TODO
    ret

    .globl circle_area
circle_area:
    # TODO
    ret

    .section .note.GNU-stack,"",@progbits
