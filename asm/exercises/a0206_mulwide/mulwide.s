# =====================================================================
#  a0206 · Широкое умножение: mul и одноадресный imul
# =====================================================================
#
#  Произведение двух 64-битных чисел занимает до 128 бит. Одноадресные
#  формы умножения отдают его целиком в паре rdx:rax:
#
#      mul rsi      # rdx:rax = rax * rsi   (беззнаково)
#      imul rsi     # rdx:rax = rax * rsi   (знаково)
#
#  Первый множитель неявный — всегда rax. Младшие 64 бита у mul и imul
#  одинаковые, старшие — разные (сравните 0xFFFF...FFFF * 2: беззнаково
#  это 2^65 - 2, старшая часть 1; знаково это -1 * 2 = -2, старшая
#  часть -1).
#
#  Пара rdx:rax — ровно то, что ждёт div. Значит a * b / c можно
#  посчитать без переполнения: mul, затем div (если частное влезает
#  в 64 бита).
#
#  Помните: mul/imul/div портят rdx, а это ваш 3-й аргумент. Сохраните
#  его в свободный регистр (например, rcx или r8) заранее.
#
#  ЗАДАЧА: напишите четыре функции целиком:
#    asm_mulhi(a, b)     — старшие 64 бита беззнакового a*b;
#    asm_imulhi(a, b)    — старшие 64 бита знакового a*b;
#    asm_mul_full(a, b)  — всё 128-битное произведение (uint128: lo в rax,
#                          hi в rdx — заметьте, mul уже кладёт его туда);
#    asm_muldiv(a, b, c) — a * b / c (беззнаково, промежуточно 128 бит).
#  Программа напечатает
#      mulhi=1 imulhi=-1 full_hi=1 muldiv=100000000
#
    .intel_syntax noprefix
    .text

    .globl asm_mulhi
asm_mulhi:
    # TODO
    xor eax, eax
    ret

    .globl asm_imulhi
asm_imulhi:
    # TODO
    xor eax, eax
    ret

    .globl asm_mul_full
asm_mul_full:
    # TODO
    xor eax, eax
    xor edx, edx
    ret

    .globl asm_muldiv
asm_muldiv:
    # TODO
    xor eax, eax
    ret

    .section .note.GNU-stack,"",@progbits
