# =====================================================================
#  a1304 · Compare-and-swap: lock cmpxchg and CAS loops
# =====================================================================
#
#  `lock cmpxchg [mem], r` is the key atomic instruction:
#
#      if [mem] == rax:  [mem] = r,   ZF = 1
#      otherwise:        rax = [mem], ZF = 0
#
#  (rax is an implicit operand: the "expected" value.) All of it is atomic.
#  Any atomic operation can be expressed through CAS: read the old
#  value, compute the new one, try to store it; if someone managed to
#  change the cell in between, cmpxchg returns the fresh value in rax,
#  and we retry:
#
#      mov rax, [p]
#  retry:
#      ...rcx = f(rax)...
#      lock cmpxchg [p], rcx
#      jne retry                 ; rax is already updated — no need to re-read
#
#  This is a "lock-free" algorithm: some thread always makes progress.
#  The pitfall of CAS is the ABA problem (the value changed from A to B and
#  back to A — CAS won't notice); for pointers it is solved with
#  version counters and cmpxchg16b.
#
#  TASK:
#      atomic_cas(p, expected, desired) -> 1 on success, 0 on failure
#                                          (sete al after cmpxchg)
#      atomic_max(p, v) — atomically *p = max(*p, v), return the old *p
#                         (a CAS loop; if *p >= v, no store is needed)
#
    .intel_syntax noprefix
    .text

# CInt atomic_cas(long* p /*rdi*/, long expected /*rsi*/, long desired /*rdx*/)
    .globl atomic_cas
atomic_cas:
    mov rax, rsi
    lock cmpxchg qword ptr [rdi], rdx
    sete al
    movzx eax, al
    ret

# long atomic_max(long* p /*rdi*/, long v /*rsi*/)
    .globl atomic_max
atomic_max:
    mov rax, [rdi]
1:
    cmp rax, rsi
    jge 2f                  # already not less than v — do nothing
    lock cmpxchg qword ptr [rdi], rsi
    jne 1b                  # failed: rax = the fresh value, try again
2:
    ret

    .section .note.GNU-stack,"",@progbits
