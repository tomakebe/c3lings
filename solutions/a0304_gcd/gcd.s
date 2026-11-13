# =====================================================================
#  a0304 · Алгоритм Евклида
# =====================================================================
#
#      while (b != 0) { t = a % b; a = b; b = t; }
#      return a;
#
#  Это цикл «с проверкой в начале» (while): если b == 0 сразу, тело
#  не выполняется ни разу. Шаблон:
#
#      .Ltop:
#          test rsi, rsi
#          jz   .Lend
#          ...тело...
#          jmp  .Ltop
#      .Lend:
#
#  (Компилятор обычно переставит его в «проверка до цикла + do-while»,
#  чтобы на каждой итерации был один переход вместо двух — сравните
#  с a0303.)
#
#  Внутри: остаток от деления — в rdx после `div`. Помните, что div
#  делит пару rdx:rax, а значит, rdx надо обнулять ПЕРЕД каждым div.
#
#  НОК: lcm(a, b) = a / gcd(a, b) * b. Делите ДО умножения, чтобы не
#  переполниться. Вызывать asm_gcd из asm_lcm мы научимся в главе 05,
#  а пока просто повторите цикл (или прыгните на общий код).
#  Считайте, что для lcm оба числа > 0.
#
#  ЗАДАЧА: напишите asm_gcd и asm_lcm. Программа напечатает
#      gcd(1071,462)=21 gcd(0,5)=5 lcm(4,6)=12
#
    .intel_syntax noprefix
    .text

    .globl asm_gcd
asm_gcd:
.Lgcd_top:
    test rsi, rsi
    jz .Lgcd_end
    mov rax, rdi
    xor edx, edx
    div rsi                 # rdx = a % b
    mov rdi, rsi            # a = b
    mov rsi, rdx            # b = t
    jmp .Lgcd_top
.Lgcd_end:
    mov rax, rdi
    ret

    .globl asm_lcm
asm_lcm:
    mov r8, rdi             # r8 = a
    mov r9, rsi             # r9 = b
.Llcm_top:
    test rsi, rsi
    jz .Llcm_end
    mov rax, rdi
    xor edx, edx
    div rsi
    mov rdi, rsi
    mov rsi, rdx
    jmp .Llcm_top
.Llcm_end:                  # rdi = gcd(a, b)
    mov rax, r8
    xor edx, edx
    div rdi                 # a / gcd
    imul rax, r9            # * b
    ret

    .section .note.GNU-stack,"",@progbits
