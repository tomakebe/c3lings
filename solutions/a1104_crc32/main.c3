// =====================================================================
//  a1104 · Inline-ассемблер: аппаратный CRC32C
// =====================================================================
//
//  В SSE4.2 есть инструкция crc32 — она считает контрольную сумму
//  CRC-32C (полином Кастаньоли 0x1EDC6F41) по 1, 2, 4 или 8 байтам за раз:
//
//      crc32 crc, src     // crc (32 бита) обновляется данными src
//
//  Размер обрабатываемых данных = размер src (char -> 1 байт, uint -> 4,
//  ulong -> 8; при ulong-источнике crc тоже должен быть 64-битным,
//  результат всё равно в младших 32 битах). CRC32C используют iSCSI, ext4,
//  Btrfs, LevelDB/RocksDB, и как очень быструю хеш-функцию.
//
//  Алгоритм (как в стандарте):
//      crc = 0xFFFFFFFF
//      для каждого байта: crc = crc32_step(crc, byte)
//      результат = ~crc
//
//  Ниже уже есть программная реализация (побитовая, медленная) — эталон.
//
//  ЗАДАЧА:
//      crc32c_hw(data)   — побайтно через инструкцию crc32;
//      crc32c_hw8(data)  — по 8 байт за раз (ulong из памяти: можно
//                          взять `mem::load((ulong*)(data.ptr + i), 1)`:
//                          обычное разыменование ulong* по невыровненному
//                          адресу C3 в безопасном режиме считает ошибкой), затем хвост
//                          побайтно. Длина данных — любая.
//
import std::io;

fn uint crc32c_soft(char[] data)
{
    uint crc = 0xFFFF_FFFF;
    foreach (b : data)
    {
        crc ^= b;
        for (int k = 0; k < 8; k++) crc = (crc >> 1) ^ (0x82F6_3B78 & (0 - (crc & 1)));
    }
    return ~crc;
}

fn uint crc32c_hw(char[] data)
{
    uint crc = 0xFFFF_FFFF;
    foreach (b : data)
    {
        asm { crc32 crc, b; }
    }
    return ~crc;
}

fn uint crc32c_hw8(char[] data)
{
    ulong crc = 0xFFFF_FFFF;
    usz i = 0;
    for (; i + 8 <= data.len; i += 8)
    {
        ulong w = mem::load((ulong*)(data.ptr + i), 1);
        asm { crc32 crc, w; }
    }
    uint c32 = (uint)crc;
    for (; i < data.len; i++)
    {
        char b = data[i];
        asm { crc32 c32, b; }
    }
    crc = c32;
    return ~(uint)crc;
}

fn void main()
{
    String s = "123456789";
    assert(crc32c_soft(s) == 0xE306_9283);     // стандартный тестовый вектор
    assert(crc32c_hw(s) == 0xE306_9283);
    assert(crc32c_hw8(s) == 0xE306_9283);
    char[300] buf;
    for (int i = 0; i < 300; i++) buf[i] = (char)(i * 7 + 3);
    for (int n = 0; n <= 300; n += 13)
    {
        assert(crc32c_hw(buf[:n]) == crc32c_soft(buf[:n]));
        assert(crc32c_hw8(buf[:n]) == crc32c_soft(buf[:n]), "hw8 len %d", n);
    }
    io::printfn("crc32c(\"123456789\")  = 0x%08X", crc32c_hw(s));
    io::printfn("crc32c(\"\")           = 0x%08X", crc32c_hw8(""));
    io::printfn("crc32c(buf[0:300])   = 0x%08X", crc32c_hw8(buf[:300]));
}
