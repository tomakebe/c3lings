# =====================================================================
#  a1401 · Как измерять: rdtsc, rdtscp, lfence
# =====================================================================
#
#  Time Stamp Counter — 64-битный счётчик, который на современных CPU
#  тикает с ПОСТОЯННОЙ частотой (флаги constant_tsc, nonstop_tsc в
#  /proc/cpuinfo), не зависящей от текущей частоты ядра. То есть это
#  «очень точные часы», а не счётчик тактов ядра в строгом смысле
#  (настоящие такты считают через perf: `perf stat -e cycles`).
#
#      rdtsc      edx:eax = TSC
#      rdtscp     edx:eax = TSC, ecx = IA32_TSC_AUX (на Linux: номер CPU и узла)
#                 и ждёт завершения всех ПРЕДЫДУЩИХ инструкций
#
#  Подвох: rdtsc не сериализующая — процессор может выполнить её раньше
#  или позже соседних инструкций (внеочередное исполнение). Поэтому:
#      lfence; rdtsc         — замер «начала»: всё до него уже завершено
#      rdtscp; lfence        — замер «конца»: ничего после не начнётся раньше
#
#  Результат собирают в 64 бита:  shl rdx, 32; or rax, rdx.
#
#  В C3 то же самое даёт $$sysclock(). Но для серьёзных измерений
#  берите готовые инструменты: perf stat, perf record, uarch-bench,
#  nanobench, google benchmark.
#
#  ЗАДАЧА:
#      read_tsc()        — lfence; rdtsc; вернуть 64-битное значение
#      read_tscp(aux)    — rdtscp; *aux = ecx; вернуть 64-битное значение
#
    .intel_syntax noprefix
    .text

    .globl read_tsc
read_tsc:
    lfence
    rdtsc
    # TODO: собрать edx:eax в rax
    ret

# ulong read_tscp(uint* aux /*rdi*/)
    .globl read_tscp
read_tscp:
    # TODO
    xor eax, eax
    ret

    .section .note.GNU-stack,"",@progbits
