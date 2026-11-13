// =====================================================================
//  a1102 · Inline-ассемблер: битовые инструкции и размеры операндов
// =====================================================================
//
//  Самый частый повод писать inline-ассемблер — инструкция, до которой
//  язык «не дотягивается» (или вы хотите гарантировать именно её).
//  В блоке asm доступны popcnt, lzcnt, tzcnt, bswapl/bswapq, pdep, pext,
//  andn, blsr, bzhi, shlx, rorx и другие.
//
//  У части инструкций суффикса нет (popcnt, tzcnt, lzcnt, pdep, pext,
//  rorx): их размер определяется размером переменных — все операнды
//  должны быть одного размера:
//
//      ulong r; ulong x;   asm { popcnt r, x; }       // 64-битный popcnt
//      uint  r; uint  x;   asm { tzcnt r, x; }        // 32-битный tzcnt
//
//  Инструкции с суффиксом требуют совпадения: bswapl — uint, bswapq — ulong.
//
//  Константа-маска для pext должна быть в регистре или переменной —
//  непосредственный операнд pext не принимает. Просто объявите
//  `uint mask = 0x...;` и передайте переменную.
//
//  Компилятор сам поймёт, что `r` пишется, а `x` читается, и что флаги
//  портятся (popcnt меняет ZF). Посмотрите на результат:
//      c3c compile --emit-asm main.c3     (файлы в asm/linux-x64/)
//  — между маркерами #APP и #NO_APP будет ваш код, уже в AT&T-синтаксисе.
//
//  ЗАДАЧА: допишите тела четырёх функций (TODO), используя блоки asm.
//
import std::io;

fn ulong popcount64(ulong x)
{
    ulong r;
    // TODO
    return r;
}

fn uint trailing_zeros32(uint x)
{
    uint r;
    // TODO (tzcnt; для x == 0 должно получиться 32)
    return r;
}

fn uint byte_swap32(uint x)
{
    // TODO
    return x;
}

// Собрать младшие биты всех 8 тетрад в 8-битное число (через pext).
fn uint nibble_lows(uint x)
{
    uint r;
    // TODO: маска 0x11111111
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
