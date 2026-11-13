# =====================================================================
#  a0203 · Деление: div, idiv и загадочный rdx
# =====================================================================
#
#  Деление на x86 устроено не так, как остальная арифметика. Делимое —
#  это ДВОЙНОЙ ширины пара регистров, делитель — единственный операнд:
#
#      div esi     # беззнаковое: edx:eax / esi -> eax = частное, edx = остаток
#      idiv esi    # знаковое:    edx:eax / esi -> eax = частное, edx = остаток
#      div rsi     # 64 бита:     rdx:rax / rsi -> rax, rdx
#
#  То есть перед делением мало положить делимое в eax — надо ещё
#  правильно заполнить edx (rdx) старшей половиной делимого:
#    * для div  — нулями:            xor edx, edx
#    * для idiv — копией знака eax:  cdq   (eax -> edx:eax)
#                                    cqo   (rax -> rdx:rax)
#  Если в edx мусор, частное может не влезть в eax — и процессор
#  бросит исключение #DE. В Linux это сигнал SIGFPE («Floating point
#  exception», хотя плавающей точки тут нет). Деление на ноль — тоже #DE.
#
#  Ещё две вещи:
#    * у div нет формы с immediate: `div 10` не существует;
#    * div портит rdx — помните, что это 3-й аргумент функции!
#
#  Знаковое деление округляет к нулю: -7 / 2 = -3, -7 % 2 = -1
#  (как в C и C3).
#
#  ЗАДАЧА: asm_udiv уже правильная — используйте её как образец.
#  Почините остальные. Программа напечатает
#      udiv=14 umod=2 idiv=-3 lmod=-1
#
    .intel_syntax noprefix
    .text

    .globl asm_udiv
asm_udiv:
    mov eax, edi
    xor edx, edx
    div esi
    ret

    .globl asm_umod
asm_umod:
    mov eax, edi
    xor edx, edx
    div esi
    # TODO: функция должна вернуть остаток
    ret

    .globl asm_idiv
asm_idiv:
    mov eax, edi
    xor edx, edx            # TODO: для знакового деления это неверно
    idiv esi
    ret

    .globl asm_lmod
asm_lmod:
    mov rax, rdi
    cdq                     # TODO: тут 64-битное деление
    idiv rsi
    mov rax, rdx
    ret

    .section .note.GNU-stack,"",@progbits
