// Тестовый стенд упражнения a0403. НЕ редактируйте этот файл — правьте lea.s.
import std::io;

extern fn int* asm_addr_of(int* base, long i);
extern fn long asm_mul5(long x);
extern fn long asm_mul9_plus7(long x);
extern fn long asm_mul10(long x);

fn void main()
{
    int[10] a;
    assert(asm_addr_of(&a, 0) == &a[2], "asm_addr_of(a, 0) должен быть &a[2]");
    assert(asm_addr_of(&a, 5) == &a[7], "asm_addr_of(a, 5) должен быть &a[7]");
    assert(asm_addr_of(&a[4], -3) == &a[3], "asm_addr_of(&a[4], -3) должен быть &a[3]");
    long[*] xs = { 0, 1, -2, 123456789 };
    foreach (x : xs)
    {
        assert(asm_mul5(x) == x * 5, "asm_mul5(%d) = %d", x, asm_mul5(x));
        assert(asm_mul9_plus7(x) == x * 9 + 7, "asm_mul9_plus7(%d) = %d", x, asm_mul9_plus7(x));
        assert(asm_mul10(x) == x * 10, "asm_mul10(%d) = %d", x, asm_mul10(x));
    }
    io::printfn("offset=%d mul5=%d mul9_plus7=%d mul10=%d",
                (long)asm_addr_of(&a, 5) - (long)&a, asm_mul5(7), asm_mul9_plus7(7), asm_mul10(7));
}
