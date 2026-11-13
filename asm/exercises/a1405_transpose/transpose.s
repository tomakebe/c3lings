# =====================================================================
#  a1405 · Транспонирование: SIMD-перестановки и доступ к памяти
# =====================================================================
#
#  Наивное транспонирование dst[c][r] = src[r][c] читает src по строкам,
#  а пишет dst по столбцам — шаг n*4 байта. Каждая запись попадает в новую
#  кеш-линию; при n = 1024 линии вытесняют друг друга (ассоциативность
#  кеша, «4K aliasing»). Классическое решение — блоки: транспонируем
#  матрицу кусками 4x4 (или 8x8), внутри блока — регистрами SIMD.
#
#  Транспонирование 4x4 int в регистрах (то же, что _MM_TRANSPOSE4_PS):
#
#      x0 = a0 a1 a2 a3       t0 = punpckldq(x0, x1) = a0 b0 a1 b1
#      x1 = b0 b1 b2 b3       t1 = punpckhdq(x0, x1) = a2 b2 a3 b3
#      x2 = c0 c1 c2 c3       t2 = punpckldq(x2, x3) = c0 d0 c1 d1
#      x3 = d0 d1 d2 d3       t3 = punpckhdq(x2, x3) = c2 d2 c3 d3
#
#      r0 = punpcklqdq(t0, t2) = a0 b0 c0 d0
#      r1 = punpckhqdq(t0, t2) = a1 b1 c1 d1
#      r2 = punpcklqdq(t1, t3) = a2 b2 c2 d2
#      r3 = punpckhqdq(t1, t3) = a3 b3 c3 d3
#
#  (Инструкции двухоперандные: punpckldq x, y — результат в x, поэтому
#   сначала копируйте movdqa t, x.)
#
#  Шаги (stride) — в ЭЛЕМЕНТАХ int; в байтах это stride*4.
#  Для полной матрицы блок (bi, bj) из src копируется транспонированным
#  в блок (bj, bi) dst. Для больших матриц добавляют prefetcht0 строк
#  следующего блока и обходят блоки «полосами», чтобы рабочий набор
#  помещался в L1.
#
#  ЗАДАЧА:
#      transpose4x4(dst, dst_stride, src, src_stride) — один блок
#      transpose(dst, src, n)  — n кратно 4; вызывайте transpose4x4
#                                (не забудьте про callee-saved регистры
#                                 и выравнивание стека перед call!)
#
    .intel_syntax noprefix
    .text

# void transpose4x4(int* dst /*rdi*/, long dst_stride /*rsi*/, int* src /*rdx*/, long src_stride /*rcx*/)
    .globl transpose4x4
transpose4x4:
    shl rsi, 2              # шаги в байтах
    shl rcx, 2
    movdqu xmm0, [rdx]
    movdqu xmm1, [rdx + rcx]
    movdqu xmm2, [rdx + rcx*2]
    add rdx, rcx
    movdqu xmm3, [rdx + rcx*2]
    # TODO: перестановки и запись четырёх строк в dst
    ret

# void transpose(int* dst /*rdi*/, int* src /*rsi*/, long n /*rdx*/)
    .globl transpose
transpose:
    # TODO: два вложенных цикла по блокам
    ret

    .section .note.GNU-stack,"",@progbits
