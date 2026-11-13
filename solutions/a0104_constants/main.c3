// Тестовый стенд упражнения a0104. НЕ редактируйте этот файл — правьте constants.s.
import std::io;

extern fn long asm_minus_one();
extern fn ulong asm_u32_max();
extern fn ulong asm_big();
extern fn long asm_zero();

fn void main()
{
    assert(asm_minus_one() == -1, "asm_minus_one = %d", asm_minus_one());
    assert(asm_u32_max() == 0xFFFF_FFFF, "asm_u32_max = %x", asm_u32_max());
    assert(asm_big() == 0x1234_5678_9ABC_DEF0, "asm_big = %x", asm_big());
    assert(asm_zero() == 0, "asm_zero = %x", asm_zero());
    io::printfn("minus_one=%d u32_max=%d big=%x zero=%d",
                asm_minus_one(), asm_u32_max(), asm_big(), asm_zero());
}
