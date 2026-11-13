Сохраните code и len в callee-saved регистрах (push rbx/r12/r13 в начале — и pop в конце на ВСЕХ путях выхода).
mmap: rdi = 0, rsi = len, rdx = 3, r10 = 0x22, r8 = -1, r9 = 0, eax = 9. Проверка ошибки: `cmp rax, -4096; ja`.
Копирование: rdi = страница, rsi = code, rcx = len, `rep movsb`. Затем mprotect(страница, len, 5) — номер 10.
jit_free: munmap = 11, аргументы уже на месте.
