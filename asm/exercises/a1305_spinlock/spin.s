# =====================================================================
#  a1305 · Спинлок: xchg, pause и порядок памяти
# =====================================================================
#
#  Простейшая блокировка: 0 — свободно, 1 — занято.
#
#  trylock:  атомарно записать 1 и посмотреть, что было:
#      mov  eax, 1
#      xchg dword ptr [rdi], eax   ; xchg с памятью — всегда атомарный (неявный lock)
#      ; eax == 0  => мы захватили блокировку
#
#  lock: повторять trylock, пока не получится. Но крутить xchg в цикле
#  плохо: каждый xchg требует ЭКСКЛЮЗИВНОГО владения кеш-линией, и
#  ждущие ядра гоняют её друг у друга. Правильно — «test and test-and-set»:
#  ждать, ПРОСТО ЧИТАЯ (линия в общем состоянии, без трафика), и пробовать
#  xchg только когда увидели 0:
#
#  lock:
#      mov  eax, 1
#      xchg [rdi], eax
#      test eax, eax
#      jz   done
#  spin:
#      pause                    ; подсказка CPU: «я в спин-цикле»
#      cmp  dword ptr [rdi], 0  ; обычное чтение
#      jne  spin
#      jmp  lock                ; освободилось — снова пробуем захватить
#
#  `pause` снижает энергопотребление, освобождает ресурсы для второго
#  гиперпотока ядра и избавляет от штрафа «memory order violation» при
#  выходе из цикла. (На Skylake+ pause длится ~140 тактов, раньше ~10.)
#
#  unlock: просто `mov dword ptr [rdi], 0`. На x86 обычная запись имеет
#  семантику release: процессор не переставит более ранние чтения и
#  записи ПОСЛЕ неё (модель памяти TSO). Барьер не нужен! (На ARM нужен
#  был бы stlr.) Но компилятору C3 об этом знать неоткуда — поэтому
#  блокировки и пишут на атомиках/ассемблере, а не обычными присваиваниями.
#
#  ЗАДАЧА: напишите spin_trylock (1 — захватили, 0 — занято), spin_lock
#  (test-and-test-and-set с pause), spin_unlock.
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
