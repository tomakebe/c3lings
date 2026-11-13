# =====================================================================
#  a0905 · Вызов функции из ассемблера с плавающими аргументами
# =====================================================================
#
#  Метод средних прямоугольников:
#      h = (b - a) / n
#      integral ~= h * sum_{i=0}^{n-1} f(a + (i + 0.5) * h)
#
#  Главная трудность — вызов f через указатель (`call rbx`):
#
#    1. ВСЕ xmm-регистры caller-saved. После `call` в xmm0 — результат f,
#       а остальные xmm могут содержать что угодно. Значит, сумму, a и h
#       нужно хранить в памяти (на стеке) или... в целочисленных
#       callee-saved регистрах (rbx, rbp, r12-r15) через movq r64, xmm.
#       Callee-saved xmm-регистров в System V нет вообще (в Windows x64 — есть).
#    2. Целочисленные callee-saved (rbx, r12..r15) можно использовать для
#       f, n, i — но их нужно сохранить в прологе и восстановить в эпилоге.
#    3. Перед `call` rsp должен быть кратен 16. При входе в функцию
#       rsp ≡ 8 (mod 16) (адрес возврата). Посчитайте push'и и sub rsp.
#
#  Подсказка по раскладке (можно иначе):
#      push rbx; push r12; push r13         ; 3*8 + 8 (ret) = 32 — кратно 16
#      sub rsp, 32                          ; [rsp]=a, [rsp+8]=h, [rsp+16]=sum
#      ...                                  ; итого кратно 16 — можно звать
#      add rsp, 32; pop r13; pop r12; pop rbx; ret
#
#  Для (i + 0.5): cvtsi2sd xmm0, i; addsd с константой 0.5 из .rodata.
#
#  ЗАДАЧА: напишите integrate(f /*rdi*/, a /*xmm0*/, b /*xmm1*/, n /*rsi*/).
#  f должна вызываться ровно n раз. Ожидаемый вывод — в checks/.
#
    .intel_syntax noprefix
    .section .rodata
    .p2align 3
half:
    .double 0.5

    .text
    .globl integrate
integrate:
    push rbx
    push r12
    push r13
    sub rsp, 32
    mov rbx, rdi            # f
    mov r12, rsi            # n
    xor r13d, r13d          # i
    movsd qword ptr [rsp], xmm0         # a
    subsd xmm1, xmm0
    xorps xmm2, xmm2
    cvtsi2sd xmm2, rsi
    divsd xmm1, xmm2
    movsd qword ptr [rsp + 8], xmm1     # h
    xorps xmm0, xmm0
    movsd qword ptr [rsp + 16], xmm0    # sum = 0
    jmp 2f
1:
    xorps xmm0, xmm0
    cvtsi2sd xmm0, r13
    addsd xmm0, qword ptr [rip + half]
    mulsd xmm0, qword ptr [rsp + 8]
    addsd xmm0, qword ptr [rsp]
    call rbx
    addsd xmm0, qword ptr [rsp + 16]
    movsd qword ptr [rsp + 16], xmm0
    inc r13
2:
    cmp r13, r12
    jl 1b
    movsd xmm0, qword ptr [rsp + 16]
    mulsd xmm0, qword ptr [rsp + 8]
    add rsp, 32
    pop r13
    pop r12
    pop rbx
    ret

    .section .note.GNU-stack,"",@progbits
