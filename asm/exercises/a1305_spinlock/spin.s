# =====================================================================
#  a1305 · Spinlock: xchg, pause and memory ordering
# =====================================================================
#
#  The simplest lock: 0 — free, 1 — taken.
#
#  trylock:  atomically write 1 and look at what was there:
#      mov  eax, 1
#      xchg dword ptr [rdi], eax   ; xchg with memory is always atomic (implicit lock)
#      ; eax == 0  => we acquired the lock
#
#  lock: repeat trylock until it succeeds. But spinning on xchg in a loop
#  is bad: every xchg requires EXCLUSIVE ownership of the cache line, and
#  the waiting cores keep stealing it from each other. The right way is
#  "test and test-and-set": wait by JUST READING (the line is in the shared
#  state, no traffic), and try xchg only after seeing 0:
#
#  lock:
#      mov  eax, 1
#      xchg [rdi], eax
#      test eax, eax
#      jz   done
#  spin:
#      pause                    ; hint to the CPU: "I'm in a spin loop"
#      cmp  dword ptr [rdi], 0  ; a plain read
#      jne  spin
#      jmp  lock                ; it's free — try to acquire again
#
#  `pause` reduces power consumption, frees resources for the core's second
#  hyperthread, and avoids the "memory order violation" penalty when
#  leaving the loop. (On Skylake+ pause takes ~140 cycles, earlier ~10.)
#
#  unlock: just `mov dword ptr [rdi], 0`. On x86 a plain store has
#  release semantics: the processor won't move earlier loads and
#  stores AFTER it (the TSO memory model). No barrier needed! (On ARM you'd
#  need stlr.) But the C3 compiler has no way of knowing that — which is why
#  locks are written with atomics/assembly rather than plain assignments.
#
#  TASK: write spin_trylock (1 — acquired, 0 — taken), spin_lock
#  (test-and-test-and-set with pause), spin_unlock.
#
    .intel_syntax noprefix
    .text

# CInt spin_trylock(CInt* l)
    .globl spin_trylock
spin_trylock:
    # TODO
    xor eax, eax
    ret

# void spin_lock(CInt* l)
    .globl spin_lock
spin_lock:
    # TODO
    ret

# void spin_unlock(CInt* l)
    .globl spin_unlock
spin_unlock:
    # TODO
    ret

    .section .note.GNU-stack,"",@progbits
