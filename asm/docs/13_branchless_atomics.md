# Chapter 13. Branchless code, atomic operations, memory barriers

The two topics of this chapter share one thing: in both, the program's
behavior depends not only on *what* is computed, but also on *how* the
processor executes it — speculatively, out of order, on multiple cores.

Exercises: `a1301`–`a1305`.

## Part 1. Code without branches

### 1. The cost of a branch

A modern processor is a pipeline 15–20 stages deep that keeps hundreds of
instructions in flight at once. When it encounters a conditional jump, it
does not wait for the result of the comparison: the **branch predictor**
guesses the direction, and the processor speculatively keeps executing.
If the guess is right, the branch costs almost nothing. If not, everything
started after the branch is thrown away and the pipeline is refilled:
a penalty of **15–20 cycles** (on Zen 2 / Skylake).

The predictor is very good at regular patterns (loops, "almost always
yes", repeating sequences) and helpless on random data. The classic
demonstration is summing the elements greater than 128 in an array: on a
sorted array the code runs several times faster than on a shuffled one,
even though the instructions are exactly the same.

### 2. Instructions

| Instruction | Action |
|---|---|
| `setCC r/m8` | byte = condition ? 1 : 0 |
| `cmovCC r, r/m` | if condition — `r = src` (16/32/64 bit) |
| `adc`/`sbb` | add/subtract CF — the "condition" as a number |
| `sbb eax, eax` | eax = CF ? -1 : 0 (a mask!) |

The CC conditions are the same as for `jcc`:

| CC | Condition | Flags |
|---|---|---|
| `e`/`z`, `ne`/`nz` | equal / not equal | ZF |
| `l`, `le`, `g`, `ge` | signed <, ≤, >, ≥ | SF, OF, ZF |
| `b`/`c`, `be`, `a`, `ae`/`nc` | unsigned <, ≤, >, ≥ | CF, ZF |
| `s`, `ns` | negative / not | SF |
| `o`, `no` | overflow | OF |
| `p`, `np` | parity (NaN after `ucomisd`) | PF |

Details:

* `setcc` writes **one byte** — zero the register beforehand (`xor eax, eax`
  **before** `cmp`, because `xor` clobbers the flags) or use `movzx`.
* `cmov` does not accept an immediate operand.
* `cmov` with a memory operand **always** reads it — even when the
  condition is false. You cannot replace `p ? *p : 0` with a `cmov` that
  dereferences `p`.
* `cmov` is not a "free" branch: it creates a **data dependency** on both
  inputs and on the flags. If the branch is well predicted, `jcc` is faster:
  the processor doesn't have to wait for the comparison.

### 3. Tricks

```asm
; max(a, b)
mov   rax, rdi
cmp   rdi, rsi
cmovl rax, rsi

; abs(x)
mov   rax, rdi
neg   rax
cmovs rax, rdi        ; if -x < 0, then x > 0 — take x

; sign(x) = (x > 0) - (x < 0)
xor   eax, eax
xor   ecx, ecx
test  rdi, rdi
setg  al
setl  cl
sub   eax, ecx

; count += (a[i] < p)
cmp   [rdi + rcx*4], edx
setl  r8b             ; r8 is zeroed once, outside the loop
add   rax, r8

; branchless mask: m = (x < y) ? -1 : 0  (unsigned)
cmp   rdi, rsi
sbb   rax, rax
```

Arithmetic tricks without flags: `x >> 63` (sar) — the "x is negative" mask;
`(x ^ m) - m` — abs via that mask; `y ^ ((x ^ y) & -(x < y))` — min.

### 4. Branchless algorithms

* **Binary search** with `cmov` (exercise `a1302`) is usually 2–3 times
  faster than the branching version on arrays that fit in cache: every
  iteration is identical, there is nothing to predict. For large arrays,
  a prefetch of both possible next positions is added.
* **Partitioning** in quicksort (branchless Lomuto, "BlockQuicksort").
* **Filtering** an array: write every element at index `j` and do
  `j += condition` — the store is unconditional, only the index moves.
* In SIMD (chapter 10) there are no branches at all — masks and blending.

### 5. What the compiler does

LLVM readily turns `a < b ? b : a` into `cmov`, and `if (x) count++` into
`setcc`+`add`. But it doesn't know your data: sometimes it uses `cmov` where
a branch would be better, and vice versa. GCC: `__builtin_expect_with_probability`,
`__builtin_unpredictable` (Clang). The decision is always made by
measurement (chapter 14), not intuition.

## Part 2. Atomic operations

### 6. Why `count++` doesn't work with multiple threads

`add dword ptr [rdi], 1` is, for the processor, "read, add,
write". Two cores can read the same value, and one of the increments
is lost. It's easy to check: 4 threads doing 200,000 increments each
without `lock` will give not 800,000 but some random smaller number.

### 7. The lock prefix

`lock` makes a read-modify-write operation atomic. The core acquires the
cache line in the exclusive state (M in the MESI protocol) and does not
answer other cores' requests for it until the operation completes
("cache lock"; a bus lock is used only for misaligned operands that
cross lines, and it is **very** expensive — a "split lock").

| Instruction | Atomic operation | C3 (`std::atomic`) |
|---|---|---|
| `lock add/sub/and/or/xor [m], r` | `*p op= v` | `a.add(v)` etc. |
| `lock inc/dec [m]` | `++*p` | |
| `lock xadd [m], r` | `r = fetch_add(p, r)` | `a.add(v)` returns the old value |
| `xchg [m], r` | `r = exchange(p, r)` — `lock` is implicit! | `a.store` (seq_cst) / swap |
| `lock cmpxchg [m], r` | CAS with `rax` as the expected value | `compare_exchange` |
| `lock cmpxchg16b [m]` | 128-bit CAS (`rdx:rax` vs `rcx:rbx`) | pointer + counter |
| `lock bts/btr/btc [m], r` | atomic bit set | |

The cost of an uncontended `lock` instruction is ~10–20 cycles (~8 on Zen 2,
~18 on Skylake). When several cores contend for the same cache line —
hundreds of cycles: the line "ping-pongs" between cores.

### 8. CAS loops

`lock cmpxchg [p], new`: if `[p] == rax`, store `new` and set ZF=1; otherwise
`rax = [p]` and ZF=0. Any operation can be expressed through CAS:

```asm
; atomic_max(p, v)
    mov  rax, [rdi]
retry:
    cmp  rax, rsi
    jge  done                       ; already >= v
    lock cmpxchg [rdi], rsi
    jne  retry                      ; rax was updated with the fresh value
done:
```

Properties and pitfalls:

* **lock-free**: if a CAS fails, it means *another* thread made progress;
* **ABA**: the value goes A → B → A, and CAS won't notice the change. For a
  lock-free stack of pointers this is fatal; it is cured with a version
  counter (`cmpxchg16b`) or memory reclamation schemes (hazard pointers, epochs);
* **false sharing**: two independent variables in the same 64-byte
  cache line behave like one — the cores keep stealing the line from each
  other. Hot atomics are aligned to 64 bytes (`@align(64)` in C3).

### 9. Spinlock

Exercise `a1305`:

```asm
spin_lock:
    mov   eax, 1
    xchg  [rdi], eax          ; atomically: grab it and learn what was there
    test  eax, eax
    jz    acquired
spin:
    pause
    cmp   dword ptr [rdi], 0  ; wait by reading only
    jne   spin
    jmp   spin_lock
acquired:
    ret

spin_unlock:
    mov   dword ptr [rdi], 0  ; a plain store = release on x86
    ret
```

* "test and test-and-set": we wait with a plain read — the cache line is in
  the Shared state for all waiters, no traffic. We attempt `xchg` only after
  seeing 0.
* `pause` is a hint to the processor; without it, exiting the spin loop
  causes a pipeline flush (memory order violation), and the sibling
  hyperthread sits starved.
* Spinlocks are good for very short critical sections. If the lock holder
  is preempted by the scheduler, everyone else spins uselessly for the whole
  time slice — that's why OS mutexes (`futex`) spin a little first and then
  go to sleep in the kernel.

## Part 3. The memory model and barriers

### 10. The x86 memory model (TSO)

The processor and the compiler may reorder memory accesses as long as a
single-threaded program can't notice. A multithreaded one will notice. What
exactly is allowed is described by the **memory model**. x86's is one of the
strictest — Total Store Order:

| Reordering | x86 |
|---|---|
| load → load | forbidden |
| store → store | forbidden |
| load → store (a later store before a read) | forbidden |
| **store → load** (a later read before a store) | **allowed** |
| `lock` instructions and `xchg` | full barrier |

The only permitted reordering is a consequence of the **store buffer**:
the core puts a store into the buffer and moves on, and a load from
another address may execute before the store becomes visible to
other cores. The classic test (Dekker / "store buffering"):

```
thread 1:  x = 1;  r1 = y;        thread 2:  y = 1;  r2 = x;
```

On x86, `r1 == 0 && r2 == 0` is possible — both loads "overtook" the stores. To
forbid that, you need an `mfence` between the store and the load (or any
`lock` instruction, which is usually cheaper).

Consequences for C3/C++ atomics on x86:

| Operation | x86 instruction |
|---|---|
| load (acquire, seq_cst) | plain `mov` |
| store (release) | plain `mov` |
| store (seq_cst) | `xchg` (or `mov` + `mfence`) |
| fetch_add, CAS (any ordering) | `lock xadd`, `lock cmpxchg` |
| fence(acquire/release) | nothing (only a compiler barrier) |
| fence(seq_cst) | `mfence` (or `lock or [rsp], 0`) |

That's why code with ordering bugs often "works" on x86 and breaks on ARM,
where the model is weaker and almost anything can be reordered. But
the **compiler** can reorder even on x86! Atomic operations in the language
are a promise to both the processor and the compiler.

### 11. Barriers

| Instruction | What it orders |
|---|---|
| `mfence` | all loads and stores before/after |
| `sfence` | stores (needed only for non-temporal `movnt*`) |
| `lfence` | loads; in practice — "wait for all previous instructions to complete" (serialization for `rdtsc`, Spectre v1 mitigation) |
| `lock` instructions | full barrier, like `mfence` |

## Pitfalls

* `setcc` without zeroing the upper bits.
* `cmov` from memory through a possibly invalid pointer.
* A non-atomic read-modify-write in multithreaded code.
* `xadd` without `lock` is not atomic (whereas `xchg` is always atomic).
* Tests of multithreaded code that "pass" by chance. A good test should
  fail deterministically (like the single-threaded checks in the exercises)
  or with overwhelming probability.
* Atomic variables in the same cache line as hot data (false sharing).
* "Works on x86" ≠ correct.

## Self-check questions

1. When is `cmov` faster than a conditional jump, and when is it slower?
2. Why must `xor eax, eax` go before `cmp`, and not between `cmp` and `setcc`?
3. How do you count the array elements smaller than a given value without branches?
4. Why is `add [rdi], 1` not atomic? What does the `lock` prefix do?
5. How does `xadd` differ from `add`? Why doesn't `xchg` need `lock`?
6. Describe a CAS loop. What is the ABA problem?
7. Why does a spinlock wait with a plain read rather than `xchg` in a loop? Why `pause`?
8. What is the only memory access reordering that x86 permits?
   How do you forbid it?
9. Why is a spinlock unlock on x86 just a plain `mov`?

## Further reading

* Intel SDM Vol. 3A, sections 8.2 "Memory Ordering" and 8.1 "Locked Atomic Operations".
* Peter Sewell et al., "x86-TSO: A Rigorous and Usable Programmer's Model
  for x86 Multiprocessors".
* Jeff Preshing, the blog preshing.com — a series on lock-free and memory models
  ("Memory Reordering Caught in the Act", "Acquire and Release Semantics").
* Paul E. McKenney, "Is Parallel Programming Hard, And, If So, What Can You Do About It?".
* Mara Bos, "Rust Atomics and Locks" — an excellent explanation of atomics,
  memory models and how locks work, applicable to any language.
* Paul Khuong, "Binary search is a pathological case for caches" and
  "Array layouts for comparison-based searching".
* Agner Fog, "The microarchitecture of Intel, AMD and VIA CPUs" — the sections
  on branch prediction.
* Denis Bakhvalov, "Performance Analysis and Tuning on Modern CPUs", the chapter on
  branch mispredictions.
