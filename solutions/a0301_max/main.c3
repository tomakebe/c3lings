// Тестовый стенд упражнения a0301. НЕ редактируйте этот файл — правьте max.s.
import std::io;

extern fn int asm_max(int a, int b);
extern fn uint asm_umax(uint a, uint b);

fn void main()
{
    assert(asm_max(3, 9) == 9, "asm_max(3,9) = %d", asm_max(3, 9));
    assert(asm_max(9, 3) == 9, "asm_max(9,3) = %d", asm_max(9, 3));
    assert(asm_max(-5, 2) == 2, "asm_max(-5,2) = %d", asm_max(-5, 2));
    assert(asm_max(-5, -2) == -2, "asm_max(-5,-2) = %d", asm_max(-5, -2));
    assert(asm_umax(3, 9) == 9, "asm_umax(3,9) = %d", asm_umax(3, 9));
    assert(asm_umax(0xFFFF_FFFF, 2) == 0xFFFF_FFFF, "asm_umax(0xFFFFFFFF,2) = %d", asm_umax(0xFFFF_FFFF, 2));
    assert(asm_umax(0x8000_0000, 0x7FFF_FFFF) == 0x8000_0000, "asm_umax(0x80000000,0x7FFFFFFF)");
    io::printfn("max(-5,2)=%d umax=%d", asm_max(-5, 2), asm_umax(0xFFFF_FFFF, 2));
}
