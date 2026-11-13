# =====================================================================
#  a1005 · Перестановки: pshufd и pshufb
# =====================================================================
#
#  Данные часто лежат «не в том порядке». SIMD-перестановки:
#
#      pshufd xmm0, xmm1, imm8   — 4 dword: поле i результата = xmm1[(imm >> 2i) & 3]
#                                  imm пишут по-двоичному «справа налево»:
#                                  0b00_01_10_11 = 0x1B — разворот (3,2,1,0)
#      shufps xmm0, xmm1, imm8   — то же для float, но поля 2,3 берутся из xmm1,
#                                  а поля 0,1 — из xmm0
#      pshufb xmm0, xmm1         — (SSSE3) байт i = xmm0[xmm1[i] & 15],
#                                  а если в xmm1[i] старший бит = 1, то 0.
#                                  Произвольная перестановка 16 байтов по таблице!
#
#  pshufb — швейцарский нож: перестановка каналов цвета, смена порядка
#  байтов, табличный lookup 16 значений (на этом построены быстрый
#  popcount, base64, UTF-8-валидация).
#
#  Перевод RGBA -> BGRA (меняем местами байты 0 и 2 в каждом пикселе):
#  маска для pshufb = 2,1,0,3, 6,5,4,7, 10,9,8,11, 14,13,12,15 — 4 пикселя
#  за инструкцию. Маску кладут в .rodata (выровненную на 16, если хотите
#  использовать её как операнд в памяти pshufb).
#
#  ЗАДАЧА:
#      reverse4(v)              — развернуть 4 int на месте (pshufd)
#      rgba_to_bgra(px, count)  — count пикселей (любое число >= 0):
#                                 по 4 пикселя через pshufb, хвост — скалярно
#                                 (например, mov eax, [px]; bswap eax; ror eax, 8
#                                 — подумайте, что это даёт; или побайтно)
#
    .intel_syntax noprefix
    .section .rodata
    .p2align 4
bgra_mask:
    .byte 2, 1, 0, 3, 6, 5, 4, 7, 10, 9, 8, 11, 14, 13, 12, 15

    .text

# void reverse4(int* v)
    .globl reverse4
reverse4:
    movdqu xmm0, [rdi]
    pshufd xmm0, xmm0, 0b00011011
    movdqu [rdi], xmm0
    ret

# void rgba_to_bgra(char* px /*rdi*/, long count /*rsi*/)
    .globl rgba_to_bgra
rgba_to_bgra:
    movdqa xmm1, [rip + bgra_mask]
    xor eax, eax            # номер пикселя
    lea rcx, [rsi - 3]
    jmp 2f
1:
    movdqu xmm0, [rdi + rax*4]
    pshufb xmm0, xmm1
    movdqu [rdi + rax*4], xmm0
    add rax, 4
2:
    cmp rax, rcx
    jl 1b
    jmp 4f
3:
    mov edx, [rdi + rax*4]  # байты в регистре: A B G R (старший..младший)
    bswap edx               # R G B A
    ror edx, 8              # A R G B -> в памяти B G R A
    mov [rdi + rax*4], edx
    inc rax
4:
    cmp rax, rsi
    jl 3b
    ret

    .section .note.GNU-stack,"",@progbits
