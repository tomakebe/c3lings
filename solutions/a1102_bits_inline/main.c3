// =====================================================================
//  a1102 · Inline assembly: bit instructions and operand sizes
// =====================================================================
//
//  The most common reason to write inline assembly is an instruction the
//  language "can't reach" (or one you want to guarantee is used).
//  In an asm block you have popcnt, lzcnt, tzcnt, bswapl/bswapq, pdep, pext,
//  andn, blsr, bzhi, shlx, rorx and others.
//
//  Some instructions have no suffix (popcnt, tzcnt, lzcnt, pdep, pext,
//  rorx): their size is determined by the size of the variables — all
//  operands must be the same size:
//
//      ulong r; ulong x;   asm { popcnt r, x; }       // 64-bit popcnt
//      uint  r; uint  x;   asm { tzcnt r, x; }        // 32-bit tzcnt
//
//  Instructions with a suffix require a match: bswapl — uint, bswapq — ulong.
//
//  The mask constant for pext must be in a register or variable — pext
//  does not accept an immediate operand. Just declare
//  `uint mask = 0x...;` and pass the variable.
//
//  The compiler will figure out on its own that `r` is written, `x` is
//  read, and the flags are clobbered (popcnt changes ZF). Look at the result:
//      c3c compile --emit-asm main.c3     (files in asm/linux-x64/)
//  — between the #APP and #NO_APP markers is your code, already in AT&T syntax.
//
//  TASK: fill in the bodies of the four functions (TODO) using asm blocks.
//
import std::io;

fn ulong popcount64(ulong x)
{
    ulong r;
    asm { popcnt r, x; }
    return r;
}

fn uint trailing_zeros32(uint x)
{
    uint r;
    asm { tzcnt r, x; }
    return r;
}

fn uint byte_swap32(uint x)
{
    asm { bswapl x; }
    return x;
}

// Gather the low bits of all 8 nibbles into an 8-bit number (via pext).
fn uint nibble_lows(uint x)
{
    uint r;
    uint mask = 0x1111_1111;
    asm { pext r, x, mask; }
    return r;
}

fn void main()
{
    assert(popcount64(0) == 0 && popcount64(ulong::max) == 64 && popcount64(0xF0F0) == 8);
    assert(trailing_zeros32(0) == 32 && trailing_zeros32(8) == 3 && trailing_zeros32(0x8000_0000) == 31);
    assert(byte_swap32(0x1122_3344) == 0x4433_2211);
    assert(nibble_lows(0x1010_1111) == 0b1010_1111);
    assert(nibble_lows(0xFFFF_FFFE) == 0b1111_1110);
    io::printfn("popcount64(0xDEADBEEF) = %d", popcount64(0xDEAD_BEEF));
    io::printfn("trailing_zeros32(80)   = %d", trailing_zeros32(80));
    io::printfn("byte_swap32(0x11223344) = 0x%08X", byte_swap32(0x1122_3344));
    io::printfn("nibble_lows(0x10101111) = 0x%02X", nibble_lows(0x1010_1111));
}
