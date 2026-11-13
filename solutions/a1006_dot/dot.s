# =====================================================================
#  a1006 · Скалярное произведение на AVX2: несколько аккумуляторов
# =====================================================================
#
#  Финал главы: функция целиком.
#
#      float dot_f32(float* a, float* b, long n)   = сумма a[i] * b[i]
#
#  Требования:
#    * основной цикл — по 16 элементов за итерацию, ДВА аккумулятора ymm
#      (ymm0 и ymm1) с vfmadd231ps. Почему два: у FMA задержка ~4 такта,
#      а запускать их процессор может 2 за такт. С одним аккумулятором
#      каждая итерация ждёт предыдущую (цепочка зависимостей), с двумя —
#      две цепочки идут параллельно. Подробно — в главе 14;
#    * затем, если осталось >= 8, — ещё один шаг по 8;
#    * сложить аккумуляторы, свернуть ymm -> xmm:
#          vextractf128 xmm2, ymm0, 1      # старшие 128 бит
#          vaddps xmm0, xmm0, xmm2
#      и горизонтальная сумма 4 float, как в a1002 (vmovhlps/vshufps/vaddss);
#    * скалярный хвост (vfmadd231ss);
#    * vzeroupper перед ret.
#
#  В тестах значения — небольшие целые, поэтому любой порядок суммирования
#  даёт точно тот же результат.
#
#  ЗАДАЧА: напишите dot_f32(a /*rdi*/, b /*rsi*/, n /*rdx*/).
#
    .intel_syntax noprefix
    .text
    .globl dot_f32
dot_f32:
    vxorps xmm0, xmm0, xmm0
    vxorps xmm1, xmm1, xmm1
    xor eax, eax
    lea rcx, [rdx - 15]
    jmp 2f
1:
    vmovups ymm2, [rdi + rax*4]
    vfmadd231ps ymm0, ymm2, [rsi + rax*4]
    vmovups ymm3, [rdi + rax*4 + 32]
    vfmadd231ps ymm1, ymm3, [rsi + rax*4 + 32]
    add rax, 16
2:
    cmp rax, rcx
    jl 1b
    lea rcx, [rdx - 7]
    cmp rax, rcx
    jge 3f
    vmovups ymm2, [rdi + rax*4]
    vfmadd231ps ymm0, ymm2, [rsi + rax*4]
    add rax, 8
3:
    vaddps ymm0, ymm0, ymm1
    vextractf128 xmm2, ymm0, 1
    vaddps xmm0, xmm0, xmm2
    vmovhlps xmm1, xmm1, xmm0
    vaddps xmm0, xmm0, xmm1
    vshufps xmm1, xmm0, xmm0, 1
    vaddss xmm0, xmm0, xmm1
    jmp 5f
4:
    vmovss xmm2, [rdi + rax*4]
    vfmadd231ss xmm0, xmm2, [rsi + rax*4]
    inc rax
5:
    cmp rax, rdx
    jl 4b
    vzeroupper
    ret

    .section .note.GNU-stack,"",@progbits
