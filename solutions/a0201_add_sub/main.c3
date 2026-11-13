// Тестовый стенд упражнения a0201. НЕ редактируйте этот файл — правьте add_sub.s.
import std::io;

extern fn long asm_calc(long a, long b, long c);
extern fn long asm_neg(long x);
extern fn long asm_dist(long a, long b);

fn void main()
{
    assert(asm_calc(10, 5, 3) == 12, "asm_calc(10,5,3) = %d", asm_calc(10, 5, 3));
    assert(asm_calc(-100, 1, 1000) == -1099, "asm_calc(-100,1,1000) = %d", asm_calc(-100, 1, 1000));
    assert(asm_neg(42) == -42, "asm_neg(42) = %d", asm_neg(42));
    assert(asm_neg(-7000000000) == 7000000000, "asm_neg(-7000000000) = %d", asm_neg(-7000000000));
    assert(asm_dist(3, 10) == 13 - 2 * 3, "asm_dist(3,10) = %d", asm_dist(3, 10));
    assert(asm_dist(10, 3) == -7, "asm_dist(10,3) = %d", asm_dist(10, 3));
    io::printfn("calc=%d neg=%d dist=%d", asm_calc(10, 5, 3), asm_neg(42), asm_dist(3, 10));
}
