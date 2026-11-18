# =====================================================================
#  a1303 · Atomic operations: the lock prefix and xadd
# =====================================================================
#
#  `add dword ptr [rdi], 1` is actually three steps: read, add, write.
#  If two cores do this at the same time, both may read 5 and both
#  write 6 — one increment is lost.
#
#  The `lock` prefix makes the read-modify-write ATOMIC: the core takes
#  the cache line into exclusive ownership (MESI protocol) and doesn't
#  give it up until the operation completes:
#
#      lock add  dword ptr [rdi], esi     ; atomically *p += v
#      lock inc  qword ptr [rdi]
#      lock xadd dword ptr [rdi], eax     ; atomically: tmp = *p; *p += eax; eax = tmp
#
#  `xadd` (exchange-and-add) returns the OLD value — this is fetch_add,
#  the basis of reference counts, ticket locks, and handing out indices in task queues.
#
#  On x86, lock operations are also a FULL memory barrier (see the chapter doc).
#  Cost: ~20 cycles uncontended; when cores fight over one line — hundreds.
#
#  `xchg` with memory is ALWAYS atomic, even without lock (lock is implied).
#
#  TASK:
#      atomic_fetch_add(p, v)  — return the old value of *p, atomically *p += v
#      atomic_inc64(p)         — atomically ++*p (64 bits), return the NEW value
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
