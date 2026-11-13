# =====================================================================
#  a1302 · Branchless-алгоритмы: подсчёт и бинарный поиск
# =====================================================================
#
#  1. Подсчёт элементов меньше pivot. Ветвление «if (a[i] < p) count++»
#     на случайных данных угадывается в половине случаев. Без ветвления:
#
#         cmp   dword ptr [rdi + rcx*4], edx
#         setl  r8b
#         add   rax, r8          ; (r8 обнулён заранее, вне цикла,
#                                 ;  setl меняет только младший байт)
#
#     Ещё изящнее — флаг переноса: после `cmp a, p` CF = 1, если a < p
#     БЕЗЗНАКОВО. Для знакового сравнения так нельзя — используйте setl.
#
#  2. Бинарный поиск (lower_bound — первый индекс i, где a[i] >= key).
#     Классическая версия ветвится на каждом шаге случайным образом.
#     Branchless-версия (см. статьи Paul Khuong, «Array layouts for
#     comparison-based searching»):
#
#         base = 0; len = n
#         while (len > 1) {
#             half = len / 2
#             if (a[base + half - 1] < key) base += half   // <- cmov
#             len -= half
#         }
#         if (len == 1 && a[base] < key) base++            // последний шаг
#         return base
#
#     Каждая итерация выполняется одинаково, переходов по данным нет —
#     только цикл, число итераций которого = log2(n) (и предсказывается
#     идеально). На больших массивах её ещё ускоряют prefetch'ем.
#
#  ЗАДАЧА:
#      count_less(a, n, pivot)  — без ветвлений в теле цикла
#      lower_bound(a, n, key)   — по схеме выше, с cmov
#
    .intel_syntax noprefix
    .text

# long count_less(int* a /*rdi*/, long n /*rsi*/, int pivot /*edx*/)
    .globl count_less
count_less:
    xor eax, eax
    xor ecx, ecx
    xor r8d, r8d
    jmp 2f
1:
    cmp dword ptr [rdi + rcx*4], edx
    setl r8b
    add rax, r8
    inc rcx
2:
    cmp rcx, rsi
    jl 1b
    ret

# long lower_bound(int* a /*rdi*/, long n /*rsi*/, int key /*edx*/)
    .globl lower_bound
lower_bound:
    xor eax, eax            # base
    test rsi, rsi
    jz 9f
    jmp 2f
1:
    mov rcx, rsi
    shr rcx, 1              # half
    lea r8, [rax + rcx]     # base + half
    cmp dword ptr [rdi + r8*4 - 4], edx
    cmovl rax, r8           # a[base+half-1] < key  =>  base += half
    sub rsi, rcx            # len -= half
2:
    cmp rsi, 1
    jg 1b
    # len == 1
    lea r8, [rax + 1]
    cmp dword ptr [rdi + rax*4], edx
    cmovl rax, r8
9:
    ret

    .section .note.GNU-stack,"",@progbits
