// =====================================================================
//  004 · Integers
// =====================================================================
//
//  In C the size of `int` and `long` depends on the platform. In C3
//  integer types have a FIXED size on every platform:
//
//      signed        unsigned        bits
//      ichar         char              8
//      short         ushort           16
//      int           uint             32
//      long          ulong            64
//      int128        uint128         128
//
//  Note: `char` in C3 is an UNsigned byte (0..255), and the signed byte
//  is called `ichar`. In C the signedness of `char` depended on the
//  compiler.
//
//  There are also two "pointer-sized" types (64 bits on a 64-bit
//  platform): `usz` — an unsigned size (like `size_t`), used to measure
//  array lengths; `sz` — its signed counterpart (like `ptrdiff_t`).
//
//  Type properties are accessed via `::` :
//      int::size   — size in bytes (4)
//      int::max    — the largest value
//      int::min    — the smallest value
//
//  LITERALS
//      1_000_000       underscores for readability (ignored)
//      0xFF            hexadecimal
//      0b1010          binary (C didn't have this for a long time)
//      0o755           octal — PAY ATTENTION to the `0o`!
//      10u, 10L, 10UL  suffixes: uint, long, ulong (`ll`/`ull` — 128 bits)
//
//  A TRAP FOR C PROGRAMMERS: in C, `0755` means the octal number 493.
//  In C3 this form was removed, and a leading zero simply means
//  nothing: `0755` == 755 (decimal!). For octal numbers always write
//  `0o755`.
//
//  A decimal literal has type `int` by default. If a number doesn't
//  fit into the variable's type, the compiler refuses to silently
//  truncate it: "The value ... is out of range for 'int'". Pick a
//  wider type.
//
//  TASK: fix the three places marked with `// <-`. The program should
//  print:
//
//      sizes: 1 2 4 8 16
//      byte range: 0..255, ichar range: -128..127
//      population: 8100000000
//      perms: 493
//      flags: 10
//
import std::io;

fn void main()
{
    io::printfn("sizes: %d %d %d %d %d",
                char::size, short::size, int::size, long::size, int128::size);
    io::printfn("byte range: %d..%d, ichar range: %d..%d",
                char::min, char::max, ichar::min, ichar::max);

    long population = 8_100_000_000;
    io::printfn("population: %d", population);

    int perms = 0o755;
    assert(perms == 493);
    io::printfn("perms: %d", perms);

    uint flags = 0b0000_1010;
    assert(flags == 10);
    io::printfn("flags: %d", flags);
}
