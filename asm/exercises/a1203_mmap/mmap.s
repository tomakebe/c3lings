# =====================================================================
#  a1203 · Память напрямую у ядра: mmap, mprotect, munmap
# =====================================================================
#
#  Все аллокаторы (malloc, аллокаторы C3, арены движка) в конце концов
#  берут память у ядра страницами (4 КиБ) через mmap:
#
#      void* mmap(void* addr, size_t len, int prot, int flags, int fd, off_t off)
#      номер 9; аргументы: rdi, rsi, rdx, r10 (!), r8, r9
#
#  Для анонимной (не из файла) памяти:
#      addr = 0 (пусть ядро выберет), prot = PROT_READ|PROT_WRITE = 1|2 = 3,
#      flags = MAP_PRIVATE|MAP_ANONYMOUS = 0x02|0x20 = 0x22, fd = -1, off = 0
#
#  ЧЕТВЁРТЫЙ аргумент системного вызова — в r10, а не в rcx: rcx
#  испортит сама инструкция syscall (туда сохраняется rip). Классическая
#  ошибка — положить flags в rcx.
#
#  Ошибка — значение в [-4095, -1] (см. a1202). Удобнее вызывающему
#  вернуть null (как делает, например, VirtualAlloc в Windows; libc mmap
#  возвращает MAP_FAILED = (void*)-1).
#
#      int mprotect(void* addr, size_t len, int prot)   номер 10
#      int munmap(void* addr, size_t len)               номер 11
#  Здесь мы возвращаем «сырой» результат ядра (0 или -errno).
#
#  mprotect понадобится в финальной главе: JIT пишет машинный код в
#  страницу с PROT_READ|PROT_WRITE, а потом меняет её на
#  PROT_READ|PROT_EXEC (W^X — никогда одновременно запись и исполнение).
#
#  ЗАДАЧА: напишите три функции.
#      page_alloc(len)            -> указатель или null при ошибке
#      page_protect(p, len, prot) -> 0 или -errno
#      page_free(p, len)          -> 0 или -errno
#
    .intel_syntax noprefix
    .text

# void* page_alloc(long len /*rdi*/)
    .globl page_alloc
page_alloc:
    # TODO
    xor eax, eax
    ret

# long page_protect(void* p, long len, CInt prot)
    .globl page_protect
page_protect:
    # TODO
    mov rax, -38
    ret

# long page_free(void* p, long len)
    .globl page_free
page_free:
    # TODO
    mov rax, -38
    ret

    .section .note.GNU-stack,"",@progbits
