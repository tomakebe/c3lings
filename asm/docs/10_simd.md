# Chapter 10. SIMD: SSE and AVX2, Loop Vectorization

A scalar instruction adds two numbers. A vector instruction adds 4, 8, 16
or 32 pairs in the same time. SIMD (Single Instruction, Multiple Data) is
the main source of "free" performance in numeric code: image and audio
processing, physics, matrices, string search, parsing, hashing. Compilers
can vectorize simple loops on their own, but far from always — and to
understand when they can and when they can't, you need to be able to
write SIMD by hand.

Exercises: `a1001`–`a1006`.

## 1. Registers and generations

| Extension | Year | Registers | Width | Key features |
|---|---|---|---|---|
| SSE | 1999 | xmm0–7 | 128 | 4×float |
| SSE2 | 2001 | xmm | 128 | double and integers (16×i8 … 2×i64); x86-64 baseline |
| SSE3/SSSE3 | 2004–06 | xmm | 128 | `haddps`, `pshufb`, `pabsd` |
| SSE4.1/4.2 | 2007–08 | xmm | 128 | `pminsd`, `blendvps`, `roundps`, `ptest`, `pcmpistri`, `crc32` |
| AVX | 2011 | ymm0–15 | 256 | float/double, VEX: 3 operands |
| AVX2 | 2013 | ymm | 256 | 256-bit integers, `vpermd`, gather, `vpbroadcast*` |
| FMA3 | 2013 | xmm/ymm | | `vfmadd231ps` etc. |
| AVX-512 | 2016+ | zmm0–31, k0–7 | 512 | masks, scatter (not used in this course) |

x86-64 has 16 vector registers (`xmm0`–`xmm15`); `xmmN` is the lower half
of `ymmN`. The levels "x86-64-v2" (SSE4.2, POPCNT), "v3" (AVX2, FMA,
BMI1/2) and "v4" (AVX-512) are handy labels understood by GCC/Clang;
c3c uses `--x86cpu=sse4`, `avx2-v2`, and so on.

## 2. Data types and suffixes

The same register is interpreted differently by different instructions:

| Suffix / prefix | Data in 128 bits |
|---|---|
| `ps` / `pd` | 4×float / 2×double |
| `pb`, `pw`, `pd`, `pq` (integer: `paddb`, `paddw`, `paddd`, `paddq`) | 16×i8, 8×i16, 4×i32, 2×i64 |
| `us`/`s` (`paddusb`, `paddsw`) | saturating arithmetic |

Careful: for floating point `pd` means packed double, but for integers
(`paddd`) it means packed dword. Integer instructions start with `p`.

Bitwise operations come in "float" and "integer" flavors (`andps`,
`andpd`, `pand`) — the result is the same, but on some processors moving
data between the floating-point and integer execution domains costs an
extra cycle (bypass delay). Use the variant matching the type of the
surrounding code.

## 3. Loads and stores

| Instruction | What it does | Alignment |
|---|---|---|
| `movaps`/`movapd`/`movdqa` | 16 bytes | 16 **required** |
| `movups`/`movupd`/`movdqu` | 16 bytes | any |
| `vmovaps ymm`/`vmovdqa ymm` | 32 bytes | 32 **required** |
| `vmovups ymm`/`vmovdqu ymm` | 32 bytes | any |
| `movss`/`movsd`/`movd`/`movq` | 4/8 bytes into the low element | any |
| `vbroadcastss ymm, m32/xmm` | replicate a float into 8 lanes | any |
| `vpbroadcastb/w/d/q` | replicate an integer | any |
| `movntps`/`vmovntdq` | store "bypassing the cache" (non-temporal) | required |

Rules:

1. An unaligned load (`movups`) on modern processors is as fast as an
   aligned one **if the data actually is aligned**. The penalty appears
   when the load crosses a cache line boundary (64 bytes), and especially
   a page boundary (4 KiB).
2. A memory operand of a non-VEX SSE instruction (`addps xmm0, [rdi]`)
   must be 16-byte aligned. For VEX forms (`vaddps ymm0, ymm1, [rdi]`) it
   need not be. This is a common cause of "works on my machine, crashes
   for the user".
3. The System V stack is 16-byte aligned — for `ymm` values on the stack
   you have to align the frame manually (`and rsp, -32`).

## 4. Arithmetic and comparisons

| Operation | float | double | integer |
|---|---|---|---|
| + − | `addps`, `subps` | `addpd`, `subpd` | `paddb/w/d/q`, `psubb/w/d/q` |
| × | `mulps` | `mulpd` | `pmullw`, `pmulld` (SSE4.1, slow), `pmuludq` |
| ÷, √ | `divps`, `sqrtps` | `divpd`, `sqrtpd` | — |
| min/max | `minps`, `maxps` | `minpd`, `maxpd` | `pminsd`, `pmaxub` … |
| FMA | `vfmadd231ps` | `vfmadd231pd` | — |
| compare → mask | `cmpps xmm, xmm, pred` | `cmppd` | `pcmpeqb/w/d/q`, `pcmpgtb/w/d/q` |
| mask → bits | `movmskps` | `movmskpd` | `pmovmskb` (one bit from each byte) |
| select by mask | `blendvps`, or `and/andn/or` | `blendvpd` | `pblendvb` |

Comparisons return a **mask**: each element becomes "all ones" or "all
zeros". This is the foundation of branchless branching in SIMD: compute
both branches and blend.

```asm
; x = max(x, 0) for 4 ints without pmaxsd (SSE2):
pxor    xmm1, xmm1
movdqa  xmm2, xmm0
pcmpgtd xmm2, xmm1      ; mask x > 0
pand    xmm0, xmm2      ; keep only the positive ones
```

FMA: `vfmadd231ps a, b, c` → `a = b*c + a`. The digits give the operand
order ("231": second × third + first). There are also `132` and `213`
variants, so that the result can overwrite any of the inputs. FMA rounds
**once**, so `fma(a,b,c)` and `a*b+c` may differ in the last bit.

## 5. Shuffles

| Instruction | What it does |
|---|---|
| `shufps xmm0, xmm1, imm` | lanes 0–1 from xmm0, 2–3 from xmm1, 2 bits of imm per lane |
| `pshufd xmm0, xmm1, imm` | any permutation of 4 dwords from one source |
| `pshufb xmm0, xmm1` | any permutation of 16 bytes via a table (SSSE3) |
| `unpcklps`/`unpckhps`, `punpckl*`/`punpckh*` | interleave elements of two registers |
| `movhlps`, `movlhps` | move halves |
| `palignr` | "concatenate" two registers and shift by bytes |
| `vperm2f128`, `vextractf128`, `vinsertf128` | work with the 128-bit halves of ymm |
| `vpermd`, `vpermps` | permute 8 dwords across the full ymm width (AVX2) |

An important property of AVX/AVX2: most "in-register" operations
(`vshufps`, `vpshufb`, `vunpcklps`, `vhaddps`) work **independently in the
two 128-bit halves (lanes)**. Moving data between the halves is only
possible with special instructions (`vperm2f128`, `vpermd`,
`vextractf128`), and they are more expensive (3-cycle latency). This is
the main source of surprises when moving from SSE to AVX2.

Encoding `imm` for `pshufd`/`shufps`: result lane `i` takes element
`(imm >> 2i) & 3`. Reversal (3,2,1,0) is `0b00_01_10_11 = 0x1B`;
"broadcast element 0" is `0`.

## 6. Horizontal operations

SIMD is good "vertically" (element i with element i). Adding up the
elements of a single register is expensive. The standard reduction of 8
floats in ymm0:

```asm
vextractf128 xmm1, ymm0, 1     ; upper 4
vaddps       xmm0, xmm0, xmm1  ; 4 sums
vmovhlps     xmm1, xmm1, xmm0  ; elements 2,3 -> 0,1
vaddps       xmm0, xmm0, xmm1  ; 2 sums
vshufps      xmm1, xmm0, xmm0, 1
vaddss       xmm0, xmm0, xmm1  ; 1 sum
```

`haddps` exists, but it is 3 uops (two shuffles and an add) — usually
slower. The main rule: do the horizontal reduction **once at the end of
the loop**, not on every iteration.

## 7. Vectorizing a loop: the skeleton

```
i = 0
// 1. main loop: while >= W elements remain (W = 4/8/16/32)
while (i + W <= n) { process a[i .. i+W-1]; i += W }
// 2. tail: the remaining n % W elements, scalar
while (i < n) { process a[i]; i++ }
```

In assembly, the condition `i + W <= n` is conveniently written as
`i < n - (W-1)`, computing `n - (W-1)` once (`lea rcx, [rsi - 7]`); the
comparison must be **signed** (`jl`), so that when `n < W` the bound
becomes negative and the main loop does not run at all.

Ways to handle the tail:

* a scalar loop (simple, slow for small n);
* an "overlapping" last iteration: process `a[n-W .. n-1]` once more —
  fine for idempotent operations (copying yes; in-place transformation
  no; accumulating into a sum no);
* masked loads `vmaskmovps` (AVX) or AVX-512 masks;
* aligning data and padding at the end of the buffer — a common choice
  in engines: component arrays are padded to a multiple of 8 up front.

### Alignment and prologue

For streaming stores, or for speed on older CPUs, people sometimes write
a "prologue": process elements scalarly up to the first address that is a
multiple of 32, then the main loop with `vmovaps`, then the tail. This is
an example from chapter 14.

### Multiple accumulators

Reductions (sum, dot product) with a single accumulator are bound by
instruction latency: `vaddps` takes 3–4 cycles, yet two of them can start
per cycle. Splitting the sum into 2–4 independent accumulators gives a
2–8× speedup. c3c (LLVM) does exactly this for integer sums: look at the
`-O3` output for the `isum` function below — four accumulator registers.

## 8. vzeroupper and mixing SSE/AVX

If your code used ymm registers, execute `vzeroupper` before returning to
"foreign" code or calling a foreign function. The reason: legacy (non-VEX)
SSE instructions don't know about the upper 128 bits of ymm and must
preserve them. On Intel Sandy Bridge through Broadwell this caused
expensive state transitions (~70 cycles); on Skylake, a false dependency
of every SSE instruction on the old data. Compilers insert `vzeroupper`
automatically before `ret` and `call` in functions that touched ymm. In
hand-written code it's your responsibility.

## 9. What the compiler can do

```c3
fn int isum(int* a, long n) { int s; for (long i = 0; i < n; i++) s += a[i]; return s; }
fn float fsum(float* a, long n) { float s; for (long i = 0; i < n; i++) s += a[i]; return s; }
```

c3c `-O3` (on Zen 2):

* `isum` is vectorized: four `vpaddd xmm` accumulators, 16 ints per
  iteration, then a horizontal reduction and a scalar tail;
* `fsum` is **not** vectorized: an unrolled chain of `vaddss` in a row.
  Float addition is not associative, and without fast-math the compiler
  has no right to reorder it. With `-O5` (fast math) it vectorizes.

Interestingly, LLVM chose xmm rather than ymm: the cost model for Zen 2
(where 256-bit operations are internally split into two 128-bit halves)
sees no benefit. On Intel you'd get ymm.

Other things that block auto-vectorization: possible pointer aliasing
(`dst` may point into `src`), branches in the loop body, function calls,
complex dependencies between iterations, irregular memory access, and
"early exit" (search). Compilers almost never vectorize a search (like
`find_byte`) — that's a job for hand-written code or libraries.

C3 has built-in vector types — `float[<8>]`, `int[<4>]` — with
element-wise operators and methods `.sum()`, `.dot()`. They are translated
directly into SIMD instructions and spare you from assembly in many cases.

## 10. Pitfalls

* `movaps`/`addps [mem]` with an unaligned address — segfault.
* Mixing up `ss`/`ps` — only one element gets processed.
* Reading past the end of the buffer in the tail.
* `pmovmskb` yields 16 bits (32 for ymm) — use a 32-bit register; for ymm
  the mask occupies all 32 bits (sign!), and `tzcnt` on `eax` works
  correctly.
* AVX2 shuffles stay within 128-bit halves.
* Forgotten `vzeroupper`.
* The single-accumulator version is correct but slow.
* Floating-point reductions in a different order give a different
  result — in tests use exactly representable values or a tolerance.

## Self-check questions

1. How many `short` elements fit in a ymm? How many `double`s?
2. How does `movaps` differ from `movups`? And `addps xmm0, [rdi]` from
   `vaddps xmm0, xmm0, [rdi]`?
3. How do you broadcast a float to all 8 lanes of a ymm? And a byte to
   16 lanes of an xmm without AVX2?
4. What does `pmovmskb` return after `pcmpeqb`? How do you find the index
   of the first match from it?
5. Why should the horizontal sum be done outside the loop?
6. Why does the compiler vectorize a sum of `int`s but not a sum of
   `float`s?
7. What is `vzeroupper` for?
8. Why can't `vpshufb ymm` move a byte from the lower half to the upper
   half?
9. Why are multiple accumulators beneficial for reductions?

## Further reading

* Intel® Intrinsics Guide — https://www.intel.com/content/www/us/en/docs/intrinsics-guide/
  (instruction search, with pseudocode).
* Agner Fog, "Optimizing subroutines in assembly language", ch. 13
  "Vectorization"; "Instruction tables".
* https://uops.info — latencies and ports for every vector instruction.
* Denis Bakhvalov, "Performance Analysis and Tuning on Modern CPUs",
  the chapter on vectorization.
* Daniel Lemire's blog: articles on `memchr`, base64, UTF-8 and JSON with
  SIMD; the simdjson project (Langdale & Lemire, "Parsing Gigabytes of
  JSON per Second").
* Wojciech Muła, http://0x80.pl/articles/ — dozens of SIMD algorithms
  (popcount via pshufb, substring search).
* Peter Cordes — Stack Overflow answers on SSE/AVX (horizontal sums,
  vzeroupper) — the best informal documentation.
