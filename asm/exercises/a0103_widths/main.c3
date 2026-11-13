// Тестовый стенд упражнения a0103. НЕ редактируйте этот файл — правьте widths.s.
import std::io;

extern fn ulong asm_low32(ulong x);
extern fn ulong asm_low8(ulong x);
extern fn long asm_sext8(ulong x);
extern fn long asm_sext32(int x);

fn void main()
{
    ulong x = 0x1122334455667788;
    assert(asm_low32(x) == 0x55667788, "asm_low32 = %x", asm_low32(x));
    assert(asm_low8(x) == 0x88, "asm_low8 = %x", asm_low8(x));
    assert(asm_low8(0xFFFF_FFFF_FFFF_FF05) == 0x05, "asm_low8 = %x", asm_low8(0xFFFF_FFFF_FFFF_FF05));
    assert(asm_sext8(x) == -120, "asm_sext8 = %d", asm_sext8(x));
    assert(asm_sext8(0x17F) == 127, "asm_sext8(0x17F) = %d", asm_sext8(0x17F));
    assert(asm_sext32(-5) == -5, "asm_sext32(-5) = %d", asm_sext32(-5));
    assert(asm_sext32(7) == 7, "asm_sext32(7) = %d", asm_sext32(7));
    io::printfn("low32=%x low8=%x sext8=%d sext32=%d",
                asm_low32(x), asm_low8(x), asm_sext8(x), asm_sext32(-5));
}
