// =====================================================================
//  e1301 · Поток байт: little-endian, float, varint, zigzag
// =====================================================================
//
//  Сначала прочитайте engine/docs/13_serialization.md (разделы 13.3).
//
//  Любая бинарная сериализация в движке стоит на двух крошечных классах:
//  писателе (ByteWriter) и читателе (ByteReader). Всё остальное —
//  чанки, рефлексия, сохранения — пишет и читает только через них.
//  Поэтому их надо сделать правильно один раз:
//
//  * Порядок байт фиксирован форматом — little-endian, младший байт
//    первым. Пишем сдвигами `(char)(v >> 8)`, а не `*(uint*)p = v`:
//    так код не зависит ни от архитектуры, ни от выравнивания буфера.
//
//  * float пишется побитово: `bitcast(f, uint)`, читается обратно
//    `bitcast(u, float)`. Ни одного бита не теряется.
//
//  * varint (LEB128): по 7 бит полезных данных в байте, старший бит
//    (0x80) означает «дальше есть ещё байт». Младшие группы — первыми.
//        300 -> AC 02        127 -> 7F        128 -> 80 01
//
//  * zigzag превращает знаковое число в беззнаковое так, чтобы малые
//    по модулю числа стали малыми: 0->0, -1->1, 1->2, -2->3, 2->4 ...
//        zigzag(n)   = ((uint)n << 1) ^ (uint)(n >> 31)
//    `n >> 31` для int — арифметический сдвиг: 0 или -1 (все единицы).
//
//  * Читатель НЕ доверяет данным: чтение за концом буфера возвращает
//    ошибку END_OF_DATA, а varint длиннее 5 байт (для uint) — MALFORMED.
//    Optional-типы C3 (`uint?`, `return ERR~;`, проброс `!`) делают
//    это почти бесплатным по количеству кода.
//
//  ЗАДАЧА: реализуйте функции, помеченные TODO:
//    ByteWriter.u32, ByteWriter.f32, ByteWriter.varint, zigzag, unzigzag,
//    ByteReader.u32, ByteReader.f32, ByteReader.varint.
//  Остальные методы — образцы, на которые можно опираться.
//  main() сам себя проверяет и печатает hex-дамп записанного потока.
//
import std::io;

excuse END_OF_DATA, MALFORMED;

const usz CAPACITY = 128;

struct ByteWriter
{
    char[CAPACITY] data;
    usz len;
}

fn void ByteWriter.u8(&self, char v)
{
    assert(self.len < CAPACITY, "ByteWriter overflow");
    self.data[self.len++] = v;
}

fn void ByteWriter.u16(&self, ushort v)
{
    self.u8((char)v);
    self.u8((char)(v >> 8));
}

fn void ByteWriter.u32(&self, uint v)
{
    // TODO: четыре байта, младший первым (по образцу u16)
}

fn void ByteWriter.f32(&self, float f)
{
    // TODO: записать битовое представление float через u32
}

fn void ByteWriter.varint(&self, uint v)
{
    // TODO: LEB128 — пока v >= 0x80, писать (v & 0x7F) | 0x80 и сдвигать v на 7
}

fn uint zigzag(int n)
{
    // TODO
    return 0;
}

fn int unzigzag(uint z)
{
    // TODO: обратное преобразование
    return 0;
}

fn void ByteWriter.svarint(&self, int v) => self.varint(zigzag(v));

fn char[] ByteWriter.bytes(&self) => self.data[:self.len];

struct ByteReader
{
    char[] data;
    usz pos;
}

fn char? ByteReader.u8(&self)
{
    if (self.pos >= self.data.len) return END_OF_DATA~;
    return self.data[self.pos++];
}

fn ushort? ByteReader.u16(&self)
{
    ushort lo = self.u8()!;
    ushort hi = self.u8()!;
    return lo | hi << 8;
}

fn uint? ByteReader.u32(&self)
{
    // TODO: прочитать 4 байта little-endian (ошибки пробрасывать через `!`)
    return 0;
}

fn float? ByteReader.f32(&self)
{
    // TODO
    return 0;
}

fn uint? ByteReader.varint(&self)
{
    // TODO: собрать группы по 7 бит; не больше 5 байт, иначе MALFORMED
    return 0;
}

fn int? ByteReader.svarint(&self) => unzigzag(self.varint()!);

fn void hexdump(char[] bytes)
{
    foreach (i, b : bytes)
    {
        io::printf("%02x", b);
        io::print((i % 16 == 15 || i + 1 == bytes.len) ? "\n" : " ");
    }
}

macro void @expect_err(String what, #expr)
{
    if (catch e = #expr)
    {
        io::printfn("%s: %s", what, e);
        return;
    }
    unreachable("expected an error: %s", what);
}

fn usz varint_size(uint v)
{
    ByteWriter w;
    w.varint(v);
    return w.len;
}

fn void main()
{
    // --- zigzag ---
    assert(zigzag(0) == 0 && zigzag(-1) == 1 && zigzag(1) == 2 && zigzag(-2) == 3);
    assert(zigzag(int::max) == uint::max - 1 && zigzag(int::min) == uint::max);
    for (int n = -1000; n <= 1000; n += 7) assert(unzigzag(zigzag(n)) == n);
    assert(unzigzag(zigzag(int::min)) == int::min);

    // --- размеры varint ---
    assert(varint_size(0) == 1 && varint_size(127) == 1);
    assert(varint_size(128) == 2 && varint_size(16383) == 2 && varint_size(16384) == 3);
    assert(varint_size(uint::max) == 5);

    // --- запись ---
    ByteWriter w;
    w.u32(0x11223344);
    w.u16(0xBEEF);
    w.f32(1.5f);
    w.f32(-0.1f);
    w.varint(300);
    w.varint(5);
    w.svarint(-3);
    w.svarint(64);
    w.varint(uint::max);
    w.u8('!');

    char[] bytes = w.bytes();
    assert(bytes[0] == 0x44 && bytes[3] == 0x11, "u32 must be little-endian");
    io::printfn("written %d bytes", bytes.len);
    hexdump(bytes);

    // --- чтение ---
    ByteReader r = { .data = bytes };
    assert(r.u32()!! == 0x11223344);
    assert(r.u16()!! == 0xBEEF);
    float a = r.f32()!!;
    float b = r.f32()!!;
    assert(a == 1.5f && b == -0.1f, "float must round-trip bit-exactly");
    assert(r.varint()!! == 300);
    assert(r.varint()!! == 5);
    assert(r.svarint()!! == -3);
    assert(r.svarint()!! == 64);
    assert(r.varint()!! == uint::max);
    assert(r.u8()!! == '!');
    assert(r.pos == bytes.len);
    io::printfn("read back: %.2f %.2f", a, b);

    // --- враждебные данные ---
    @expect_err("past end", r.u8());

    ByteReader cut = { .data = bytes[0:2] };
    @expect_err("truncated u32", cut.u32());

    char[6] evil = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01 };
    ByteReader bad = { .data = &evil };
    @expect_err("6-byte varint", bad.varint());

    char[2] unfinished = { 0x80, 0x80 };
    ByteReader unf = { .data = &unfinished };
    @expect_err("unfinished varint", unf.varint());

    io::printn("byte stream ok");
}
