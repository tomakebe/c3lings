// Драйвер упражнения a1203. Этот файл НЕ нужно править — правьте mmap.s.
import std::io;

extern fn void* page_alloc(long len);
extern fn long page_protect(void* p, long len, CInt prot);
extern fn long page_free(void* p, long len);

fn void main()
{
    long len = 3 * 4096;
    char* p = page_alloc(len);
    assert(p != null, "mmap failed");
    assert((uptr)p % 4096 == 0, "mmap returns page-aligned memory");
    // Анонимная память обнулена ядром
    for (long i = 0; i < len; i++) assert(p[i] == 0);
    for (long i = 0; i < len; i++) p[i] = (char)(i * 31);
    long sum = 0;
    for (long i = 0; i < len; i++) sum += p[i];
    io::printfn("checksum = %d", sum);

    assert(page_protect(p, len, 1) == 0);           // PROT_READ: теперь только чтение
    assert(p[100] == (char)(100 * 31));
    assert(page_protect(p + 1, 4096, 1) == -22);    // EINVAL: адрес не выровнен
    assert(page_free(p, len) == 0);
    io::printn("munmap ok");

    assert(page_alloc(0) == null);                   // EINVAL -> null
    io::printn("mmap(0) -> null");
}
