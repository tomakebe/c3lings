// Тестовый стенд упражнения a0202. НЕ редактируйте этот файл — правьте imul.s.
import std::io;

extern fn long asm_poly(long x);
extern fn long asm_area(long w, long h);

fn long ref_poly(long x) => 3 * x * x + 2 * x + 1;

fn void main()
{
    long[*] xs = { 0, 1, 2, -3, 10, 1000000 };
    foreach (x : xs)
    {
        assert(asm_poly(x) == ref_poly(x), "asm_poly(%d) = %d, ожидалось %d", x, asm_poly(x), ref_poly(x));
    }
    assert(asm_area(7, 6) == 42, "asm_area(7,6) = %d", asm_area(7, 6));
    assert(asm_area(-3, 100000) == -300000, "asm_area(-3,100000) = %d", asm_area(-3, 100000));
    io::printfn("poly(2)=%d poly(-3)=%d area=%d", asm_poly(2), asm_poly(-3), asm_area(7, 6));
}
