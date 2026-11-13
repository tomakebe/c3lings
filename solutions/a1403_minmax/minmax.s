# =====================================================================
#  a1403 · Развёртка + branchless: минимум и максимум за один проход
# =====================================================================
#
#  Функция целиком. Наивный вариант с ветвлениями на случайных данных
#  ошибается в предсказании: «новый минимум» встречается всё реже, но
#  не регулярно. Branchless-вариант с cmov не ошибается никогда, но
#  создаёт цепочку зависимостей: каждый cmovl зависит от предыдущего
#  минимума (cmp + cmov = 2 такта на элемент на одну цепочку).
#
#  Поэтому разделите и здесь: развёртка на 2 элемента и ДВЕ пары
#  аккумуляторов (min0/max0 для чётных, min1/max1 для нечётных), а в
#  конце — объединение. Так длина цепочки на элемент уменьшается вдвое.
#
#  (А совсем быстро — SIMD: pminsd/pmaxsd по 4-8 элементов. Можете
#  попробовать после того, как сделаете скалярную версию.)
#
#  ЗАДАЧА: minmax(a /*rdi*/, n /*rsi*/, out_min /*rdx*/, out_max /*rcx*/),
#  n >= 1. Записать минимум в *out_min и максимум в *out_max.
#  Никаких условных переходов внутри тела цикла (переход цикла — можно).
#
    .intel_syntax noprefix
    .text
    .globl minmax
minmax:
    push rbx
    mov r11, rcx                # out_max (rcx понадобится под индекс)
    mov eax, [rdi]              # min0
    mov r8d, eax                # max0
    mov r9d, eax                # min1
    mov r10d, eax               # max1
    mov ecx, 1                  # i
    lea rbx, [rsi - 1]          # пока i < n - 1 — есть пара
    jmp 2f
1:
    mov esi, [rdi + rcx*4]
    cmp esi, eax
    cmovl eax, esi
    cmp esi, r8d
    cmovg r8d, esi
    mov esi, [rdi + rcx*4 + 4]
    cmp esi, r9d
    cmovl r9d, esi
    cmp esi, r10d
    cmovg r10d, esi
    add rcx, 2
2:
    cmp rcx, rbx
    jl 1b
    # объединить пары
    cmp r9d, eax
    cmovl eax, r9d
    cmp r10d, r8d
    cmovg r8d, r10d
    # хвост: не более одного элемента
    cmp rcx, rbx
    jne 3f
    mov esi, [rdi + rcx*4]
    cmp esi, eax
    cmovl eax, esi
    cmp esi, r8d
    cmovg r8d, esi
3:
    mov [rdx], eax
    mov [r11], r8d
    pop rbx
    ret

    .section .note.GNU-stack,"",@progbits
