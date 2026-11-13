// Тестовый стенд упражнения a0203. НЕ редактируйте этот файл — правьте div.s.
import std::io;

extern fn uint asm_udiv(uint a, uint b);
extern fn uint asm_umod(uint a, uint b);
extern fn int asm_idiv(int a, int b);
extern fn long asm_lmod(long a, long b);

fn void main()
{
    assert(asm_udiv(100, 7) == 14, "asm_udiv(100,7) = %d", asm_udiv(100, 7));
    assert(asm_umod(100, 7) == 2, "asm_umod(100,7) = %d", asm_umod(100, 7));
    assert(asm_umod(0xFFFF_FFFF, 10) == 5, "asm_umod(0xFFFFFFFF,10) = %d", asm_umod(0xFFFF_FFFF, 10));
    assert(asm_idiv(100, 7) == 14, "asm_idiv(100,7) = %d", asm_idiv(100, 7));
    assert(asm_idiv(-7, 2) == -3, "asm_idiv(-7,2) = %d", asm_idiv(-7, 2));
    assert(asm_idiv(7, -2) == -3, "asm_idiv(7,-2) = %d", asm_idiv(7, -2));
    assert(asm_lmod(-7, 2) == -1, "asm_lmod(-7,2) = %d", asm_lmod(-7, 2));
    assert(asm_lmod(-10000000000, 3) == -1, "asm_lmod(-10000000000,3) = %d", asm_lmod(-10000000000, 3));
    assert(asm_lmod(10000000007, 10000000000) == 7, "asm_lmod = %d", asm_lmod(10000000007, 10000000000));
    io::printfn("udiv=%d umod=%d idiv=%d lmod=%d",
                asm_udiv(100, 7), asm_umod(100, 7), asm_idiv(-7, 2), asm_lmod(-7, 2));
}
