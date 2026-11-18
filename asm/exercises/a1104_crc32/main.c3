// =====================================================================
//  a1104 · Inline assembly: hardware CRC32C
// =====================================================================
//
//  SSE4.2 has a crc32 instruction — it computes the CRC-32C checksum
//  (the Castagnoli polynomial 0x1EDC6F41) over 1, 2, 4 or 8 bytes at a time:
//
//      crc32 crc, src     // crc (32 bits) is updated with the data in src
//
//  The size of the data processed = the size of src (char -> 1 byte,
//  uint -> 4, ulong -> 8; with a ulong source crc must also be 64-bit,
//  though the result is still in the low 32 bits). CRC32C is used by iSCSI,
//  ext4, Btrfs, LevelDB/RocksDB, and as a very fast hash function.
//
//  The algorithm (as in the standard):
//      crc = 0xFFFFFFFF
//      for each byte: crc = crc32_step(crc, byte)
//      result = ~crc
//
//  Below there is already a software implementation (bitwise, slow) —
//  the reference.
//
//  TASK:
//      crc32c_hw(data)   — byte by byte using the crc32 instruction;
//      crc32c_hw8(data)  — 8 bytes at a time (a ulong from memory: you can
//                          use `mem::load((ulong*)(data.ptr + i), 1)`:
//                          a plain dereference of a ulong* at an unaligned
//                          address is an error in C3's safe mode), then the
//                          tail byte by byte. The data length can be anything.
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
        // TODO: one crc32 step over byte b
    }
    return ~crc;
}

fn uint crc32c_hw8(char[] data)
{
    ulong crc = 0xFFFF_FFFF;
    usz i = 0;
    // TODO: 8-byte blocks, then the tail one byte at a time
    //       (the byte step needs a 32-bit copy of crc:
    //        uint c32 = (uint)crc; asm { crc32 c32, b; } crc = c32;)
    return ~(uint)crc;
}

fn void main()
{
    String s = "123456789";
    assert(crc32c_soft(s) == 0xE306_9283);     // the standard test vector
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
