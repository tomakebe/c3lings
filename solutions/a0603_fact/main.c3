// Тестовый стенд упражнения a0603. НЕ редактируйте этот файл и abi_check.s —
// правьте fact.s.
import std::io;

extern fn long abi_call(void* f, long a, long b, long c, long d);
extern fn long abi_errors();
extern fn ulong asm_fact(ulong n);

fn void main()
{
    ulong expect = 1;
    for (ulong n = 0; n <= 20; n++)
    {
        if (n > 0) expect *= n;
        ulong r = (ulong)abi_call(&asm_fact, (long)n, 0, 0, 0);
        assert(abi_errors() == 0, "asm_fact(%d) нарушила ABI: код %d", n, abi_errors());
        assert(r == expect, "asm_fact(%d) = %d, ожидалось %d", n, r, expect);
    }
    io::printfn("fact(5)=%d fact(20)=%d", asm_fact(5), asm_fact(20));
}
