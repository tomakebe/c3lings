# =====================================================================
#  a1202 · Ошибки системных вызовов и errno
# =====================================================================
#
#  Ядро Linux сообщает об ошибке, возвращая в rax ОТРИЦАТЕЛЬНЫЙ код:
#  -EBADF (-9), -EFAULT (-14), -EINVAL (-22), -ENOMEM (-12)...
#  Ошибкой считается значение в диапазоне [-4095, -1]; всё остальное —
#  нормальный результат (например, mmap может вернуть «большой» адрес,
#  который как знаковое число отрицателен, но он > -4096).
#
#  libc превращает это в привычное соглашение POSIX:
#      if ((unsigned long)rax > -4096UL) { errno = -rax; return -1; }
#  errno в libc — переменная в TLS (своя у каждого потока). У нас —
#  простая глобальная переменная last_errno, объявленная ниже в .bss.
#
#  Сравнение «беззнаково больше -4096» — одна инструкция:
#      cmp rax, -4096
#      ja  error          # ja — беззнаковое сравнение!
#
#  Обратите внимание: ядро НИКОГДА не трогает errno само — это чисто
#  библиотечная конвенция. И при успехе errno не меняется.
#
#  ЗАДАЧА:
#      checked_write(fd, buf, len) — write; при ошибке last_errno = -rax,
#                                    вернуть -1
#      checked_close(fd)           — close (номер 3), так же
#
    .intel_syntax noprefix
    .bss
    .p2align 2
    .globl last_errno
last_errno:
    .zero 4

    .text

# long checked_write(CInt fd, char* buf, long len)
    .globl checked_write
checked_write:
    mov eax, 1
    syscall
    cmp rax, -4096
    ja set_errno
    ret

# общий хвост: rax = -errno
set_errno:
    neg eax
    mov dword ptr [rip + last_errno], eax
    mov rax, -1
    ret

# long checked_close(CInt fd)
    .globl checked_close
checked_close:
    mov eax, 3
    syscall
    cmp rax, -4096
    ja set_errno
    ret

    .section .note.GNU-stack,"",@progbits
