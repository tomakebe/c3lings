# =====================================================================
#  a0803 · Подсчёт битов: popcnt, lzcnt, tzcnt
# =====================================================================
#
#  Три инструкции «посчитай биты» (все — 1 мкоп, задержка ~1-3 такта):
#
#      popcnt dst, src   — количество единичных битов     (POPCNT)
#      lzcnt  dst, src   — количество ведущих нулей       (LZCNT/ABM)
#      tzcnt  dst, src   — количество хвостовых нулей     (BMI1)
#
#  Для src = 0 lzcnt и tzcnt возвращают ширину операнда (64) и ставят CF.
#
#  Их старые родственники — bsr/bsf (bit scan reverse/forward) — возвращают
#  ИНДЕКС старшего/младшего единичного бита, а при src = 0 оставляют dst
#  НЕОПРЕДЕЛЁННЫМ (на практике — не трогают) и ставят ZF. Связь:
#
#      bsr(x) = 63 - lzcnt(x)       (x != 0)
#      bsf(x) = tzcnt(x)            (x != 0)
#
#  Ловушка: tzcnt кодируется как `rep bsf`. Старый процессор без BMI1
#  молча выполнит его как bsf — с другим результатом для нуля. Поэтому
#  перед использованием BMI/LZCNT проверяют cpuid (у нас — есть всё).
#
#  Ещё ловушка (историческая): на Intel до Cannon Lake у popcnt/lzcnt/tzcnt
#  была «ложная зависимость» от регистра-приёмника. Компиляторы вставляют
#  `xor eax, eax` перед `popcnt rax, rdi`, чтобы её разорвать.
#
#  Полезные формулы:
#      floor(log2(x))   = 63 - lzcnt(x)                      (x >= 1)
#      next_pow2(x)     = 1 << (64 - lzcnt(x - 1))           (x >= 2)
#                         и next_pow2(1) = 1 — особый случай, потому что
#                         lzcnt(0) = 64, а сдвиг на 64 по модулю = сдвиг на 0 —
#                         ...что, внезапно, даёт 1 << 0 = 1. Повезло!
#
#  ЗАДАЧА: допишите функции (TODO).
#      asm_popcount(x), asm_ctz(x) (ctz(0) = 64),
#      asm_log2_floor(x) (x >= 1), asm_next_pow2(x) (x >= 1, x <= 2^63)
#
    .intel_syntax noprefix
    .text

    .globl asm_popcount
asm_popcount:
    xor eax, eax
    popcnt rax, rdi
    ret

    .globl asm_ctz
asm_ctz:
    tzcnt rax, rdi
    ret

    .globl asm_log2_floor
asm_log2_floor:
    lzcnt rcx, rdi
    mov eax, 63
    sub rax, rcx
    ret

    .globl asm_next_pow2
asm_next_pow2:
    lea rax, [rdi - 1]
    lzcnt rcx, rax
    neg ecx                 # 64 - n == -n (mod 64)
    mov eax, 1
    shl rax, cl
    ret

    .section .note.GNU-stack,"",@progbits
