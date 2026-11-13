// Тестовый стенд упражнения a0102. НЕ редактируйте этот файл — правьте args.s.
import std::io;

extern fn long asm_first(long a, long b, long c, long d, long e, long f);
extern fn long asm_second(long a, long b, long c, long d, long e, long f);
extern fn long asm_fourth(long a, long b, long c, long d, long e, long f);
extern fn long asm_sixth(long a, long b, long c, long d, long e, long f);

fn void main()
{
    long r1 = asm_first(10, 20, 30, 40, 50, 60);
    long r2 = asm_second(10, 20, 30, 40, 50, 60);
    long r4 = asm_fourth(10, 20, 30, 40, 50, 60);
    long r6 = asm_sixth(10, 20, 30, 40, 50, 60);
    assert(r1 == 10, "asm_first вернула %d", r1);
    assert(r2 == 20, "asm_second вернула %d", r2);
    assert(r4 == 40, "asm_fourth вернула %d", r4);
    assert(r6 == 60, "asm_sixth вернула %d", r6);
    assert(asm_sixth(-1, -2, -3, -4, -5, -6000000000) == -6000000000, "asm_sixth: нужен весь 64-битный регистр");
    io::printfn("first=%d second=%d fourth=%d sixth=%d", r1, r2, r4, r6);
}
