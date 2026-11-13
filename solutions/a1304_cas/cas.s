# =====================================================================
#  a1304 · Compare-and-swap: lock cmpxchg и CAS-циклы
# =====================================================================
#
#  `lock cmpxchg [mem], r` — главная атомарная инструкция:
#
#      если [mem] == rax:  [mem] = r,   ZF = 1
#      иначе:              rax = [mem], ZF = 0
#
#  (rax — неявный операнд: «ожидаемое» значение.) Всё — атомарно.
#  Через CAS выражается любая атомарная операция: читаем старое
#  значение, вычисляем новое, пытаемся записать; если кто-то успел
#  изменить ячейку — cmpxchg вернёт свежее значение в rax, и мы
#  повторяем:
#
#      mov rax, [p]
#  retry:
#      ...rcx = f(rax)...
#      lock cmpxchg [p], rcx
#      jne retry                 ; rax уже обновлён — заново читать не нужно
#
#  Это «lock-free» алгоритм: какой-то поток всегда продвигается.
#  Подводный камень CAS — проблема ABA (значение изменилось с A на B и
#  обратно на A — CAS этого не заметит); для указателей её решают
#  счётчиками версий и cmpxchg16b.
#
#  ЗАДАЧА:
#      atomic_cas(p, expected, desired) -> 1 при успехе, 0 при неудаче
#                                          (sete al после cmpxchg)
#      atomic_max(p, v) — атомарно *p = max(*p, v), вернуть старое *p
#                         (CAS-цикл; если *p >= v, писать не нужно)
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
    jge 2f                  # уже не меньше v — ничего не делаем
    lock cmpxchg qword ptr [rdi], rsi
    jne 1b                  # не вышло: rax = свежее значение, пробуем снова
2:
    ret

    .section .note.GNU-stack,"",@progbits
