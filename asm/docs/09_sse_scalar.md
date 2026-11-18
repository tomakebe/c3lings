# Chapter 09. Floating point: scalar SSE

In 64-bit x86 code, floating-point arithmetic lives almost entirely in the
SSE unit: 16 registers `xmm0`–`xmm15`, 128 bits each. The old stack-based
x87 coprocessor (`fld`, `fadd`, `st0`…`st7`) survives for compatibility and
for the 80-bit `long double`, but compilers do not use it for
`float`/`double`.

In this chapter we use only the **low part** of an xmm register — the
"scalar" instructions. In chapter 10 the same registers start working as
vectors.

Exercises: `a0901`–`a0905`.

## 1. IEEE 754 in two minutes

`double` is 64 bits: 1 sign bit, 11 exponent bits, 52 mantissa bits.
`float` is 32 bits: 1 + 8 + 23.

```
double 1.0  = 0x3FF0000000000000
double -2.5 = 0xC004000000000000
float  1.0  = 0x3F800000
```

Special values: `±0` (two zeros!), `±inf` (exponent all ones, mantissa 0),
`NaN` (exponent all ones, mantissa non-zero), denormal numbers (exponent
0). Important consequences:

* `NaN != NaN`; every comparison with NaN except `!=` is false.
* `-0.0 == 0.0`, but `1 / -0.0 = -inf`.
* The sign is exactly the top bit, so `fabs` and `-x` are done with bit
  masks, not arithmetic.
* Addition is not associative: `(a + b) + c` may differ from
  `a + (b + c)`. That is why the compiler **is not allowed** to reorder
  floating-point operations (without `-ffast-math`; in c3c, without
  `-O5`), and this seriously hampers vectorization of reductions
  (chapter 10).
* On many processors denormal numbers are handled tens of times slower
  (microcode). The FTZ/DAZ modes in MXCSR turn them off.

## 2. Registers and suffixes

The name of an SSE instruction encodes the data type:

| Suffix | Meaning | Type |
|---|---|---|
| `ss` | scalar single | one `float` in bits 0–31 |
| `sd` | scalar double | one `double` in bits 0–63 |
| `ps` | packed single | 4 `float`s (chapter 10) |
| `pd` | packed double | 2 `double`s (chapter 10) |

## 3. Core instructions

| Instruction | Action |
|---|---|
| `movss xmm, m32` / `movsd xmm, m64` | load; **zeroes** the remaining bits of xmm |
| `movss xmm, xmm` / `movsd xmm, xmm` | copies only the low element, keeps the rest |
| `movaps`/`movapd xmm, xmm` | copy of the whole register — this is how compilers copy scalars |
| `movd`/`movq` | between xmm and an integer register (`movq rax, xmm0`) |
| `addsd`, `subsd`, `mulsd`, `divsd` | arithmetic: `dst = dst op src` |
| `sqrtsd xmm, xmm/m64` | square root, correctly rounded |
| `minsd`, `maxsd` | minimum/maximum (asymmetric for NaN!) |
| `ucomisd`, `comisd` | comparison → EFLAGS |
| `cmpsd xmm, xmm, pred` | comparison → mask of all ones/zeros in xmm |
| `andpd`, `orpd`, `xorpd`, `andnpd` | bitwise operations on all 128 bits |
| `roundsd xmm, xmm, imm` | rounding with an explicit mode (SSE4.1) |
| `cvt*` | conversions, see below |

Example: `double hyp(double x, double y) => sqrt(x*x + y*y);`

```asm
hyp:
    mulsd  xmm0, xmm0
    mulsd  xmm1, xmm1
    addsd  xmm0, xmm1
    sqrtsd xmm0, xmm0
    ret
```

### AVX forms

With AVX, every SSE instruction gained a VEX version with a `v` prefix and
**three** operands: `vaddsd xmm0, xmm1, xmm2` (xmm0 = xmm1 + xmm2). The
sources are not clobbered — fewer extra `movapd`s. Look at c3c's output:
by default it compiles for your CPU, and you will see exactly `vaddsd`,
`vucomisd` and so on. Mixing "legacy" SSE and VEX instructions on the
same register is expensive on some CPUs (see `vzeroupper` in chapter 10);
in scalar code written in a single style this is not a problem.

## 4. ABI: floating-point arguments

System V AMD64:

* `float`/`double` arguments go in `xmm0`…`xmm7`, **numbered separately**
  from the integer ones (`rdi, rsi, rdx, rcx, r8, r9`);
* the return value is in `xmm0` (for a pair of doubles in a struct,
  `xmm0:xmm1`);
* **all** xmm registers are caller-saved: after any `call` their contents
  are lost;
* for variadic functions (`printf`), `al` holds the number of vector
  registers used.

```
double mix(long k, double x, long m, float y)
            rdi       xmm0      rsi     xmm1
```

The absence of callee-saved xmm registers is the main practical difference
from integer registers. If your function calls another one and keeps live
values in xmm, save them on the stack (`movsd [rsp+8], xmm1`) or in an
integer callee-saved register (`movq rbx, xmm1`). On Windows x64, by
contrast, `xmm6`–`xmm15` are callee-saved — portable code accounts for
this.

Stack alignment before `call` is still 16 bytes — and here it is not a
formality: the callee may use `movaps [rsp+...]`, which requires
alignment, and crash.

## 5. Conversions

| Instruction | From → to | Rounding |
|---|---|---|
| `cvtsi2sd xmm, r/m32/64` | integer → double | per MXCSR (for large longs) |
| `cvtsi2ss xmm, r/m32/64` | integer → float | per MXCSR |
| `cvttsd2si r32/64, xmm/m64` | double → integer | **toward zero** (like a cast in C3) |
| `cvtsd2si r32/64, xmm/m64` | double → integer | per MXCSR (round to nearest even by default) |
| `cvtss2sd`, `cvtsd2ss` | float ↔ double | per MXCSR |
| `roundsd xmm, xmm, imm` | double → double | imm: 0 nearest, 1 down, 2 up, 3 toward zero |

Subtleties:

* Round to nearest **even**: `2.5 → 2`, `3.5 → 4`, `-2.5 → -2`. This is
  not the schoolbook rule; it is the IEEE standard ("banker's rounding"),
  which reduces systematic error when summing.
* If the value does not fit in the target type, or is NaN, the result is
  the "integer indefinite" `0x8000...0` (`long.min`). In C3, overflow in a
  cast is undefined behavior, and on x86 this is exactly what you get.
* SSE has no unsigned `u64 ↔ double` conversions (they appeared only in
  AVX-512). Compilers build them out of several instructions — look at
  `(double)x` for a `ulong`.
* `cvtsi2sd xmm0, rdi` changes only the low 64 bits and therefore depends
  on the old value of xmm0. Compilers break the dependency: `xorps xmm0,
  xmm0` before it, or (like c3c/LLVM with AVX) `vcvtsi2sd xmm0, xmm15,
  rdi` — taking the "upper bits" from a register that hasn't been touched
  in a long time.

## 6. Comparisons

`ucomisd a, b` sets the flags like an **unsigned** comparison, plus PF for
an unordered result:

| Result | ZF | PF | CF |
|---|---|---|---|
| a > b | 0 | 0 | 0 |
| a < b | 0 | 0 | 1 |
| a == b | 1 | 0 | 0 |
| NaN | 1 | 1 | 1 |

Hence the rules:

* after `ucomisd`, use `ja`/`jae`/`jb`/`jbe`/`je`, not `jg`/`jl`;
* NaN looks like "both less and equal" — check `jp` first if that
  matters;
* `ja` and `jae` are false for NaN — compilers exploit this: `a < b`
  compiles to `ucomisd b, a; seta al` (the operands are swapped);
* `a == b` needs two checks (`ZF=1 and PF=0`): `sete al; setnp cl;
  and al, cl` — or, as LLVM does, `cmpeqsd` + extracting a bit.

`cmpsd xmm0, xmm1, pred` (`cmpltsd`, `cmpeqsd`, `cmpunordsd` …) puts a
mask of all ones or all zeros into xmm0 instead of setting flags. This is
the basis of branchless floating-point code: `blend = (mask & a) | (~mask
& b)` via `andpd`/`andnpd`/`orpd`, and with SSE4.1, `blendvpd`.

### min and max

`minsd dst, src` = `dst < src ? dst : src`. If at least one is NaN, the
result is `src`; for `minsd(+0, -0)` it is also `src`. This is not like
`fmin` from libm (which ignores NaN), but it matches the C3 expression
`a < b ? a : b` exactly — which is why the compiler turns such an
expression into a single instruction. `clamp(x, lo, hi)` is `maxsd` +
`minsd`.

## 7. Constants

There are no floating-point immediate operands. Constants live in
`.rodata` and are addressed relative to `rip`:

```asm
    .section .rodata
    .p2align 4
sign_mask: .quad 0x8000000000000000, 0x8000000000000000
pi:        .double 3.141592653589793
    .text
fneg:
    xorpd xmm0, xmmword ptr [rip + sign_mask]   # needs an aligned address!
    ret
area:
    mulsd xmm0, xmm0
    mulsd xmm0, qword ptr [rip + pi]
    ret
```

Instructions with `pd`/`ps` (non-VEX) require the memory operand to be
16-byte aligned, otherwise you get `SIGSEGV` (general protection). The
scalar `mulsd xmm, m64` does not require alignment. VEX forms (`vxorpd`)
don't either — that is one of their advantages.

An alternative without memory: `mov rax, 0x400921FB54442D18; movq xmm1,
rax`. `0.0` is obtained with `xorps xmm0, xmm0`, and "all ones" with
`pcmpeqd xmm0, xmm0`.

## 8. What the compiler emits

A few functions and their `-O3` output from c3c (AT&T syntax converted to
Intel; c3c compiles for the current CPU by default, hence AVX):

| C3 | Assembly |
|---|---|
| `a < b` (double) | `vucomisd xmm1, xmm0; seta al` |
| `a == b` | `vcmpeqsd xmm0, xmm0, xmm1; vmovq rax, xmm0; and eax, 1` |
| `a < 0 ? -a : a` | `vxorpd xmm1, xmm0, [rip+mask]; vmaxsd xmm0, xmm1, xmm0` |
| `(long)a` | `vcvttsd2si rax, xmm0` |
| `(double)n` | `vcvtsi2sd xmm0, xmm15, rdi` |
| `a * b + c` (float) | `vmulss` + `vaddss` (without `-O5` no FMA fusion: a different rounding result!) |

The last row matters: `fma(a, b, c)` rounds once, while `a*b + c` rounds
twice. The compiler is not allowed to silently substitute one for the
other unless "fast math" flags permit it.

## 9. Pitfalls

* Swapped operand order in `subsd`/`divsd`.
* `jg`/`jl` after `ucomisd` — always wrong.
* A forgotten `jp` where NaN matters.
* Live values in xmm across a `call` — lost.
* An unaligned memory operand for `andpd`/`xorpd`/`movaps`.
* `movsd xmm0, xmm1` does not zero the upper half, but `movsd xmm0, [mem]`
  does. The same goes for `movss`.
* Comparing floating-point numbers for exact equality is almost always a
  bug in the program's logic (not in the assembly); in the tests we use
  values that are exactly representable in binary (0.5, 0.25, 7.75).

## Self-check questions

1. In which registers do the arguments of `f(int a, float b, double* c, double d)` arrive?
2. Why use `ja` rather than `jg` after `ucomisd`?
3. What does `cvtsd2si` return for 2.5 and for -3.5? And `cvttsd2si`?
4. Why does `(long)1e300` give a negative number on x86?
5. How do you compute `fabs(x)` with a single instruction? Why must its
   memory operand be aligned?
6. Which xmm registers are preserved across a function call in System V?
   And in Windows x64?
7. How does `minsd` differ from `fmin` for NaN?
8. Why does the compiler emit `xorps xmm0, xmm0` before `cvtsi2sd xmm0, rdi`?

## Further reading

* David Goldberg, "What Every Computer Scientist Should Know About
  Floating-Point Arithmetic" (1991) — a classic.
* Intel SDM Vol. 1, ch. 10–11 (SSE/SSE2) and Vol. 2 — descriptions of
  `UCOMISD`, `CVTSD2SI`, `MINSD`.
* System V AMD64 ABI, section 3.2.3 "Parameter Passing".
* Agner Fog, "Optimizing subroutines in assembly language", the chapter on
  floating point; "Calling conventions for different C++ compilers".
* Bruce Dawson, the "Comparing Floating Point Numbers" series (randomascii.wordpress.com).
* https://float.exposed — bit-level visualization of float/double.
