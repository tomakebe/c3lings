# =====================================================================
#  a0604 · Рекурсия с двумя вызовами: Фибоначчи
# =====================================================================
#
#      fib(n) = n < 2 ? n : fib(n - 1) + fib(n - 2)
#
#  Теперь между двумя рекурсивными вызовами нужно хранить ДВА значения:
#  n (для второго вызова) и результат первого вызова (чтобы сложить).
#  Значит, два callee-saved регистра, например rbx и r12:
#
#      push rbx
#      push r12
#      sub rsp, 8          # два push — чётное число — доравниваем
#      ...
#      add rsp, 8
#      pop r12
#      pop rbx
#
#  Альтернатива — кадр с rbp и локальными переменными [rbp - 8],
#  [rbp - 16]. Компилятор на -O0 делает именно так.
#
#  Такое дерево вызовов экспоненциально (fib(25) — это ~250 тысяч
#  вызовов), так что ошибка в сохранении регистров проявится быстро.
#  Тестовый стенд проверит, что вы вернули rbx/r12 на место.
#
#  Полезный приём для отладки рекурсии в gdb:
#      gdb ./.build/a0604_fib
#      (gdb) break asm_fib
#      (gdb) run
#      (gdb) info registers rdi rbx r12 rsp
#      (gdb) backtrace         # цепочка вызовов
#      (gdb) continue
#
#  ЗАДАЧА: напишите asm_fib целиком. Программа напечатает
#      fib(10)=55 fib(25)=75025
#
    .intel_syntax noprefix
    .text

    .globl asm_fib
asm_fib:
    cmp rdi, 2
    jae .Lrec
    mov rax, rdi
    ret
.Lrec:
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi            # n
    lea rdi, [rbx - 1]
    call asm_fib
    mov r12, rax            # fib(n - 1)
    lea rdi, [rbx - 2]
    call asm_fib
    add rax, r12
    add rsp, 8
    pop r12
    pop rbx
    ret

    .section .note.GNU-stack,"",@progbits
