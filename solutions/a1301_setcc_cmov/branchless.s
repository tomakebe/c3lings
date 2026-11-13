# =====================================================================
#  a1301 · Код без ветвлений: cmov и setcc
# =====================================================================
#
#  Условный переход (jcc) — ставка: процессор УГАДЫВАЕТ направление и
#  выполняет код дальше, не дожидаясь сравнения. Угадал — переход почти
#  бесплатен. Не угадал — весь начатый конвейер выбрасывается: ~15-20
#  тактов штрафа. Для случайных данных (50/50) это очень дорого.
#
#  Альтернатива — вычислить результат без перехода:
#
#      cmovCC dst, src   — если условие CC истинно, dst = src (иначе dst не меняется)
#      setCC  r8         — r8 = условие ? 1 : 0   (только 8-битный регистр!)
#
#  CC — те же условия, что у jcc: e/ne, l/le/g/ge (знаковые), b/be/a/ae
#  (беззнаковые), s/ns, o/no, p/np.
#
#      ; long max(long a, long b)
#      mov   rax, rdi
#      cmp   rdi, rsi
#      cmovl rax, rsi        ; если a < b, взять b
#
#  Особенности:
#    * cmov не умеет непосредственный операнд: `cmovl rax, 0` нельзя —
#      сначала положите 0 в регистр;
#    * cmov с памятью ЧИТАЕТ память всегда, даже если условие ложно
#      (может упасть на плохом указателе!);
#    * setCC пишет только младший байт: обнулите регистр ЗАРАНЕЕ
#      (`xor eax, eax` до cmp — после cmp xor испортит флаги) или movzx;
#    * знак числа: (x > 0) - (x < 0) — два setcc и вычитание.
#
#  ЗАДАЧА: напишите функции без единого условного перехода.
#      bl_max(a, b), bl_abs(x), bl_sign(x) (-1/0/1), bl_clamp(x, lo, hi)
#
    .intel_syntax noprefix
    .text

# long bl_max(long a /*rdi*/, long b /*rsi*/)
    .globl bl_max
bl_max:
    mov rax, rdi
    cmp rdi, rsi
    cmovl rax, rsi
    ret

# long bl_abs(long x)
    .globl bl_abs
bl_abs:
    mov rax, rdi
    neg rax                 # rax = -x, SF = знак -x
    cmovs rax, rdi
    ret

# CInt bl_sign(long x)
    .globl bl_sign
bl_sign:
    xor eax, eax
    xor ecx, ecx
    test rdi, rdi
    setg al
    setl cl
    sub eax, ecx
    ret

# long bl_clamp(long x, long lo, long hi)
    .globl bl_clamp
bl_clamp:
    mov rax, rdi
    cmp rax, rsi
    cmovl rax, rsi
    cmp rax, rdx
    cmovg rax, rdx
    ret

    .section .note.GNU-stack,"",@progbits
