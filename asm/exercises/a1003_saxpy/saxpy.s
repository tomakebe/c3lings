# =====================================================================
#  a1003 · AVX2 + FMA: saxpy и vzeroupper
# =====================================================================
#
#  AVX удвоил ширину: регистры ymm0..ymm15 по 256 бит (8 float).
#  Младшая половина ymmN — это xmmN. Инструкции — с префиксом v и
#  трёхоперандные (источники не портятся):
#
#      vmovups ymm0, [rdi]            8 float из памяти (без выравнивания)
#      vaddps  ymm0, ymm1, ymm2       ymm0 = ymm1 + ymm2
#      vbroadcastss ymm1, xmm0        все 8 элементов = xmm0[0]
#      vfmadd231ps ymm0, ymm1, ymm2   ymm0 = ymm1 * ymm2 + ymm0  (FMA3)
#
#  Цифры в vfmadd — номера операндов: «231» значит op2*op3 + op1.
#  Есть 132 и 213. FMA округляет ОДИН раз, поэтому результат может
#  отличаться от mul+add в последнем бите (здесь — целые числа, всё точно).
#  FMA — отдельный флаг cpuid (`fma` в /proc/cpuinfo), не часть AVX2.
#
#  vzeroupper. Если функция использовала ymm, перед возвратом обязательно
#  `vzeroupper` — обнулить старшие половины всех ymm. Иначе старый
#  (не-VEX) SSE-код в вызывающей программе может замедлиться в разы
#  (переходы состояний на Intel, ложные зависимости на Skylake+).
#  Компиляторы вставляют vzeroupper перед каждым ret и call.
#
#  saxpy — «single-precision a*x plus y», классика BLAS:
#      y[i] = a * x[i] + y[i],  i = 0..n-1
#
#  Схема: основной цикл по 8 элементов (ymm), затем хвост скалярно
#  (vfmadd231ss xmm..., или vmulss+vaddss).
#
#  ЗАДАЧА: напишите saxpy(n /*rdi*/, a /*xmm0*/, x /*rsi*/, y /*rdx*/)
#  для любого n >= 0. Не забудьте vzeroupper.
#
    .intel_syntax noprefix
    .text
    .globl saxpy
saxpy:
    # TODO: целиком
    ret

    .section .note.GNU-stack,"",@progbits
