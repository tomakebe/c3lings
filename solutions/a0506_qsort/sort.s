# =====================================================================
#  a0506 · Колбэк для qsort: libc вызывает ваш код
# =====================================================================
#
#  Теперь наоборот: передадим адрес СВОЕЙ ассемблерной функции в libc.
#
#      void qsort(void* base, size_t n, size_t size,
#                 int (*cmp)(const void*, const void*));
#
#  Адрес функции из того же файла берётся так же, как адрес данных:
#      lea rcx, [rip + asm_cmp_desc]
#
#  Компаратор получает два УКАЗАТЕЛЯ на элементы и возвращает int:
#  < 0, если первый должен идти раньше, > 0 — если позже, 0 — равны.
#  Мы сортируем по убыванию.
#
#  Знаменитая ловушка: «return *a - *b». Для long разность может
#  переполниться (LONG_MAX - LONG_MIN), а при усечении до int ещё и
#  потерять старшие биты (2^40 - 0 = 0x10000000000, младшие 32 бита —
#  ноль!). Сравнивайте честно: cmp + условные переходы (или setcc).
#
#  Компаратор — «листовая» функция (никого не вызывает), ему стек
#  выравнивать не нужно. А asm_sort_desc вызывает qsort — значит,
#  перед call rsp должен быть кратен 16.
#
#  ЗАДАЧА: напишите
#    asm_cmp_desc(pa, pb) — сравнение long *pa и *pb для убывания;
#    asm_sort_desc(a, n)  — qsort(a, n, 8, asm_cmp_desc).
#  Программа напечатает
#      [9223372036854775807, 1099511627776, 42, 42, 3, 0, -1, -100, -9223372036854775808]
#      abi=ok
#
    .intel_syntax noprefix
    .text

    .globl asm_cmp_desc
asm_cmp_desc:
    mov rax, [rdi]
    cmp rax, [rsi]
    jg .Lfirst              # *pa > *pb -> pa раньше
    jl .Lsecond
    xor eax, eax
    ret
.Lfirst:
    mov eax, -1
    ret
.Lsecond:
    mov eax, 1
    ret

    .globl asm_sort_desc
asm_sort_desc:
    sub rsp, 8
    mov edx, 8
    lea rcx, [rip + asm_cmp_desc]
    call qsort@PLT
    add rsp, 8
    ret

    .section .note.GNU-stack,"",@progbits
