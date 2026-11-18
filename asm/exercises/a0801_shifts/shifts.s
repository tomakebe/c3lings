# =====================================================================
#  a0801 · Shifts: shl, shr, sar
# =====================================================================
#
#  A shift is the cheapest "arithmetic" a processor has (1 cycle,
#  several per cycle). The three basic shifts:
#
#      shl dst, k    — left, zeros come in from the right   (x * 2^k)
#      shr dst, k    — right, ZEROS come in from the left   (unsigned x / 2^k)
#      sar dst, k    — right, the SIGN bit is copied in from the left
#                      (signed division by 2^k, rounding toward -inf)
#
#  The shift count k can be:
#    * a constant:                       shl rax, 3
#    * the CL register — and only CL!    shl rax, cl
#  There is no such thing as `shl rax, rsi`: if the count is in rsi, you
#  must first move it into rcx (`mov rcx, rsi` or `mov ecx, esi`),
#  and then use its low byte `cl`.
#
#  The processor takes the count modulo 64 (modulo 32 for 32-bit
#  operands): `shl rax, cl` with cl = 65 shifts by 1. In C3, shifting by
#  >= the type width is an error (a panic in safe mode), while the
#  hardware silently masks the count.
#
#  Flags: CF receives the last bit "shifted out". With a count of 0 the
#  flags are not changed at all — which is why variable shifts are harder
#  for the processor than they look (on Intel `shl r, cl` is 2-3 uops).
#  BMI2 has `shlx/shrx/sarx dst, src, cnt` — count in any register,
#  flags untouched, 1 uop. More in chapter asm/docs/08_bits.md.
#
#  Extracting the bit field [pos, pos+len) is classically done like this:
#      (x >> pos) & ((1 << len) - 1)
#  The mask (1 << len) - 1 also has to be built with a variable shift.
#  Careful with len = 64: 1 << 64 wraps to 1 << 0, and the mask becomes 0.
#  In our tests len < 64.
#
#  TASK: fix the four functions (each one is marked TODO).
#      shl_var(x, n)  = x << n
#      shr_var(x, n)  = x >> n    (unsigned)
#      sar_var(x, n)  = x >> n    (signed)
#      extract_bits(x, pos, len) = (x >> pos) & ((1 << len) - 1)
#
    .intel_syntax noprefix
    .text

# ulong shl_var(ulong x /*rdi*/, ulong n /*rsi*/)
    .globl shl_var
shl_var:
    mov rax, rdi
    shl rax, 1              # TODO: the shift must be by n, not by 1 (via cl)
    ret

# ulong shr_var(ulong x, ulong n)
    .globl shr_var
shr_var:
    mov rax, rdi
    mov rcx, rsi
    sar rax, cl             # TODO: which shift do you need for an unsigned number?
    ret

# long sar_var(long x, ulong n)
    .globl sar_var
sar_var:
    mov rax, rdi
    mov rcx, rsi
    shr rax, cl             # TODO: and here the number is signed
    ret

# ulong extract_bits(ulong x /*rdi*/, ulong pos /*rsi*/, ulong len /*rdx*/)
    .globl extract_bits
extract_bits:
    mov rax, rdi
    mov rcx, rsi
    shr rax, cl             # rax = x >> pos
    # TODO: build the mask (1 << len) - 1 in some register
    #       (for example, r8) and do `and rax, r8`
    ret

    .section .note.GNU-stack,"",@progbits
