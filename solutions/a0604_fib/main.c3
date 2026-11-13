// Тестовый стенд упражнения a0604. НЕ редактируйте этот файл и abi_check.s —
// правьте fib.s.
import std::io;

extern fn long abi_call(void* f, long a, long b, long c, long d);
extern fn long abi_errors();
extern fn ulong asm_fib(ulong n);

fn void main()
{
    ulong a = 0;
    ulong b = 1;
    for (ulong n = 0; n <= 25; n++)
    {
        ulong r = (ulong)abi_call(&asm_fib, (long)n, 0, 0, 0);
        assert(abi_errors() == 0, "asm_fib(%d) нарушила ABI: код %d", n, abi_errors());
        assert(r == a, "asm_fib(%d) = %d, ожидалось %d", n, r, a);
        ulong t = a + b; a = b; b = t;
    }
    io::printfn("fib(10)=%d fib(25)=%d", asm_fib(10), asm_fib(25));
}
