// Тестовый стенд упражнения a0205. НЕ редактируйте этот файл — правьте flags.s.
import std::io;

extern fn int asm_add_carries(uint a, uint b);
extern fn int asm_add_overflows(int a, int b);
extern fn int asm_sub_borrows(uint a, uint b);
extern fn int asm_is_negative(long x);

fn void main()
{
    assert(asm_add_carries(0xFFFF_FFFF, 1) == 1, "carries(0xFFFFFFFF,1)");
    assert(asm_add_carries(0x7FFF_FFFF, 1) == 0, "carries(0x7FFFFFFF,1)");
    assert(asm_add_overflows(int::max, 1) == 1, "overflows(INT_MAX,1)");
    assert(asm_add_overflows(-1, 1) == 0, "overflows(-1,1)");
    assert(asm_add_overflows(int::min, -1) == 1, "overflows(INT_MIN,-1)");
    assert(asm_sub_borrows(3, 5) == 1, "borrows(3,5)");
    assert(asm_sub_borrows(5, 3) == 0, "borrows(5,3)");
    assert(asm_sub_borrows(5, 5) == 0, "borrows(5,5)");
    assert(asm_is_negative(-1) == 1, "is_negative(-1)");
    assert(asm_is_negative(0) == 0, "is_negative(0)");
    assert(asm_is_negative(0x8000_0000) == 0, "is_negative(0x80000000): число 64-битное!");
    assert(asm_is_negative(long::min) == 1, "is_negative(LONG_MIN)");
    io::printfn("carry=%d %d overflow=%d %d borrow=%d %d negative=%d %d",
        asm_add_carries(0xFFFF_FFFF, 1), asm_add_carries(0x7FFF_FFFF, 1),
        asm_add_overflows(int::max, 1), asm_add_overflows(-1, 1),
        asm_sub_borrows(3, 5), asm_sub_borrows(5, 3),
        asm_is_negative(-1), asm_is_negative(0x8000_0000));
}
