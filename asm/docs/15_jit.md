# Chapter 15. Finale: a JIT compiler

A JIT (just-in-time) compiler generates machine code **while the program
is running** and executes it immediately. This is how JavaScript engines
(V8, SpiderMonkey), the JVM, .NET, LuaJIT, PyPy, emulators (Dolphin, QEMU),
regular expressions (PCRE-JIT), databases (query compilation in
PostgreSQL/LLVM), shader compilers in GPU drivers and the scripting
systems of game engines work.

This chapter brings together everything from the track: instruction
encoding (chapters 01–08), the ABI (05–06), system calls and page
permissions (12), calling host code with an aligned stack (05, 09) — and
builds a bridge to the scripting chapter of the engine track.

Exercises: `a1501`–`a1505`.

## 1. The overall scheme

```
source text / bytecode ──► code generator ──► byte buffer
                                                   │ mmap(RW), memcpy
                                                   ▼
                                       RW page ──mprotect──► RX page
                                                                 │
                                                function pointer ──► call
```

1. The **front end** parses the program (in our case it is ready-made bytecode).
2. The **code generator** turns each operation into x86-64 bytes and writes
   them into an ordinary array.
3. The **loader** allocates pages with `mmap(PROT_READ|PROT_WRITE)`, copies
   the code in, and switches the permissions to `PROT_READ|PROT_EXEC` (W^X).
4. The page address is cast to a function type and called:

```c3
alias JitFn = fn long(long);
JitFn f = (JitFn)code;
long r = f(42);
```

## 2. x86-64 instruction encoding

```
[prefixes] [REX] [opcode 1–3 bytes] [ModRM] [SIB] [disp 0/1/4] [imm 0/1/2/4/8]
```

### REX

`0100 W R X B`:

| Bit | Meaning |
|---|---|
| W | 64-bit operand (`0x48`) |
| R | 4th bit of the ModRM.reg field |
| X | 4th bit of SIB.index |
| B | 4th bit of ModRM.rm / SIB.base / a register encoded in the opcode |

Registers `r8`–`r15` are numbered 8–15; the low 3 bits go into ModRM and
the 4th bit goes into REX. That is why `push r12` = `41 54` (REX.B + `50+4`),
while `push rsp` = `54`.

### ModRM and SIB

`ModRM = mod(2) | reg(3) | rm(3)`:

| mod | Meaning of rm |
|---|---|
| 11 | register |
| 00 | `[rm]` (rm=101 → `[rip + disp32]`, rm=100 → SIB) |
| 01 | `[rm + disp8]` |
| 10 | `[rm + disp32]` |

`SIB = scale(2) | index(3) | base(3)`, scale 00/01/10/11 = ×1/2/4/8.
Special cases: `rsp`/`r12` as a base require a SIB byte; `rbp`/`r13` as a
base with no displacement require `mod=01` with `disp8 = 0`.

The `reg` field either names a second register or — for "group" opcodes —
extends the opcode (`/digit` in the documentation): `F7 /3` = `neg`,
`F7 /2` = `not`, `FF /2` = `call r/m`, `FF /6` = `push r/m`.

### Examples

| Instruction | Bytes | Breakdown |
|---|---|---|
| `ret` | `C3` | |
| `mov eax, 42` | `B8 2A 00 00 00` | `B8+r`, imm32 |
| `mov rax, imm64` | `48 B8 imm64` | REX.W, `B8+r`, imm64 |
| `mov r11, imm64` | `49 BB imm64` | REX.W+B, `B8+3` |
| `add rax, rcx` | `48 01 C8` | `01 /r`: reg=rcx(1), rm=rax(0) |
| `add r10, rdx` | `49 01 D2` | REX.W+B, reg=rdx(2), rm=r10(2) |
| `imul rax, rcx` | `48 0F AF C1` | `0F AF /r`: reg=rax — the destination! |
| `lea rax, [rdi+rsi]` | `48 8D 04 37` | mod=00 rm=100 → SIB(1, rsi, rdi) |
| `push qword [rbp-8]` | `FF 75 F8` | `FF /6`, mod=01 rm=101, disp8=-8 |
| `pop qword [rbp-16]` | `8F 45 F0` | `8F /0` |
| `cmp rax, rcx` | `48 39 C8` | |
| `setl al` | `0F 9C C0` | |
| `jz rel32` | `0F 84 rel32` | |
| `jmp rel32` | `E9 rel32` | |
| `call rax` | `FF D0` | `FF /2`, mod=11 |
| `leave` | `C9` | `mov rsp, rbp; pop rbp` |

How to check yourself — ask the assembler:

```
echo 'imul r12, rbx' | as -msyntax=intel -mnaked-reg -o /tmp/x.o && objdump -d -M intel /tmp/x.o
```

In `a1503` the same idea is automated: the reference instructions are
assembled by GNU as in `ref.s`, and the driver compares your emitter's
bytes against them.

### Relative jumps

`jmp`/`jcc`/`call` with `rel8`/`rel32` jump to the address of the
**end of the instruction** + the offset. For a forward jump the target
address is not known yet — we write a placeholder and remember where to
come back to (a "fixup"), and after code generation we fill it in
(backpatching). Assemblers and linkers work the same way (relocations
are the same patches, just stored in a file).

## 3. Code generation for a stack machine

The simplest scheme is **bytecode stack = machine stack**:

| Bytecode | Machine code |
|---|---|
| `CONST k` | `mov rax, k; push rax` |
| `ARG` | `push rdi` (or from the frame) |
| `ADD` | `pop rcx; pop rax; add rax, rcx; push rax` |
| `LT` | `pop rcx; pop rax; cmp rax, rcx; setl al; movzx eax, al; push rax` |
| `JZ t` | `pop rax; test rax, rax; jz rel32` |
| `LOAD i` | `push qword [rbp - 16 - 8i]` |
| `RET` | `pop rax; leave; ret` |

This is a "template" JIT: every operation is a fixed chunk of code. It is
already 3–10 times faster than an interpreter, because dispatch (a
`switch` or an indirect jump per operation), operand decoding and
accesses to the stack array all disappear. Early JITs (the first
versions of V8, "baseline" compilers) are built exactly like this.

The next steps — each one gives a multiplicative speedup:

* **Top-of-stack caching** (TOS caching): keep the top of the stack in
  `rax`, so that `CONST; ADD` → `add rax, imm`.
* **Register allocation**: translate the stack code into a form with
  virtual registers (SSA) and assign physical registers to them —
  linear scan is fast and gives good results.
* **Constant folding and peephole optimizations** over a window of a few
  instructions.
* **Type specialization** (for dynamic languages): inline caches,
  traces (LuaJIT, TraceMonkey), deoptimization when assumptions are violated.
* Tiering: interpreter → fast baseline JIT → optimizing JIT for "hot"
  functions (V8: Ignition → Sparkplug → Maglev → TurboFan).

## 4. Calling host code from generated code

A script needs engine functions: "deal damage", "find the nearest enemy",
"play a sound". From JIT code this is an ordinary System V ABI call:

```asm
pop  rdi                ; argument
mov  rax, rsp
and  rsp, -16           ; align the stack to 16 before call
push rax                ; save the old rsp (twice — so that rsp
push rax                ; stays a multiple of 16)
mov  rax, <host function address>
call rax
pop  rsp                ; restore rsp
push rax                ; result
```

Important:

* alignment is mandatory: the host function may use `movaps` on the
  stack (chapter 09);
* all caller-saved registers (`rax, rcx, rdx, rsi, rdi, r8–r11`, all xmm)
  are clobbered after the call — keep live values in the frame or in
  callee-saved registers;
* `call rel32` to a host function only works if it is within ±2 GiB of
  the JIT code — `mmap` gives no such guarantee, so people use
  `mov rax, imm64; call rax` or an address table;
* if the JIT code itself uses callee-saved registers (`rbx`, `r12`–`r15`),
  it must save them in the prologue.

## 5. Security and operations

* **W^X**: a page is never writable and executable at the same time.
  Otherwise a memory-write vulnerability turns into arbitrary code
  execution. On macOS (Apple Silicon) this is enforced in hardware
  (`MAP_JIT`, `pthread_jit_write_protect_np`); on SELinux — by the
  `execmem` policy.
* **Dual mapping**: the same physical memory is mapped twice — at one
  address as RW (for writing), at another as RX (for execution), via
  `memfd_create` + two `mmap` calls. This lets the JIT append code
  without switching permissions.
* **Instruction cache**: on x86 nothing needs to be done after writing
  code — the processor tracks self-modification (expensive if you write
  to a page that is currently executing!). On ARM, flushing the
  instruction cache is mandatory.
* **Debugging**: gdb and perf know nothing about generated code. For perf
  there is the `/tmp/perf-<pid>.map` convention (address, size, name); for
  gdb, the JIT interface `__jit_debug_register_code`. For simple cases,
  dump the buffer to a file and disassemble it:
  `objdump -D -b binary -m i386:x86-64 -M intel code.bin`.
* **Limits and validation**: bytecode from an untrusted source is
  validated before compilation (stack correctness, local variable
  bounds, valid jump targets); otherwise the JIT will generate arbitrary
  machine code at an attacker's direction.

## 6. A bridge to the engine track

In the scripting chapter of the `engine/` track you will design a game's
scripting system. The decisions you will have to make there are now
understandable "from the inside":

* a bytecode interpreter — portable, simple, safe, slower;
* a JIT — fast, but platform-dependent and forbidden on some platforms
  (iOS, consoles — you cannot allocate executable memory);
* AOT compilation of scripts to native code at game build time (for
  example, translation to C3 or C) — a compromise many engines choose;
* the "script ↔ engine" boundary (host calls) — the place where
  performance is lost and where a clear ABI is needed.

## Self-check questions

1. What parts does an x86-64 instruction consist of? What are REX.W, REX.R, REX.B?
2. Encode `add rbx, r14` and `imul r12, rbx` by hand. Why is the destination
   of these two instructions in different ModRM fields?
3. Why do `push rsp` and `push r12` differ by one REX byte?
4. From which address is the `rel32` in `jmp` measured? How do you
   generate a forward jump when the target address is not yet known?
5. Why is `mprotect` needed after writing the code? What is W^X?
6. How do you correctly call a C3 function from JIT code when the stack
   depth at that moment is arbitrary?
7. Why is a template JIT faster than an interpreter? What does register
   allocation add on top of that?
8. How do you view the generated code in a disassembler?

## Further reading

* Intel SDM Vol. 2, ch. 2 "Instruction Format" and Appendix A (opcode
  tables); https://www.felixcloutier.com/x86/ — a convenient HTML version.
* https://wiki.osdev.org/X86-64_Instruction_Encoding — a concise
  encoding reference.
* Eli Bendersky, "How to JIT — an introduction" and the series "Adventures
  in JIT compilation" (eli.thegreenplace.net).
* Robert Nystrom, "Crafting Interpreters" (craftinginterpreters.com) —
  bytecode, stack VMs; the natural continuation of this chapter.
* Mike Pall, notes on LuaJIT (luajit.org) and the DynASM sources — an
  emitter embedded in C code.
* The V8 blog (v8.dev/blog): "Sparkplug — a non-optimizing JavaScript compiler".
* Massimiliano Poletto, Vivek Sarkar, "Linear Scan Register Allocation".
* Josh Haberman, "Parsing Protobuf at 2+GB/s: How I Learned To Love Tail
  Calls in C" — when an interpreter almost catches up with a JIT.
