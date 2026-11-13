// Тестовый стенд упражнения a0304. НЕ редактируйте этот файл — правьте gcd.s.
import std::io;

extern fn ulong asm_gcd(ulong a, ulong b);
extern fn ulong asm_lcm(ulong a, ulong b);

fn ulong ref_gcd(ulong a, ulong b)
{
    while (b != 0) { ulong t = a % b; a = b; b = t; }
    return a;
}

fn void main()
{
    ulong[*] xs = { 0, 1, 6, 12, 35, 49, 1071, 462, 0xFFFF_FFFF_FFFF_FFFE };
    foreach (a : xs)
    {
        foreach (b : xs)
        {
            assert(asm_gcd(a, b) == ref_gcd(a, b), "asm_gcd(%d, %d) = %d", a, b, asm_gcd(a, b));
        }
    }
    assert(asm_lcm(4, 6) == 12, "asm_lcm(4,6) = %d", asm_lcm(4, 6));
    assert(asm_lcm(21, 6) == 42, "asm_lcm(21,6) = %d", asm_lcm(21, 6));
    assert(asm_lcm(1_000_000_007, 998_244_353) == 998_244_359_987_710_471, "asm_lcm big = %d", asm_lcm(1_000_000_007, 998_244_353));
    io::printfn("gcd(1071,462)=%d gcd(0,5)=%d lcm(4,6)=%d", asm_gcd(1071, 462), asm_gcd(0, 5), asm_lcm(4, 6));
}
