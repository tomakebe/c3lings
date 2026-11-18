# Chapter 11. C3 inline assembly and reading compiler output

Writing whole functions in `.s` files is a good way to learn, but in
real projects assembly more often shows up in two other forms:

1. **Inline assembly** — a few instructions right inside a function
   written in a high-level language: access to an instruction the language
   "can't reach" (`rdtsc`, `cpuid`, `crc32`, `pdep`), or a guarantee of a
   specific instruction sequence.
2. **Reading compiler output** — a far more common task. To understand
   why code is slow, whether a loop got vectorized, whether the compiler
   removed a bounds check, you open a disassembler. You rarely have to
   write assembly, but you read it all the time.

Exercises: `a1101`–`a1105`. In this chapter you edit `.c3` files.

## 1. Two kinds of `asm` in C3

### String

```c3
asm("nop");
```

The string is passed to LLVM unchanged, as a "module-level" insertion
inside the function. The compiler does not know which registers it reads
and clobbers, so it is only suitable for instructions with no operands
and no side effects on registers: `nop`, `pause`, `int3`. The syntax is
AT&T (the LLVM default).

### Block

```c3
fn int add(int a, int b)
{
    int r;
    asm
    {
        movl r, a;      // r = a
        addl r, b;      // r += b
    }
    return r;
}
```

A block is assembly the compiler "understands". c3c parses each
instruction, looks it up in a table (which operands are read, which are
written, what gets clobbered) and generates LLVM inline asm with the
correct constraints — what in GCC you would write by hand
(`"=r"(r) : "r"(a), "0"(b) : "cc"`), and where it is so easy to make a
mistake.

Block syntax rules:

| Rule | Example |
|---|---|
| mnemonic with an AT&T size suffix: `b`/`w`/`l`/`q` | `movl`, `addq`, `xaddl` |
| some instructions have no suffix; size comes from the operands | `popcnt r, x;`, `tzcnt`, `pdep`, `crc32` |
| **Intel** operand order: destination first | `subq r, b;` → r -= b |
| registers with `$` | `$eax`, `$rdx`, `$xmm0` |
| C3 variables by name | `movq $rax, a;` |
| memory through a pointer variable | `[p]`, `[p + 8]`, `[p + i * 4 + 4]` |
| address of a variable | `&x` |
| a parenthesized expression is evaluated before the block | `movl $eax, (a + 1);` |
| variable size = instruction size | `movl` + `ulong` → error |
| every instruction ends with `;` | |

### Supported instructions

The full list for the current target is printed by

```
c3c compile --list-asm file.c3
```

(with "clobbers" columns and an argument template: `rw:` — read and
written, `w:` — written only). In c3c 0.8.5 for x86-64 it is roughly:

* moves: `movb/w/l/q`, `movzbl`, `movsbq`, `movslq`, …, `xchg*`, `push*`, `pop*`;
* arithmetic: `add*`, `adc*`, `sub*`, `inc*`, `dec*`, `neg*`, `mul*`,
  `div*`, `idiv*`, `mulx`, `adcx`, `adox`;
* logic: `or*`, `xor*`, `not*`, `andn`, BMI (`blsi`, `blsr`, `blsmsk`,
  `bextr`, `bzhi`, `pdep`, `pext`, `shlx`, `shrx`, `sarx`, `rorx`);
* bit counting: `popcnt`, `lzcnt`, `tzcnt`; `bswapl`/`bswapq`;
* atomics: `xadd*`, `cmpxchg*`, `cmpxchg8b`, `cmpxchg16b`;
* `cmova*`, `cmovae*`, `cmovb*`, `cmovbe*` (unsigned conditions only);
* system: `cpuid`, `rdtsc`, `rdtscp`, `rdrand`, `rdseed`, `xgetbv`,
  `syscall`, `clflush`, `int3`, `hlt`, `nop`;
* a bit of SSE/AVX: `addss/sd/ps/pd`, `vadd*`, `crc32`, `pclmulqdq`, AES, SHA;
  `vzeroupper`, `vzeroall`.

**Missing**: `and`, `shl`/`shr`/`sar`, `rol`, `imul`, `cmp`, `test`, `lea`,
`setcc`, jumps, the `lock` prefix, the `mfence`/`pause` barriers. The
manual honestly warns: inline assembly is a "work in progress". In
practice this is not a big deal: C3 expresses everything listed above
perfectly well on its own, and only what the language lacks goes into a
block.

### Rough edges found (c3c 0.8.5)

Reading the `--list-asm` table is also useful for catching bugs in the
compiler itself:

* `cmov*` are described as `w:r32, r32/mem` — the destination is "written
  only". But `cmov` writes the destination *conditionally*: if the
  condition is false, the old value remains, i.e. the destination is also
  **read**. Because of this, at `-O3` the compiler is entitled not to load
  the variable's initial value into the register — and the result becomes
  garbage. See for yourself:

  ```c3
  fn uint umax(uint a, uint b) { uint r = a; asm { movl $eax, a; subl $eax, b; cmovbl r, b; } return r; }
  ```

  in the `-O3` output, `cmovb ecx, esi` writes to `ecx`, into which nobody
  ever put `a`. Use `cmov` in blocks only with explicit initialization
  inside the block via a fixed register, or better yet, write
  `a < b ? b : a` and trust the compiler.
* `cmpxchgl` is described with 16-bit operands, so `cmpxchgl [p], x`
  with `int x` does not compile.
* There is no `lock`: `xaddl [p], v` in a block is **not atomic**. Only
  `xchg` with memory is atomic — it always implies `lock`. For atomics
  use `std::atomic` (chapter 13) or a `.s` file.

If you need something outside this subset, write the function in a
`.s` file and call it via `extern fn`, as in chapters 00–10. That is
more portable and easier to debug.

## 2. Fixed registers

`mul`, `div`, `rdtsc`, `cpuid`, `syscall` work with specific registers.
In a block this is expressed with explicit moves:

```c3
fn ulong muldiv(ulong a, ulong b, ulong c)
{
    ulong q;
    asm
    {
        movq $rax, a;
        mulq b;          // rdx:rax = rax * b
        divq c;          // rax = rdx:rax / c
        movq q, $rax;
    }
    return q;
}
```

The compiler sees that `mulq` clobbers `rax` and `rdx` and will not place
your variables there. Compare with GCC syntax, where you would have to
write this yourself: `asm("mulq %2; divq %3" : "=a"(q) : "a"(a), "r"(b), "r"(c) : "rdx", "cc");`.

## 3. How to get compiler output

```
c3c compile -O3 --emit-asm main.c3      # files in ./asm/linux-x64/<module>.s
c3c compile -O3 --emit-llvm main.c3     # LLVM IR — the intermediate level
objdump -d -M intel --no-show-raw-insn ./main | less   # disassembler for the finished binary
```

* `--emit-asm` produces **AT&T syntax** (`movl %edi, %eax` — source
  first, registers with `%`, constants with `$`, size suffixes). You need
  to be able to read it: GCC/Clang emit it by default, and so does `gdb`.
* Function names are `module.function` (`main.add`); you can set your own
  via `@export("name")`.
* Between `#APP` and `#NO_APP` is your inline assembly.
* `.loc`, `.cfi_*`, `#DEBUG_VALUE` lines are debug info; your eyes can
  skip them.
* Compiler Explorer (godbolt.org) supports C3 — the most convenient way
  to view the output interactively.
* `objdump -M intel` converts to Intel syntax; `-S` interleaves it with
  the source (if debug info is present).

### Translating AT&T ↔ Intel

| AT&T | Intel |
|---|---|
| `movl %edi, %eax` | `mov eax, edi` |
| `movl $5, %eax` | `mov eax, 5` |
| `movq 8(%rdi,%rcx,4), %rax` | `mov rax, [rdi + rcx*4 + 8]` |
| `leal (%rdi,%rdi,8), %eax` | `lea eax, [rdi + rdi*8]` |
| `imulq %rcx, %rax` | `imul rax, rcx` |
| `cmpq %rsi, %rdi; jl` | `cmp rdi, rsi; jl` (!) |
| `movzbl (%rdi), %eax` | `movzx eax, byte ptr [rdi]` |
| `cltq` / `cqto` | `cdqe` / `cqo` |
| `vfmadd231ps %ymm2, %ymm1, %ymm0` | `vfmadd231ps ymm0, ymm1, ymm2` |

Note `cmp`: in AT&T the operands are swapped, so
`cmpq %rsi, %rdi; jl` means "if rdi < rsi".

## 4. -O0 versus -O3

The function `fn int m3(int x, int y) => x * 9 + y * 4 - 7;`

`-O0` (Intel syntax):

```asm
m3:
    push rbp
    mov  rbp, rsp
    mov  dword ptr [rbp - 4], edi     ; arguments are saved to the stack
    mov  dword ptr [rbp - 8], esi
    imul eax, dword ptr [rbp - 4], 9  ; and read back
    mov  ecx, dword ptr [rbp - 8]
    shl  ecx, 2
    add  eax, ecx
    sub  eax, 7
    pop  rbp
    ret
```

`-O3`:

```asm
m3:
    lea eax, [rdi + rdi*8]       ; x*9
    lea eax, [rax + rsi*4]       ; + y*4
    add eax, -7
    ret
```

What we see:

* at `-O0` every variable lives in memory (the debugger needs this — you
  can change its value in gdb), with a stack frame through `rbp`;
* at `-O3` — registers only, no frame, multiplication replaced by `lea`;
* `-O0` is an honest "line by line" translation; `-O3` computes the same
  result by any means available.

In c3c, the `-O0`/`-O1` levels are "safe" (bounds checks, shift overflow,
alignment, contracts), and `-O2` and above have no checks. So when
comparing C3 code with C code, keep in mind that in "safe" mode you will
see comparisons and panic calls. (Incidentally, it is exactly the
alignment check that would have caught the `ulong*` dereference at an
odd address in `a1104` — for unaligned reads C3 has
`mem::load(ptr, align)`.)

## 5. Typical optimizer patterns

| Source | What you will see | Why |
|---|---|---|
| `x / 10` (uint) | `mov eax, 0xCCCCCCCD; imul rax, rcx; shr rax, 35` | division is ~25–40 cycles, multiplication 3 |
| `x % 10` | quotient × 10 via two `lea`s, then `sub` | |
| `x / 4` (int) | `lea eax,[rdi+3]; test edi,edi; cmovns eax,edi; sar eax,2` | `sar` rounds down, C3 rounds toward zero |
| `x * 9`, `x * 5` | `lea eax, [rdi + rdi*8]` | `lea` is 1 cycle |
| `x < 0 ? -x : x` | `mov eax,edi; neg eax; cmovs eax,edi` | branchless |
| `a < b` (bool) | `cmp; setl al` | |
| `return f(x);` | `jmp f` | tail call |
| int sum loop | `vpaddd` ×4, unrolling, tail | auto-vectorization (chapter 10) |
| `memset`/zeroing an array | `rep stosb`, a call to `memset`, or `vmovups` | |
| `switch` with dense labels | `jmp [rip + table + rax*8]` | jump table |
| unused result | nothing | dead code elimination |

Magic numbers for division: `x / d = (x * M) >> s`, where
`M = ceil(2^s / d)` is chosen so that the result is exact for all
32-bit `x`. For `d = 10`: `2^35 / 10 = 3435973836.8`, `M = 3435973837 =
0xCCCCCCCD`. For details see Hacker's Delight, ch. 10, and libdivide.

### More signs worth looking for

* a `call` inside a hot loop — the function was not inlined;
* `ud2`/a panic call after a comparison — a bounds check (in safe mode);
* `movaps [rsp + ...]` in the prologue — saving vector registers;
* `vzeroupper` before `ret` — the function touched ymm;
* lots of `mov`s to/from the stack inside a loop — register shortage (spilling);
* `cmov` instead of `jcc` — the compiler decided the branch is
  unpredictable or cheap (chapter 13).

## 6. When inline assembly is a bad idea

* The compiler cannot optimize across an `asm` block: it will not reorder,
  vectorize, or constant-fold through it. A short function with `asm` can
  end up slower than its C3 equivalent.
* Inline assembly is not portable (x86 vs ARM) — you need a pure C3
  version for other platforms (`$if env::X86_64:` … `$else` … `$endif`).
* For most "special" instructions C3 already has built-in functions:
  `x.popcount()`, `x.clz()`, `x.ctz()`, `$$sysclock()` (rdtsc),
  `$$prefetch`, `$$fma`, the `std::atomic` atomics, `float[<8>]` vectors.
  They are visible to the optimizer — reach for them first.

## Self-check questions

1. How does `asm("...")` differ from `asm { ... }` from the compiler's point of view?
2. In what order are operands written in a C3 `asm` block? And in the AT&T
   output of `--emit-asm`?
3. Why does `movl r, x;` not compile if `x` is a `ulong`?
4. How do you call `rdtsc` in an `asm` block and get a 64-bit result?
5. Why is `xaddl [p], v` in a C3 `asm` block not atomic, while `xchgl [p], v` is?
6. What is wrong with the description of `cmov*` in the `--list-asm` table,
   and what can that lead to at `-O3`?
7. How do you recognize division by 10 in assembly? Signed division by 4?
8. Why do all variables live on the stack at `-O0`?

## Further reading

* C3 manual, "Inline Assembly" section (`./.c3c/c3/MANUAL.md`, 10_1).
* Matt Godbolt, "What Has My Compiler Done for Me Lately?" (CppCon 2017) and
  Compiler Explorer itself — https://godbolt.org.
* GCC manual, "Extended Asm" — to appreciate how much work c3c does for
  you; LLVM LangRef, "Inline Assembler Expressions".
* Henry S. Warren, *Hacker's Delight*, ch. 10 "Integer Division by Constants".
* Agner Fog, "Optimizing software in C++", the chapter on what optimizers
  can do; "Optimizing subroutines in assembly language", ch. 3 (inline asm).
* Denis Bakhvalov, "Performance Analysis and Tuning on Modern CPUs" —
  techniques for reading assembly while profiling.
