// Тестовый стенд упражнения a0305. НЕ редактируйте этот файл — правьте collatz.s.
import std::io;

extern fn ulong asm_collatz_steps(ulong n);
extern fn ulong asm_longest_below(ulong limit);

fn ulong ref_steps(ulong n)
{
    ulong s = 0;
    while (n != 1) { n = (n % 2 == 0) ? n / 2 : 3 * n + 1; s++; }
    return s;
}

fn void main()
{
    for (ulong n = 1; n < 200; n++)
    {
        assert(asm_collatz_steps(n) == ref_steps(n), "asm_collatz_steps(%d) = %d, ожидалось %d",
               n, asm_collatz_steps(n), ref_steps(n));
    }
    assert(asm_collatz_steps(837799) == 524, "asm_collatz_steps(837799) = %d", asm_collatz_steps(837799));
    assert(asm_longest_below(10) == 9, "asm_longest_below(10) = %d", asm_longest_below(10));
    assert(asm_longest_below(1000) == 871, "asm_longest_below(1000) = %d", asm_longest_below(1000));
    io::printfn("steps(27)=%d steps(837799)=%d longest_below(1000)=%d longest_below(100000)=%d",
                asm_collatz_steps(27), asm_collatz_steps(837799), asm_longest_below(1000),
                asm_longest_below(100000));
}
