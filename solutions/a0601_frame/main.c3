// Тестовый стенд упражнения a0601. НЕ редактируйте этот файл и abi_check.s —
// правьте frame.s.
import std::io;

extern fn long abi_call(void* f, long a, long b, long c, long d);
extern fn long abi_errors();
extern fn long asm_locals(long a, long b, long c);
extern fn long asm_seventh(long a, long b, long c, long d, long e, long f, long g);

fn void main()
{
    long r = abi_call(&asm_locals, 1, 20, 300, 0);
    assert(abi_errors() == 0, "asm_locals нарушила ABI: код %d", abi_errors());
    assert(r == 1 * 100 + 20 * 10 + 300, "asm_locals = %d", r);
    long g = asm_seventh(1, 2, 3, 4, 5, 6, 777);
    assert(g == 777, "asm_seventh = %d", g);
    io::printfn("locals=%d seventh=%d", r, g);
}
