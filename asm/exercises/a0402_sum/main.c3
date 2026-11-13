// Тестовый стенд упражнения a0402. НЕ редактируйте этот файл — правьте sum.s.
import std::io;

extern fn long asm_sum(int* a, usz n);
extern fn int asm_max_elem(int* a, usz n);

fn void main()
{
    int[8] a = { 5, -3, 2_000_000_000, 2_000_000_000, -7, 11, 0, 1 };
    long expect = 0;
    foreach (x : a) expect += x;
    assert(asm_sum(&a, 8) == expect, "asm_sum = %d, ожидалось %d", asm_sum(&a, 8), expect);
    assert(asm_sum(&a, 2) == 2, "asm_sum(a, 2) = %d", asm_sum(&a, 2));
    assert(asm_sum(&a, 0) == 0, "asm_sum(a, 0) = %d", asm_sum(&a, 0));
    int[5] neg = { -9, -4, -100, -5, -6 };
    assert(asm_max_elem(&neg, 5) == -4, "asm_max_elem(neg) = %d", asm_max_elem(&neg, 5));
    assert(asm_max_elem(&a, 8) == 2_000_000_000, "asm_max_elem(a) = %d", asm_max_elem(&a, 8));
    assert(asm_max_elem(&a, 2) == 5, "asm_max_elem(a, 2) = %d", asm_max_elem(&a, 2));
    io::printfn("sum=%d max=%d max_neg=%d", asm_sum(&a, 8), asm_max_elem(&a, 8), asm_max_elem(&neg, 5));
}
