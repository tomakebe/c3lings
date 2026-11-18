# Chapter 14. Performance: the pipeline, dependencies, cache, measurement

We know how to write correct assembly. This chapter is about why two
correct versions can differ in speed by a factor of 10, and how to
measure it without fooling yourself. You need this knowledge not to write
everything in assembly (you almost never should), but to understand what
the processor does with your C3 code — and why.

Exercises: `a1401`–`a1405`. They check correctness only: timing depends
on the machine and its load, so it is not part of the expected output.
Measuring is your own homework (section 8).

## 1. How an instruction executes

A modern x86 core (Zen, Golden Cove) looks roughly like this:

```
 frontend                          backend (out-of-order)
 ┌───────────┐  ┌───────────┐  ┌──────────────┐  ┌──────────────────────┐
 │ branch    │→ │ fetch and │→ │ register     │→ │ scheduler → ports:   │
 │ predictor │  │ decoder / │  │ renaming,    │  │ ALU ×4, AGU/LOAD ×3, │
 │           │  │ uop cache │  │ ROB (~250)   │  │ STORE ×2, FP/SIMD ×4 │
 └───────────┘  └───────────┘  └──────────────┘  └──────────────────────┘
                 4–6 µops/cycle                      in-order retirement
```

* Instructions are split into **micro-operations** (µops). Most simple
  instructions are 1 µop; `div` is dozens; "microcoded" ones (`rep movsb`
  on short strings, `pdep` on Zen 2) are even more.
* **Out-of-order execution**: a µop executes as soon as its operands are
  ready and a port is free, not in program order. The reorder buffer
  (ROB) holds ~200–500 µops "in flight".
* **Register renaming**: `rax` in neighbouring independent computations
  maps to different physical registers. False dependencies disappear.
  Zeroing idioms (`xor eax, eax`) and `mov reg, reg` are often executed
  right in the renamer, without a port (move elimination).
* **Speculation**: after a predicted branch, execution continues; on a
  mispredict, it rolls back (15–20 cycles).

## 2. Latency and throughput

Two numbers matter for every instruction:

* **latency** — how many cycles until the result can be used by the
  next dependent instruction;
* **reciprocal throughput** — how often *independent* instructions of
  that kind can be issued.

| Instruction | Latency | Throughput (cycles/instr) |
|---|---|---|
| `add`, `and`, `lea` (simple) | 1 | 0.25 |
| `imul r64, r64` | 3 | 1 |
| `div r64` | 13–45 (depends on CPU and values) | 13–40 |
| load from L1 | 4–5 | 0.33–0.5 |
| `addsd`/`vaddps` | 3–4 | 0.5 |
| `vfmadd231ps` | 4–5 | 0.5 |
| `sqrtsd` | 13–20 | 4–6 |
| `divsd` | 13–15 | 4–5 |
| `pdep` (Intel / Zen 3) | 3 | 1 |
| `pdep` (Zen 2) | ~18–300 | — |
| `lock xadd` | ~10–20 | ~10–20 |

(Orders of magnitude for modern CPUs; for exact data see Agner Fog's
"Instruction tables" and uops.info.)

A loop's speed is limited by its **bottleneck**:

1. A **dependency chain** carried across iterations (loop-carried
   dependency): `sum += a[i]` — each iteration waits for the previous
   `sum`. Time ≥ chain length × latency.
2. Port **throughput**: if the loop has 8 loads and there are 2–3 load
   ports, an iteration can't be faster than 3–4 cycles.
3. The **frontend**: no more than 4–6 µops per cycle enter the backend.
4. **Memory**: if the data isn't in cache, nothing else matters.

### Multiple accumulators

```asm
; 1 accumulator: 1 cycle/element (add latency)     ; 4 accumulators: ~0.33–0.5 cycles/element
1:  add rax, [rdi + rcx*8]                         1:  add rax, [rdi + rcx*8]
    inc rcx                                            add r8,  [rdi + rcx*8 + 8]
    cmp rcx, rsi                                       add r9,  [rdi + rcx*8 + 16]
    jl  1b                                             add r10, [rdi + rcx*8 + 24]
                                                       add rcx, 4
                                                       cmp rcx, rdx
                                                       jl  1b
```

For floating point the effect is stronger: `vaddps` has 3 cycles of
latency with two issues per cycle, so you need **6–8 independent
accumulators** to fully saturate the FP units. This is Little's law:
*parallelism = latency × throughput*.

### Loop unrolling

Unrolling reduces loop overhead (`inc`/`cmp`/`jl` per N elements instead
of per one) and opens the door to multiple accumulators. But it has a
cost: more code (pressure on the uop cache and L1i), more tail handling.
Compilers typically unroll by 2–4. A `cmp`+`jcc` pair fuses into a single
µop (macro-fusion) — so loop bookkeeping instructions are cheaper than
they look.

## 3. The memory hierarchy

| Level | Size (typical) | Latency | Throughput |
|---|---|---|---|
| registers | — | 0 | — |
| L1d | 32–48 KiB per core | 4–5 cycles | 2–3 loads/cycle |
| L2 | 512 KiB–2 MiB per core | 12–15 cycles | ~1 line/cycle |
| L3 | 8–64 MiB shared | 40–50 cycles | |
| DRAM | gigabytes | 80–120 ns (~300+ cycles) | 20–50 GB/s |

Key concepts:

* A **cache line** is 64 bytes. Memory is read only in whole lines. Read
  one byte — pay for 64. So dense data packing and sequential access are
  what matter most. This is the foundation of data-oriented design and
  ECS in engines: array of structs vs struct of arrays.
* The **hardware prefetcher** recognizes sequential and strided access
  and fetches lines ahead of time. It cannot predict random access
  (linked lists, hash tables, trees).
* **Software prefetch**: `prefetcht0 [addr]` (into all levels),
  `prefetcht1/t2`, `prefetchnta` (with minimal cache pollution). Useful
  when the address is known in advance but the prefetcher won't guess it
  (tree traversal, binary search, "jumping" through indices). The
  prefetch distance is tuned by measurement: ~100–300 cycles ahead.
* **TLB**: virtual address translation is cached (L1 dTLB ~64 entries,
  L2 ~2000). Memory access scattered across many pages misses the TLB —
  "huge pages" (2 MiB) help.
* **Associativity and 4K aliasing**: addresses that differ by a multiple
  of 4096 land in the same cache set. Transposing a 1024×1024 int matrix
  column-by-column is a pathological case (exercise `a1405` solves it
  with blocking).
* **Alignment**: an access that crosses a cache line boundary (split
  load) costs more; one that crosses a page boundary costs much more.
  `vmovdqa` requires alignment, `vmovdqu` doesn't, but it still benefits
  from aligned data (exercise `a1404`).
* **Non-temporal stores** (`movnti`, `vmovntdq`) bypass the cache — for
  large buffers that won't be read again soon (filling a framebuffer,
  large memsets). Follow them with `sfence`.

## 4. Branch prediction

A recap of chapter 13: a mispredict costs 15–20 cycles. Simple rules:

* make branches predictable (sort the data, separate the "hot" and
  "cold" paths);
* for unpredictable conditions use `cmov`/`setcc`/SIMD masks;
* indirect branches (`switch`, virtual calls, bytecode interpreters)
  also have a predictor, but it is weaker; "threaded code" in
  interpreters (a jump at the end of every handler) predicts better than
  a single shared `switch` — and the JIT in chapter 15 gets rid of this
  entirely.

## 5. What else matters

* **False dependencies**: writing to an 8/16-bit part of a register
  (`mov al, ...`) merges with the old value; `popcnt`/`lzcnt` on older
  Intel waited on the destination; `cvtsi2sd` on the upper bits of the
  xmm. Break them with `xor`.
* **Store forwarding**: a read of a just-written address is served from
  the store buffer (~4–5 cycles). If the read is wider than the write or
  misaligned relative to it — a "store forwarding stall", ~10–15 cycles.
* **Denormal floats** — microcode, dozens of times slower.
* **Code alignment**: hot loops are sometimes aligned to 32/64 bytes
  (`.p2align 5`) so they fit in fewer uop cache lines. The effect is
  small and unstable — measure.
* **Frequency**: heavy AVX2/AVX-512 code lowered the core frequency on
  some Intel CPUs; turbo boost depends on temperature and the number of
  active cores.

## 6. Measurement

Rules for honest measurement:

1. Measure an **optimized** build (`-O3`) — measuring `-O0` is pointless.
2. **Warm-up**: the first pass runs with cold caches, TLB and predictor;
   memory pages are not yet allocated (page faults).
3. **Repetitions**: take the minimum or median of many runs; look at the
   spread.
4. **Don't let the compiler throw the work away**: the result must "leak"
   (printing, `volatile`, an `asm` barrier), otherwise the loop vanishes.
5. **Data size**: 10 KiB (L1), 1 MiB (L2/L3) and 1 GiB (DRAM) are three
   different problems. Write it down next to the result.
6. Pin the frequency (`cpupower frequency-set -g performance`), pin the
   thread to a core (`taskset -c 2`).

### rdtsc

```asm
    lfence          ; everything before has completed
    rdtsc           ; edx:eax = TSC
    shl  rdx, 32
    or   rax, rdx
    ; ... code being measured ...
    rdtscp          ; waits for preceding instructions to complete
    lfence          ; and doesn't let subsequent ones start early
```

On modern CPUs the TSC ticks at a constant ("nominal") frequency,
independent of turbo and power saving — it is a clock, not core cycles.
In C3 it is `$$sysclock()`; for time, use `std::time` (`clock::now()`).

### perf

Linux `perf` reads the hardware performance counters (PMU):

```
perf stat ./prog                      # cycles, instructions, IPC, branch misses
perf stat -e cycles,instructions,branch-misses,cache-misses,L1-dcache-load-misses ./prog
perf record -g ./prog && perf report  # where the time goes (with call graph)
perf annotate                         # hot instructions in the disassembly
```

Key metrics:

* **IPC** (instructions per cycle): < 1 — something is waiting (memory,
  mispredicts), 2–4 — the code keeps the core busy;
* **branch-misses** per thousand instructions;
* **cache-misses**, L1/LLC misses;
* the **Top-Down** method (Intel, Yasin): the share of cycles that are
  frontend bound / backend bound (memory / core) / bad speculation /
  retiring — `perf stat --topdown` or `toplev`.

### Static analysis

* **llvm-mca** — simulates a block of instructions on a model of a
  specific CPU and shows the bottleneck: `llvm-mca -mcpu=znver2 loop.s`.
* **uiCA** (uops.info) — the same for Intel, very accurate.
* Compiler Explorer can show llvm-mca output right next to the code.

## 7. Optimization checklist

1. The right algorithm and data structure (big-O still applies).
2. Data layout: sequential access, dense packing, SoA for hot fields,
   no pointer chasing.
3. Remove unnecessary work from the hot loop (hoist invariants, don't
   allocate).
4. Break dependency chains (multiple accumulators).
5. Vectorize (chapter 10) — or help the compiler do it.
6. Remove unpredictable branches (chapter 13).
7. Multithreading — last, and watch out for false sharing.

Take each step **only after a measurement** shows that this exact thing
is the bottleneck.

## Self-check questions

1. How does an instruction's latency differ from its throughput? Give an
   example of a loop limited by each.
2. Why is an array sum with four accumulators faster than with one? How
   many accumulators do you need for `vaddps` with latency 3 and two
   issues per cycle?
3. What is a cache line, and why is traversing a matrix by columns slow?
4. When is `prefetcht0` useful, and when is it useless?
5. Why `lfence` before `rdtsc`? What exactly does the TSC count?
6. Which `perf stat` metrics will you look at first, and what will they
   tell you?
7. Why are benchmark results at `-O0` meaningless?
8. What is a store forwarding stall?

## Further reading

* Denis Bakhvalov, "Performance Analysis and Tuning on Modern CPUs"
  (free book, easyperf.net) — the main source for this chapter.
* Agner Fog: "Optimizing software in C++", "Optimizing subroutines in
  assembly language", "The microarchitecture of Intel, AMD and VIA CPUs",
  "Instruction tables" (agner.org/optimize).
* https://uops.info, https://uica.uops.info.
* Ulrich Drepper, "What Every Programmer Should Know About Memory".
* Intel® 64 and IA-32 Architectures Optimization Reference Manual; AMD
  Software Optimization Guide for Zen.
* Daniel Lemire's blog — lots of careful microbenchmarks.
* Brendan Gregg, "Systems Performance" and brendangregg.com (perf,
  flame graphs).
* Mike Acton, "Data-Oriented Design and C++" (CppCon 2014) — a bridge to
  the engine track.
