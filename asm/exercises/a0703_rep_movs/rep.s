# =====================================================================
#  a0703 · Строковые инструкции: rep movsb и rep stosb
# =====================================================================
#
#  У x86 есть «строковые» инструкции с неявными операндами:
#
#      movsb     byte [rdi] = byte [rsi];  rdi++, rsi++
#      stosb     byte [rdi] = al;          rdi++
#      stosd     dword [rdi] = eax;        rdi += 4   (stosw, stosq — тоже)
#      lodsb     al = byte [rsi];          rsi++
#
#  Префикс `rep` повторяет инструкцию rcx раз (уменьшая rcx до нуля):
#
#      mov rcx, n
#      rep movsb          # memcpy(rdi, rsi, n)
#
#  Удобное совпадение: rdi (приёмник) и rsi (источник) — это же
#  первые два аргумента System V. Для memcpy(dst, src, n) остаётся
#  только перенести n из rdx в rcx.
#
#  Направление задаёт флаг DF: при DF = 0 адреса растут, при DF = 1 —
#  убывают. ABI гарантирует DF = 0 при входе в функцию и требует
#  DF = 0 при выходе. Если меняли (`std`), верните `cld`.
#
#  На современных CPU (флаг ERMSB, «Enhanced REP MOVSB») rep movsb —
#  быстрый способ копировать большие блоки; glibc использует его для
#  больших memcpy.
#
#  Не забудьте: memcpy и memset возвращают исходный dst, а rep
#  movsb/stosb сдвигают rdi — сохраните его заранее в rax.
#
#  ЗАДАЧА:
#    asm_memcpy(dst, src, n) — скопировать n байт, вернуть dst;
#    asm_memset(dst, c, n)   — заполнить n байт значением c, вернуть dst;
#    asm_fill32(dst, v, n)   — заполнить n uint'ов значением v.
#  Программа напечатает
#      memcpy: ..abcde........
#      memset: ..abcde.ZZZZ...
#      fill32: 0 deadbeef deadbeef
#
    .intel_syntax noprefix
    .text

    .globl asm_memcpy
asm_memcpy:
    # TODO: rcx = ? и что вернуть?
    rep movsb
    ret

    .globl asm_memset
asm_memset:
    mov rax, rdi
    mov rcx, rdx
    rep stosb               # TODO: какой байт сейчас в al?
    ret

    .globl asm_fill32
asm_fill32:
    # TODO
    ret

    .section .note.GNU-stack,"",@progbits
