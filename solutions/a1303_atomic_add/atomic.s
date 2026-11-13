# =====================================================================
#  a1303 · Атомарные операции: префикс lock и xadd
# =====================================================================
#
#  `add dword ptr [rdi], 1` — это на самом деле три шага: прочитать,
#  сложить, записать. Если два ядра делают это одновременно, оба могут
#  прочитать 5 и оба записать 6 — одно увеличение потеряется.
#
#  Префикс `lock` делает чтение-изменение-запись АТОМАРНОЙ: ядро
#  захватывает кеш-линию в эксклюзивное владение (протокол MESI) и не
#  отдаёт её, пока операция не завершится:
#
#      lock add  dword ptr [rdi], esi     ; атомарно *p += v
#      lock inc  qword ptr [rdi]
#      lock xadd dword ptr [rdi], eax     ; атомарно: tmp = *p; *p += eax; eax = tmp
#
#  `xadd` (exchange-and-add) возвращает СТАРОЕ значение — это fetch_add,
#  основа счётчиков ссылок, тикет-локов, раздачи индексов в очередях задач.
#
#  lock-операции на x86 к тому же — ПОЛНЫЙ барьер памяти (глава в доке).
#  Цена: ~20 тактов без конкуренции; при борьбе ядер за одну линию — сотни.
#
#  `xchg` с памятью атомарен ВСЕГДА, даже без lock (lock подразумевается).
#
#  ЗАДАЧА:
#      atomic_fetch_add(p, v)  — вернуть старое значение *p, атомарно *p += v
#      atomic_inc64(p)         — атомарно ++*p (64 бита), вернуть НОВОЕ значение
#
    .intel_syntax noprefix
    .text

# CInt atomic_fetch_add(CInt* p /*rdi*/, CInt v /*esi*/)
    .globl atomic_fetch_add
atomic_fetch_add:
    mov eax, esi
    lock xadd dword ptr [rdi], eax
    ret

# long atomic_inc64(long* p)
    .globl atomic_inc64
atomic_inc64:
    mov eax, 1
    lock xadd qword ptr [rdi], rax
    inc rax
    ret

    .section .note.GNU-stack,"",@progbits
