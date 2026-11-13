# =====================================================================
#  a1004 · Поиск байта: pcmpeqb + pmovmskb + tzcnt
# =====================================================================
#
#  Так устроены memchr, strlen и парсеры вроде simdjson:
#
#      movd      xmm1, esi        # c в младший байт
#      pxor      xmm2, xmm2
#      pshufb    xmm1, xmm2       # размножить байт 0 на все 16 (SSSE3)
#                                 # (в AVX2: vpbroadcastb xmm1, xmm1)
#    цикл:
#      movdqu    xmm0, [rdi + i]  # 16 байтов строки
#      pcmpeqb   xmm0, xmm1       # байт = 0xFF там, где совпало, иначе 0x00
#      pmovmskb  eax, xmm0        # по 1 биту из каждого байта -> 16-битная маска
#      test      eax, eax
#      jnz       found            # индекс = i + tzcnt(eax)
#
#  Тот самый перебор битов маски из главы 08! А для подсчёта — popcnt.
#
#  Хвост: нельзя просто прочитать 16 байтов, если до конца данных
#  меньше 16 — можно выйти за конец страницы и получить segfault. (Реальные
#  memchr читают выровненными блоками: выровненный 16-байтный блок никогда
#  не пересекает границу страницы. Это законно на уровне железа, но
#  санитайзеры такое не любят.) Мы сделаем просто: блоки по 16, пока
#  i + 16 <= n, потом скалярный хвост.
#
#  Важно: pmovmskb даёт маску в eax, а аргумент c пришёл в sil/esi; сам
#  c — char, т.е. значимы только младшие 8 бит esi.
#
#  ЗАДАЧА:
#      find_byte(s, n, c)   — индекс первого вхождения c или -1
#      count_byte(s, n, c)  — количество вхождений
#
    .intel_syntax noprefix
    .text

# long find_byte(char* s /*rdi*/, long n /*rsi*/, char c /*dl*/)
    .globl find_byte
find_byte:
    movd xmm1, edx
    pxor xmm2, xmm2
    pshufb xmm1, xmm2       # c во всех 16 байтах
    xor eax, eax            # i
    lea rcx, [rsi - 15]
    jmp 2f
1:
    movdqu xmm0, [rdi + rax]
    pcmpeqb xmm0, xmm1
    pmovmskb r8d, xmm0
    test r8d, r8d
    jz 5f
    tzcnt r8d, r8d
    add rax, r8
    ret
5:
    add rax, 16
2:
    cmp rax, rcx
    jl 1b
    jmp 4f
3:
    cmp byte ptr [rdi + rax], dl
    je 9f
    inc rax
4:
    cmp rax, rsi
    jl 3b
    mov rax, -1
9:
    ret

# long count_byte(char* s, long n, char c)
    .globl count_byte
count_byte:
    movd xmm1, edx
    pxor xmm2, xmm2
    pshufb xmm1, xmm2
    xor eax, eax            # результат
    xor r9d, r9d            # i
    lea rcx, [rsi - 15]
    jmp 2f
1:
    movdqu xmm0, [rdi + r9]
    pcmpeqb xmm0, xmm1
    pmovmskb r8d, xmm0
    popcnt r8d, r8d
    add rax, r8
    add r9, 16
2:
    cmp r9, rcx
    jl 1b
    jmp 4f
3:
    cmp byte ptr [rdi + r9], dl
    jne 5f
    inc rax
5:
    inc r9
4:
    cmp r9, rsi
    jl 3b
    ret

    .section .note.GNU-stack,"",@progbits
