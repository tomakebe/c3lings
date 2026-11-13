# =====================================================================
#  a0704 · Поиск байта: repne scasb
# =====================================================================
#
#  `scasb` сравнивает al с байтом [rdi] (как `cmp al, [rdi]`, ставит
#  флаги) и сдвигает rdi на 1. С префиксом:
#
#      repne scasb     # повторять, пока rcx != 0 И байт != al
#      repe  scasb     # повторять, пока rcx != 0 И байт == al
#
#  После остановки rdi указывает на байт ПОСЛЕ последнего сравнённого,
#  rcx уменьшен на число сравнений, а ZF говорит, чем кончилось:
#  ZF = 1 — нашли (байт == al), ZF = 0 — кончился rcx.
#
#  Классический strlen через scasb:
#
#      xor eax, eax        # ищем 0
#      mov rcx, -1         # «бесконечно» (2^64 - 1)
#      repne scasb
#      # проверено k = (длина + 1) байт; rcx = -1 - k
#      not rcx             # rcx = k     (not x = -x - 1)
#      dec rcx             # длина без нуля
#
#  Флаг DF (направление) должен быть 0 — ABI это гарантирует при
#  входе. Красиво, но на практике медленно: repne scasb обрабатывает
#  1 байт за такт или хуже, а glibc читает по 32 байта AVX2-регистром.
#  Это урок про семантику, а не про скорость (скорость — глава 10).
#
#  ЗАДАЧА:
#    asm_strlen_scas(s)    — длина через repne scasb;
#    asm_memchr(p, c, n)   — указатель на первый байт == (char)c среди
#                            первых n байт, или null (0).
#  Программа напечатает
#      len=0 8 colon_at=4
#
    .intel_syntax noprefix
    .text

    .globl asm_strlen_scas
asm_strlen_scas:
    xor eax, eax
    mov rcx, -1
    repne scasb
    not rcx
    dec rcx
    mov rax, rcx
    ret

    .globl asm_memchr
asm_memchr:
    test rdx, rdx
    jz .Lnone
    mov eax, esi
    mov rcx, rdx
    repne scasb
    jne .Lnone
    lea rax, [rdi - 1]
    ret
.Lnone:
    xor eax, eax
    ret

    .section .note.GNU-stack,"",@progbits
