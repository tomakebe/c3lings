// Тестовый стенд упражнения a0204. НЕ редактируйте этот файл — правьте adc.s.
import std::io;

extern fn uint128 asm_add128(uint128 a, uint128 b);
extern fn uint128 asm_sub128(uint128 a, uint128 b);

fn void check(uint128 a, uint128 b)
{
    uint128 s = asm_add128(a, b);
    uint128 d = asm_sub128(a, b);
    assert(s == a + b, "asm_add128: hi=%x lo=%x", (ulong)(s >> 64), (ulong)s);
    assert(d == a - b, "asm_sub128: hi=%x lo=%x", (ulong)(d >> 64), (ulong)d);
}

fn void main()
{
    check(1, 2);
    check(0xFFFF_FFFF_FFFF_FFFF, 1);
    check((uint128)5 << 64, 1);
    check(0x1234_5678_9ABC_DEF0_FFFF_FFFF_FFFF_FFFF, 0x0000_0000_0000_0001_8000_0000_0000_0001);
    check(0, 1);
    uint128 s = asm_add128(0xFFFF_FFFF_FFFF_FFFF, 1);
    uint128 d = asm_sub128((uint128)1 << 64, 1);
    io::printfn("add: hi=%x lo=%x", (ulong)(s >> 64), (ulong)s);
    io::printfn("sub: hi=%x lo=%x", (ulong)(d >> 64), (ulong)d);
}
