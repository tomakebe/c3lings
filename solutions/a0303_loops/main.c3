// Тестовый стенд упражнения a0303. НЕ редактируйте этот файл — правьте loops.s.
import std::io;

extern fn ulong asm_sum_to(ulong n);
extern fn ulong asm_count_digits(ulong n);

fn void main()
{
    ulong[*] ns = { 0, 1, 2, 10, 100, 12345 };
    foreach (n : ns)
    {
        assert(asm_sum_to(n) == n * (n + 1) / 2, "asm_sum_to(%d) = %d", n, asm_sum_to(n));
    }
    assert(asm_count_digits(0) == 1, "asm_count_digits(0) = %d", asm_count_digits(0));
    assert(asm_count_digits(9) == 1, "asm_count_digits(9) = %d", asm_count_digits(9));
    assert(asm_count_digits(10) == 2, "asm_count_digits(10) = %d", asm_count_digits(10));
    assert(asm_count_digits(12345) == 5, "asm_count_digits(12345) = %d", asm_count_digits(12345));
    assert(asm_count_digits(ulong::max) == 20, "asm_count_digits(ULONG_MAX) = %d", asm_count_digits(ulong::max));
    io::printfn("sum_to(10)=%d sum_to(100)=%d digits=%d %d %d",
                asm_sum_to(10), asm_sum_to(100), asm_count_digits(0), asm_count_digits(12345),
                asm_count_digits(ulong::max));
}
