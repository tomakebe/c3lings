// Тестовый стенд упражнения a0302. НЕ редактируйте этот файл — правьте sign.s.
import std::io;

extern fn long asm_sign(long x);
extern fn long asm_clamp(long x, long lo, long hi);

fn void main()
{
    assert(asm_sign(-100) == -1, "asm_sign(-100) = %d", asm_sign(-100));
    assert(asm_sign(0) == 0, "asm_sign(0) = %d", asm_sign(0));
    assert(asm_sign(7) == 1, "asm_sign(7) = %d", asm_sign(7));
    assert(asm_sign(long::min) == -1, "asm_sign(LONG_MIN) = %d", asm_sign(long::min));
    assert(asm_sign(0x1_0000_0000) == 1, "asm_sign(2^32) = %d", asm_sign(0x1_0000_0000));
    assert(asm_clamp(5, 0, 10) == 5, "asm_clamp(5,0,10) = %d", asm_clamp(5, 0, 10));
    assert(asm_clamp(-5, 0, 10) == 0, "asm_clamp(-5,0,10) = %d", asm_clamp(-5, 0, 10));
    assert(asm_clamp(50, 0, 10) == 10, "asm_clamp(50,0,10) = %d", asm_clamp(50, 0, 10));
    assert(asm_clamp(-50, -20, -10) == -20, "asm_clamp(-50,-20,-10) = %d", asm_clamp(-50, -20, -10));
    io::printfn("sign=%d %d %d clamp=%d %d %d", asm_sign(-100), asm_sign(0), asm_sign(7),
                asm_clamp(-5, 0, 10), asm_clamp(5, 0, 10), asm_clamp(50, 0, 10));
}
