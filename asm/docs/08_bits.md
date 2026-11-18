# Chapter 08. Bit Operations

So far we have treated numbers as "numbers". In this chapter we look at them
as **arrays of 64 bits** — and see that x86 can process such arrays as a
whole in a single cycle. Bit tricks are the foundation of hash functions,
bitsets, component masks in an ECS, allocators, compression, chess engines,
spatial structures (Morton codes) and the SIMD code of the following
chapters.

Exercises: `a0801`–`a0805`.

## 1. Logical operations (recap)

| Instruction | Action | Flags |
|---|---|---|
| `and dst, src` | `dst &= src` | ZF/SF/PF from the result, CF=OF=0 |
| `or dst, src` | `dst \|= src` | same |
| `xor dst, src` | `dst ^= src` | same |
| `not dst` | `dst = ~dst` | **does not change** flags |
| `test a, b` | `a & b`, result discarded | like `and` |

`xor eax, eax` is the canonical zeroing idiom: it is shorter than `mov eax, 0`
and the processor recognizes it as a "dependency-breaking" instruction
(register renaming just hands out a fresh zero register; the instruction
never even reaches an ALU).

Reminder: writing a 32-bit register (`eax`) zeroes the upper 32 bits of
`rax`, but writing an 8/16-bit one (`al`, `ax`) does **not** — the old bits
stay.

## 2. Shifts

| Instruction | Action | C3 equivalent |
|---|---|---|
| `shl dst, k` / `sal` | left, zeros shifted in from the right | `x << k` |
| `shr dst, k` | right, zeros shifted in from the left | `x >> k` for unsigned |
| `sar dst, k` | right, copies of the sign bit shifted in from the left | `x >> k` for signed |
| `shld dst, src, k` | shift dst left, vacated bits are taken from src | 128-bit shifts |
| `shrd dst, src, k` | same, to the right | |

The count `k` is an immediate constant or the register **`cl`**, and
nothing else. The hardware masks the count: for 64-bit operands it uses
`k & 63`, for 32-bit ones `k & 31`. So `x << 64` on the hardware is `x`,
not 0. In C3, shifting by the type width or more is an error (a panic in
safe mode) precisely because different processors behave differently
(ARM, for example, gives 0).

`sar` rounds toward minus infinity: `-7 sar 1 = -4`, whereas `-7 / 2 = -3`
in C3. That is why the compiler, when dividing a signed number by 2,
generates a correction:

```asm
; long div2(long x) => x / 2;
mov  rax, rdi
shr  rax, 63        ; rax = 1 if x < 0
add  rax, rdi       ; x + (x < 0)
sar  rax, 1
```

**Flags and a count of 0.** If the count is zero, the flags are not
changed. This means `shl rax, cl` depends on the previous value of the
flags — an extra dependency for the processor, and on Intel such a shift
costs 2–3 uops. BMI2 adds `shlx`/`shrx`/`sarx dst, src, cnt`: count in any
register, flags untouched, one uop. Compilers targeting `-march=haswell`
and above use exactly these.

### Multiplication with shifts and `lea`

Compilers like to replace multiplication by a constant with a combination
of `lea` and shifts:

```asm
lea rax, [rdi + rdi*4]   ; x * 5
lea rax, [rdi + rdi*8]   ; x * 9
lea rax, [rax + rax*4]   ; (x*5)*5 = x * 25
shl rax, 4               ; x * 16
```

`imul` has 3 cycles of latency, a two-component `lea` has 1. Division by a
constant is replaced by the compiler with multiplication by a "magic"
number — we will look at that in chapter 11.

## 3. Rotations

| Instruction | Action |
|---|---|
| `rol dst, k` | rotate left |
| `ror dst, k` | rotate right |
| `rcl`/`rcr` | rotate through the CF flag (65-bit) — slow, rarely needed |
| `rorx dst, src, imm` | BMI2: flagless rotation, into any register |

C3 has no rotate operator, but the idiom `(x << n) | (x >> (64 - n))`
(or `(x << n) | (x >> (-n & 63))`, to avoid a shift by 64) is recognized
by LLVM and turned into `rol`. Rotations are the basis of hashes
(xxHash, wyhash, SipHash) and pseudo-random number generators
(xoshiro256**: `rotl(s1 * 5, 7) * 9`).

`bswap r32/r64` is a related operation: it reverses the order of **bytes**
(little-endian <-> big-endian). You need it when parsing network protocols
and file formats. For 16-bit values use `rol ax, 8`. There is also `movbe` —
a load/store with byte reversal.

## 4. Bit tests

| Instruction | Action |
|---|---|
| `bt  x, i` | CF := bit i |
| `bts x, i` | CF := bit i; bit := 1 |
| `btr x, i` | CF := bit i; bit := 0 |
| `btc x, i` | CF := bit i; bit is inverted |

With a register operand, the index is taken modulo the width. With a memory
operand and a register index, it is a **bit string**: `bt [rdi], rsi`
tests bit `rsi` of the memory starting at `rdi`, arbitrarily far away (the
index is signed — it can even go backwards!). This is convenient, but this
form is microcoded (~10 uops on Intel) — compilers don't use it; instead
they compute `[rdi + (i >> 6)*8]` and `i & 63` by hand and then do `bt` on
a register. The form `lock bts [mem], imm` is an atomic "test-and-set" of a
single bit (chapter 13).

The result lands in the CF flag. To turn it into a number:

```asm
bt    rdi, rsi
setc  al          ; al = CF
movzx eax, al
```

Or use it directly in a jump: `jc bit_is_set`. Or in arithmetic:
`adc rax, 0` adds CF.

## 5. Counting bits

| Instruction | Extension | Result | For 0 |
|---|---|---|---|
| `popcnt d, s` | POPCNT | number of ones | 0 |
| `lzcnt d, s` | ABM/LZCNT | number of leading zeros | width, CF=1 |
| `tzcnt d, s` | BMI1 | number of trailing zeros | width, CF=1 |
| `bsr d, s` | 386 | index of the highest set bit | d undefined, ZF=1 |
| `bsf d, s` | 386 | index of the lowest set bit | d undefined, ZF=1 |

The corresponding functions in C3: `x.popcount()`, `x.clz()`, `x.ctz()` (module `std::bits`,
they return `int`; compiled into these instructions on a suitable target CPU).

Classic uses:

* `floor(log2(x)) = 63 - lzcnt(x)` — the "size class" number in an allocator;
* `next_pow2(x) = 1 << (64 - lzcnt(x - 1))` — hash table size;
* `tzcnt` — "first free slot" in a bitset (after `not`);
* `popcnt` — Hamming distance (`popcnt(a ^ b)`), rank in succinct
  structures (rank/select), number of components in a mask.

### Pitfalls

1. **`tzcnt` = `rep bsf`, `lzcnt` = `rep bsr`.** On a processor without
   BMI1/LZCNT the `rep` prefix is ignored, and the instruction silently
   executes as `bsf`/`bsr` — with a *different* result (an index instead
   of a zero count for `lzcnt`!). Check `cpuid` before using them (on
   Linux the flags are visible in `/proc/cpuinfo`: `popcnt`, `abm`, `bmi1`, `bmi2`).
2. **False dependency.** On Intel Sandy Bridge through Skylake, `popcnt`,
   `lzcnt`, `tzcnt` waited for the previous value of the destination
   register. That is why GCC and Clang emit `xor eax, eax` before
   `popcnt rax, rdi`. More on this in chapter 14 on dependency chains.
3. `bsf`/`bsr` on zero: Intel officially says "undefined"; in practice AMD
   and Intel leave the destination untouched — people rely on this, but
   better not to.

## 6. BMI1 and BMI2

Bit Manipulation Instructions — a set of three-operand (VEX) instructions
that don't clobber their sources:

| Instruction | Formula | Use |
|---|---|---|
| `andn d, a, b` | `~a & b` | clear bits by mask |
| `blsr d, s` | `s & (s - 1)` | clear the lowest set bit |
| `blsi d, s` | `s & -s` | isolate the lowest set bit |
| `blsmsk d, s` | `s ^ (s - 1)` | mask up to and including the lowest set bit |
| `bextr d, s, ctl` | `(s >> start) & ((1<<len)-1)` | bit field (`ctl = start \| len<<8`) |
| `bzhi d, s, n` | `s & ((1<<n)-1)` | zero the bits starting at n |
| `pdep d, s, mask` | deposit bits according to the mask | Morton codes, unpacking |
| `pext d, s, mask` | extract bits according to the mask | packing, bit "gather" |
| `shlx/shrx/sarx` | flagless shifts | |
| `rorx d, s, imm` | flagless rotation | |
| `mulx hi, lo, s` | `rdx * s` → hi:lo without flags | multi-precision arithmetic |

### Iterating over set bits

The most useful technique of the chapter:

```asm
; rdi = mask; for each set bit i ...
    test rdi, rdi
    jz   done
next:
    tzcnt rcx, rdi        ; i = index of the lowest set bit
    ...                   ; process i
    blsr  rdi, rdi        ; drop it; ZF=1 if there are no more
    jnz   next
done:
```

There are as many iterations as there are ones, not 64. This is exactly
how archetypes in an ECS, occupied slots in an object pool, and matches
after a SIMD comparison (`pmovmskb` + `tzcnt` in chapter 10) are iterated.

### pdep/pext

```
pext:  src  = 1 0 1 1 0 1 1 0
       mask = 1 1 0 0 1 0 1 0
       src bits at the positions of mask ones: 1 0 . . 0 . 1 .  → 0b1001 (packed)

pdep:  src  = ....1001
       mask = 1 1 0 0 1 0 1 0
       low bits of src are spread over the ones: 1 0 0 0 0 0 1 0
```

A Morton code (interleaving the bits of x and y) is two `pdep`s:

```asm
mov  ecx, 0x55555555
pdep eax, edi, ecx      ; x → even bits
mov  ecx, 0xAAAAAAAA
pdep edx, esi, ecx      ; y → odd bits
or   eax, edx
```

**Important:** on AMD Zen 1 and Zen 2 (Ryzen 1000–4000, including the
mobile 5x00U parts on Zen 2) `pdep`/`pext` are implemented in microcode and
cost from ~18 to ~300 cycles depending on the number of ones in the mask.
On Intel Haswell+ and AMD Zen 3+ they take 3 cycles. That is why mature
libraries (simdjson, for example) choose the implementation not only by
`cpuid` but also by processor family. A good example of how "the
instruction exists" and "the instruction is fast" are different things;
the tables at uops.info will help.

## 7. What the compiler generates

Try it yourself (`c3c compile -O3 --emit-asm file.c3`, the output goes to
`asm/linux-x64/`):

| C3 | Typical output (`-O3`, x86-64 baseline) |
|---|---|
| `x & (x - 1)` | `lea rax,[rdi-1]; and rax,rdi` (with BMI1 — `blsr`) |
| `(x << 7) \| (x >> 57)` | `rol rax, 7` or the equivalent `shld rax, rax, 7` (that's what LLVM does in c3c) |
| `x.popcount()` | `popcnt` (if the target CPU lacks POPCNT — a long "SWAR" sequence of shifts and masks) |
| `x % 8` (unsigned) | `and eax, 7` |
| `x / 8` (signed) | `lea rax,[rdi+7]; test rdi,rdi; cmovns rax,rdi; sar rax,3` (rounding correction) |
| `(x >> 3) & 0x1F` | `shr` + `and` (with BMI1 sometimes `bextr`) |

Important: the set of instructions available to the compiler is
determined by the target processor. In c3c that's the flag
`--x86cpu=<baseline|ssse3|sse4|avx1|avx2-v1|avx2-v2|avx512|native>`
(in GCC/Clang — `-march=x86-64-v3`, `-march=native`). For example,
`x & (x - 1)` with `--x86cpu=avx2-v2` becomes a single `blsr`. In an
assembly file you are free to use any instruction your processor has —
but then checking `cpuid` is your responsibility.

## 8. Pitfalls

* The shift count can only be `cl`. `shl rax, rsi` does not exist.
* Shifts are modulo the width: "shift by 64" = "don't shift".
* `setcc` writes only an 8-bit register — zero the upper bits
  (`movzx`, or `xor eax, eax` *before* the comparison, otherwise `xor`
  will clobber the flags).
* `bt` with memory and a register is a bit string; it can go beyond the
  "word" (and beyond your array, if the index isn't checked).
* Constants wider than 32 bits cannot be used directly in `and`/
  `or`/`pdep`: load them into a register with `mov rcx, imm64` (in GNU as —
  `movabs rcx, ...` or just `mov rcx, ...`).
* Check extension support: `grep -o -w bmi2 /proc/cpuinfo`.

## Self-check questions

1. How do `shr` and `sar` differ? What do you get from `sar` of -1 by any
   number of bits?
2. Why does `x / 2` for a signed `long` not compile to a single `sar`?
3. What value does `shl rax, cl` give when `cl = 70`?
4. What does `tzcnt` return for zero, and what does `bsf`? Why is it
   dangerous to execute `tzcnt` on a processor without BMI1?
5. How do you iterate over all set bits of a 64-bit mask in a number of
   iterations equal to the number of ones?
6. Write the `next_pow2` formula using `lzcnt`. Where do you need to be careful?
7. What do `pdep` and `pext` do? How can you use them to encode and
   decode a Morton code?
8. Why does the compiler sometimes put `xor eax, eax` before `popcnt rax, rdi`?

## Further reading

* Intel® 64 and IA-32 Architectures Software Developer's Manual, Vol. 2 —
  descriptions of `BT`, `BTS`, `LZCNT`, `TZCNT`, `PDEP`, `PEXT`, `SHLX`.
* Henry S. Warren, *Hacker's Delight* (2nd ed.) — the bible of bit tricks.
* Sean Eron Anderson, *Bit Twiddling Hacks* —
  https://graphics.stanford.edu/~seander/bithacks.html
* Agner Fog, *Instruction tables* — latencies and throughput;
  pay attention to `PDEP`/`PEXT` on Zen 2 and Zen 3.
* https://uops.info — precise measurements for all microarchitectures.
* Daniel Lemire's blog (lemire.me/blog) — many articles on `popcnt`,
  bitsets and bit iteration ("Iterating over set bits quickly").
* Wikipedia: "Z-order curve" — Morton codes.
