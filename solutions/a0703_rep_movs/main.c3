// Тестовый стенд упражнения a0703. НЕ редактируйте этот файл — правьте rep.s.
import std::io;

extern fn void* asm_memcpy(void* dst, void* src, usz n);
extern fn void* asm_memset(void* dst, int c, usz n);
extern fn void asm_fill32(uint* dst, uint v, usz n);

fn void main()
{
    char[16] src = "abcdefghijklmno";
    char[16] dst;
    dst[..] = '.';
    void* r = asm_memcpy(&dst[2], &src, 5);
    assert(r == &dst[2], "asm_memcpy должна вернуть dst");
    assert(dst[0] == '.' && dst[1] == '.' && dst[7] == '.', "asm_memcpy вышла за границы");
    io::printfn("memcpy: %s", (String)dst[0:15]);
    r = asm_memset(&dst[8], 'Z', 4);
    assert(r == &dst[8], "asm_memset должна вернуть dst");
    io::printfn("memset: %s", (String)dst[0:15]);
    asm_memcpy(&dst, &src, 0);
    uint[6] w;
    asm_fill32(&w[1], 0xDEADBEEF, 4);
    assert(w[0] == 0 && w[5] == 0, "asm_fill32 вышла за границы: %s", w);
    io::printfn("fill32: %x %x %x", w[0], w[1], w[4]);
}
