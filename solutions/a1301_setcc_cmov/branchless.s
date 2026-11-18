# =====================================================================
#  a1301 · Branchless code: cmov and setcc
# =====================================================================
#
#  A conditional jump (jcc) is a bet: the processor GUESSES the direction and
#  keeps executing without waiting for the comparison. Guessed right — the
#  jump is almost free. Guessed wrong — the whole started pipeline is thrown
#  away: a ~15-20 cycle penalty. For random data (50/50) that is very costly.
#
#  The alternative is to compute the result without a jump:
#
#      cmovCC dst, src   — if condition CC is true, dst = src (otherwise dst is unchanged)
#      setCC  r8         — r8 = condition ? 1 : 0   (8-bit register only!)
#
#  CC are the same conditions as for jcc: e/ne, l/le/g/ge (signed), b/be/a/ae
#  (unsigned), s/ns, o/no, p/np.
#
#      ; long max(long a, long b)
#      mov   rax, rdi
#      cmp   rdi, rsi
#      cmovl rax, rsi        ; if a < b, take b
#
#  Details:
#    * cmov can't take an immediate operand: `cmovl rax, 0` is not allowed —
#      put 0 in a register first;
#    * cmov with a memory operand ALWAYS READS the memory, even if the condition
#      is false (it can crash on a bad pointer!);
#    * setCC writes only the low byte: zero the register IN ADVANCE
#      (`xor eax, eax` before cmp — after cmp, xor would clobber the flags) or use movzx;
#    * sign of a number: (x > 0) - (x < 0) — two setcc and a subtraction.
#
#  TASK: write the functions without a single conditional jump.
#      bl_max(a, b), bl_abs(x), bl_sign(x) (-1/0/1), bl_clamp(x, lo, hi)
#
    .intel_syntax noprefix
    .text

# long bl_max(long a /*rdi*/, long b /*rsi*/)
    .globl bl_max
bl_max:
    mov rax, rdi
    cmp rdi, rsi
    cmovl rax, rsi
    ret

# long bl_abs(long x)
    .globl bl_abs
bl_abs:
    mov rax, rdi
    neg rax                 # rax = -x, SF = sign of -x
    cmovs rax, rdi
    ret

# CInt bl_sign(long x)
    .globl bl_sign
bl_sign:
    xor eax, eax
    xor ecx, ecx
    test rdi, rdi
    setg al
    setl cl
    sub eax, ecx
    ret

# long bl_clamp(long x, long lo, long hi)
    .globl bl_clamp
bl_clamp:
    mov rax, rdi
    cmp rax, rsi
    cmovl rax, rsi
    cmp rax, rdx
    cmovg rax, rdx
    ret

    .section .note.GNU-stack,"",@progbits
