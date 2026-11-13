# =====================================================================
#  a0502 · Callee-saved регистры
# =====================================================================
#
#  System V делит регистры на две группы:
#
#    caller-saved (volatile, «можно портить»):
#        rax, rcx, rdx, rsi, rdi, r8, r9, r10, r11
#    callee-saved (non-volatile, «верни как было»):
#        rbx, rbp, r12, r13, r14, r15   (и, конечно, rsp)
#
#  Если ваша функция пользуется rbx или r12–r15, она обязана сохранить
#  их старые значения и восстановить перед ret. Классический способ —
#  push в начале и pop в ОБРАТНОМ порядке в конце:
#
#      push rbx
#      push r12
#      ...
#      pop r12
#      pop rbx
#      ret
#
#  Зачем вообще нужны callee-saved регистры? Вызывающий держит в них
#  значения, которые должны пережить вызов, — и не платит за
#  сохранение при каждом call (см. a0503).
#
#  Нарушение этого правила — коварный баг: ваша функция работает,
#  а падает (или считает неправильно) код, который её вызвал, иногда
#  намного позже. Тестовый стенд abi_check.s кладёт в эти регистры
#  «канарейки» и проверяет их после вызова.
#
#  Альтернатива — просто не трогать callee-saved регистры, если хватает
#  volatile. Оба решения засчитываются.
#
#  ЗАДАЧА: функции считают правильно, но портят регистры вызывающего.
#    asm_sumsq(a, b, c)     = a² + b² + c²
#    asm_poly3(x, a, b, c)  = a·x² + b·x + c
#  Почините их. Программа напечатает
#      sumsq=14 poly3=124 abi=ok
#
    .intel_syntax noprefix
    .text

    .globl asm_sumsq
asm_sumsq:
    # TODO: rbx и r12 — callee-saved
    mov rbx, rdi
    imul rbx, rbx
    mov r12, rsi
    imul r12, r12
    mov rax, rdx
    imul rax, rax
    add rax, rbx
    add rax, r12
    ret

    .globl asm_poly3
asm_poly3:
    # TODO: r13, r14, r15 — тоже
    mov r13, rdi
    imul r13, rdi           # x²
    imul r13, rsi           # a·x²
    mov r14, rdx
    imul r14, rdi           # b·x
    mov r15, rcx            # c
    lea rax, [r13 + r14]
    add rax, r15
    ret

    .section .note.GNU-stack,"",@progbits
