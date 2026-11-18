# =====================================================================
#  a1401 · How to measure: rdtsc, rdtscp, lfence
# =====================================================================
#
#  The Time Stamp Counter is a 64-bit counter that on modern CPUs ticks
#  at a CONSTANT rate (the constant_tsc and nonstop_tsc flags in
#  /proc/cpuinfo), independent of the current core frequency. So it is
#  a "very precise clock" rather than a core cycle counter in the strict
#  sense (real cycles are counted via perf: `perf stat -e cycles`).
#
#      rdtsc      edx:eax = TSC
#      rdtscp     edx:eax = TSC, ecx = IA32_TSC_AUX (on Linux: CPU and node number)
#                 and waits for all PRECEDING instructions to complete
#
#  The catch: rdtsc is not serializing — the processor may execute it
#  earlier or later than neighbouring instructions (out-of-order
#  execution). Therefore:
#      lfence; rdtsc         — "start" timestamp: everything before it has completed
#      rdtscp; lfence        — "end" timestamp: nothing after it starts early
#
#  The result is assembled into 64 bits:  shl rdx, 32; or rax, rdx.
#
#  In C3, $$sysclock() gives you the same thing. But for serious
#  measurements use ready-made tools: perf stat, perf record, uarch-bench,
#  nanobench, google benchmark.
#
#  TASK:
#      read_tsc()        — lfence; rdtsc; return the 64-bit value
#      read_tscp(aux)    — rdtscp; *aux = ecx; return the 64-bit value
#
    .intel_syntax noprefix
    .text

    .globl read_tsc
read_tsc:
    lfence
    rdtsc
    shl rdx, 32
    or rax, rdx
    ret

# ulong read_tscp(uint* aux /*rdi*/)
    .globl read_tscp
read_tscp:
    rdtscp
    lfence
    mov dword ptr [rdi], ecx
    shl rdx, 32
    or rax, rdx
    ret

    .section .note.GNU-stack,"",@progbits
