# =====================================================================
#  a0504 · Вызов libc: snprintf и strlen
# =====================================================================
#
#  Программа на C3 линкуется с libc, так что из ассемблера можно звать
#  любые её функции — по тем же правилам System V.
#
#  Вариадические функции (printf, snprintf, ...) требуют ещё одного:
#  в al перед вызовом — число аргументов, переданных в векторных
#  регистрах xmm0–xmm7 (верхняя граница). Нет double-аргументов —
#  `xor eax, eax`. Есть один double — `mov eax, 1`.
#  Double-аргументы идут в xmm0, xmm1, ... НЕЗАВИСИМО от целых:
#      snprintf(buf, size, fmt, n, x)  ->  rdi, rsi, rdx, rcx, xmm0
#  Наша функция получила x тоже в xmm0 — так что он уже на месте.
#
#  glibc, увидев al != 0, сохраняет xmm-регистры инструкцией movaps,
#  которая падает на невыровненном адресе. Так что тут выравнивание
#  стека проверяется «по-настоящему»: забыли — segfault.
#
#  Строковые константы кладут в секцию только для чтения, а адрес
#  берут относительно rip (код у нас позиционно-независимый, PIE):
#
#          .section .rodata
#      fmt: .asciz "n=%ld x=%.2f"     # .asciz добавляет завершающий 0
#          .text
#          lea rdx, [rip + fmt]
#
#  Вызов внешней функции: `call snprintf@PLT` (через таблицу PLT —
#  линковщик подставит адрес из libc; просто `call snprintf` линковщик
#  тоже поймёт).
#
#  ЗАДАЧА:
#    asm_format(buf, size, n, x) — вызвать snprintf(buf, size,
#        "n=%ld x=%.2f", n, x) и вернуть её результат. Сейчас не
#        выставлен al и не выровнен стек.
#    asm_total_len(a, b) — strlen(a) + strlen(b). Напишите сами;
#        помните, что после первого call rsi уже испорчен.
#  Программа напечатает
#      [n=42 x=3.14] len=11
#      [n=-7 x=-0.50] len=12
#      total_len=13 abi=ok
#
    .intel_syntax noprefix

    .section .rodata
fmt:
    .asciz "n=%ld x=%.2f"

    .text

    .globl asm_format
asm_format:
    sub rsp, 8
    mov rcx, rdx            # 4-й аргумент snprintf — n
    lea rdx, [rip + fmt]    # 3-й — формат
    mov eax, 1              # один аргумент в xmm-регистре
    call snprintf@PLT
    add rsp, 8
    ret

    .globl asm_total_len
asm_total_len:
    push rbx
    push r12
    sub rsp, 8
    mov r12, rsi
    call strlen@PLT
    mov rbx, rax
    mov rdi, r12
    call strlen@PLT
    add rax, rbx
    add rsp, 8
    pop r12
    pop rbx
    ret

    .section .note.GNU-stack,"",@progbits
