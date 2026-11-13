// Тестовый стенд упражнения a0206. НЕ редактируйте этот файл — правьте mulwide.s.
import std::io;

extern fn ulong asm_mulhi(ulong a, ulong b);
extern fn long asm_imulhi(long a, long b);
extern fn uint128 asm_mul_full(ulong a, ulong b);
extern fn ulong asm_muldiv(ulong a, ulong b, ulong c);

fn void main()
{
    ulong[*] us = { 0, 1, 3, 0xFFFF_FFFF, 0xFFFF_FFFF_FFFF_FFFF, 0x1234_5678_9ABC_DEF0 };
    foreach (a : us)
    {
        foreach (b : us)
        {
            uint128 p = (uint128)a * (uint128)b;
            assert(asm_mulhi(a, b) == (ulong)(p >> 64), "asm_mulhi(%x, %x) = %x", a, b, asm_mulhi(a, b));
            assert(asm_mul_full(a, b) == p, "asm_mul_full(%x, %x)", a, b);
            long sa = (long)a;
            long sb = (long)b;
            int128 sp = (int128)sa * (int128)sb;
            assert(asm_imulhi(sa, sb) == (long)(sp >> 64), "asm_imulhi(%d, %d) = %d", sa, sb, asm_imulhi(sa, sb));
        }
    }
    // a * b / c без переполнения промежуточного результата
    assert(asm_muldiv(0xFFFF_FFFF_FFFF_FFFF, 1000, 1000) == 0xFFFF_FFFF_FFFF_FFFF, "asm_muldiv");
    assert(asm_muldiv(10_000_000_000, 10_000_000_000, 1_000_000_000_000) == 100_000_000, "asm_muldiv");
    io::printfn("mulhi=%x imulhi=%d full_hi=%x muldiv=%d",
        asm_mulhi(0xFFFF_FFFF_FFFF_FFFF, 2), asm_imulhi(-1, 2),
        (ulong)(asm_mul_full(0x1_0000_0000, 0x1_0000_0000) >> 64),
        asm_muldiv(10_000_000_000, 10_000_000_000, 1_000_000_000_000));
}
