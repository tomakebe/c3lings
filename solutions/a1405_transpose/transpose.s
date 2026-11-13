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
    movdqa xmm4, xmm0
    punpckldq xmm4, xmm1    # a0 b0 a1 b1
    punpckhdq xmm0, xmm1    # a2 b2 a3 b3
    movdqa xmm5, xmm2
    punpckldq xmm5, xmm3    # c0 d0 c1 d1
    punpckhdq xmm2, xmm3    # c2 d2 c3 d3
    movdqa xmm1, xmm4
    punpcklqdq xmm1, xmm5   # a0 b0 c0 d0
    punpckhqdq xmm4, xmm5   # a1 b1 c1 d1
    movdqa xmm3, xmm0
    punpcklqdq xmm3, xmm2   # a2 b2 c2 d2
    punpckhqdq xmm0, xmm2   # a3 b3 c3 d3
    movdqu [rdi], xmm1
    movdqu [rdi + rsi], xmm4
    movdqu [rdi + rsi*2], xmm3
    add rdi, rsi
    movdqu [rdi + rsi*2], xmm0
    ret

# void transpose(int* dst /*rdi*/, int* src /*rsi*/, long n /*rdx*/)
    .globl transpose
transpose:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8              # 6 push + адрес возврата = 56, +8 = 64: кратно 16
    mov r12, rdi            # dst
    mov r13, rsi            # src
    mov r14, rdx            # n
    xor ebx, ebx            # bi (строка блока в src)
1:
    cmp rbx, r14
    jge 4f
    xor ebp, ebp            # bj (столбец блока в src)
2:
    cmp rbp, r14
    jge 3f
    # src блок: src + (bi*n + bj)*4 ; dst блок: dst + (bj*n + bi)*4
    mov rax, rbx
    imul rax, r14
    add rax, rbp
    lea rdx, [r13 + rax*4]
    mov rax, rbp
    imul rax, r14
    add rax, rbx
    lea rdi, [r12 + rax*4]
    mov rsi, r14
    mov rcx, r14
    call transpose4x4
    add rbp, 4
    jmp 2b
3:
    add rbx, 4
    jmp 1b
4:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

    .section .note.GNU-stack,"",@progbits
