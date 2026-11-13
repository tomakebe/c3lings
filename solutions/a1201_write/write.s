# =====================================================================
#  a1201 · Системный вызов write
# =====================================================================
#
#  Всё, что программа делает с внешним миром (файлы, экран, память,
#  потоки), в итоге идёт через ядро — системные вызовы. libc и стандартная
#  библиотека C3 — лишь обёртки. На x86-64 Linux вызов делается
#  инструкцией `syscall`:
#
#      rax  — номер вызова (write = 1, read = 0, exit_group = 231, ...)
#      rdi, rsi, rdx, r10, r8, r9 — аргументы 1..6
#           (внимание: 4-й — r10, а НЕ rcx, как в обычных функциях!)
#      результат — в rax
#      syscall портит rcx (туда пишется адрес возврата) и r11 (rflags).
#      Остальные регистры ядро сохраняет.
#
#  ssize_t write(int fd, const void* buf, size_t count)
#      fd 1 — stdout. Возвращает число записанных байтов.
#
#  Номера вызовов — в /usr/include/asm/unistd_64.h или `ausyscall --dump`.
#
#  Аргументы нашей функции sys_write(fd, buf, len) уже лежат в rdi, rsi,
#  rdx — ровно там, где их ждёт ядро. Осталось номер и сама инструкция.
#
#  ЗАДАЧА:
#      sys_write(fd, buf, len)  — прямой вызов write
#      write_cstr(s)            — записать в stdout строку, оканчивающуюся
#                                 нулём (длину посчитайте сами), вернуть
#                                 результат write
#
    .intel_syntax noprefix
    .text

# long sys_write(CInt fd /*edi*/, char* buf /*rsi*/, long len /*rdx*/)
    .globl sys_write
sys_write:
    mov eax, 1
    syscall
    ret

# long write_cstr(char* s /*rdi*/)
    .globl write_cstr
write_cstr:
    xor edx, edx
1:
    cmp byte ptr [rdi + rdx], 0
    je 2f
    inc rdx
    jmp 1b
2:
    mov rsi, rdi
    mov edi, 1
    mov eax, 1
    syscall
    ret

    .section .note.GNU-stack,"",@progbits
