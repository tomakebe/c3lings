// Тестовый стенд упражнения a0606. НЕ редактируйте этот файл и abi_check.s —
// правьте ackermann.s.
import std::io;

extern fn long abi_call(void* f, long a, long b, long c, long d);
extern fn long abi_errors();
extern fn ulong asm_ack(ulong m, ulong n);

fn ulong ref_ack(ulong m, ulong n)
{
    if (m == 0) return n + 1;
    if (n == 0) return ref_ack(m - 1, 1);
    return ref_ack(m - 1, ref_ack(m, n - 1));
}

fn void main()
{
    for (ulong m = 0; m <= 3; m++)
    {
        for (ulong n = 0; n <= 4; n++)
        {
            ulong r = (ulong)abi_call(&asm_ack, (long)m, (long)n, 0, 0);
            assert(abi_errors() == 0, "asm_ack(%d, %d) нарушила ABI: код %d", m, n, abi_errors());
            assert(r == ref_ack(m, n), "asm_ack(%d, %d) = %d, ожидалось %d", m, n, r, ref_ack(m, n));
        }
    }
    io::printfn("ack(2,3)=%d ack(3,3)=%d ack(3,7)=%d", asm_ack(2, 3), asm_ack(3, 3), asm_ack(3, 7));
}
