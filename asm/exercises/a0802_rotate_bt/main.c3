// Драйвер упражнения a0802. Этот файл НЕ нужно править — правьте bits.s.
import std::io;

extern fn ulong rotl64(ulong x, ulong n);
extern fn ulong rotr64(ulong x, ulong n);
extern fn CInt bitset_test(ulong* set, ulong i);
extern fn CInt bitset_set(ulong* set, ulong i);
extern fn CInt bitset_clear(ulong* set, ulong i);

fn void main()
{
    assert(rotl64(1, 1) == 2);
    assert(rotl64(0x8000_0000_0000_0001UL, 4) == 0x18);
    assert(rotr64(0x18, 4) == 0x8000_0000_0000_0001UL);
    assert(rotr64(rotl64(0x0123_4567_89AB_CDEFUL, 20), 20) == 0x0123_4567_89AB_CDEFUL);
    io::printfn("rotl64(0x8000000000000001, 4) = 0x%X", rotl64(0x8000_0000_0000_0001UL, 4));
    io::printfn("rotr64(0x1234, 8)             = 0x%X", rotr64(0x1234, 8));

    ulong[4] set;   // 256 бит
    assert(bitset_set(&set, 0) == 0);
    assert(bitset_set(&set, 63) == 0);
    assert(bitset_set(&set, 64) == 0);
    assert(bitset_set(&set, 200) == 0);
    assert(bitset_set(&set, 200) == 1);      // уже был установлен
    assert(bitset_test(&set, 63) == 1);
    assert(bitset_test(&set, 62) == 0);
    assert(bitset_test(&set, 200) == 1);
    assert(bitset_clear(&set, 63) == 1);
    assert(bitset_clear(&set, 63) == 0);
    assert(bitset_test(&set, 63) == 0);
    foreach (i, w : set) io::printfn("set[%d] = 0x%016X", i, w);
    io::printn("bitset ok");
}
