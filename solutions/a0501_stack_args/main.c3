// Тестовый стенд упражнения a0501. НЕ редактируйте этот файл — правьте stack_args.s.
import std::io;

extern fn long asm_weighted(long a, long b, long c, long d, long e, long f);
extern fn long asm_eight(long a, long b, long c, long d, long e, long f, long g, long h);
extern fn int asm_mixed(int a, int b, int c, int d, int e, int f, int g, int h);

fn void main()
{
    assert(asm_weighted(1, 1, 1, 1, 1, 1) == 21, "asm_weighted(1..1) = %d", asm_weighted(1, 1, 1, 1, 1, 1));
    assert(asm_weighted(1, 2, 3, 4, 5, 6) == 91, "asm_weighted(1..6) = %d", asm_weighted(1, 2, 3, 4, 5, 6));
    assert(asm_eight(1, 2, 3, 4, 5, 6, 7, 8) == 57, "asm_eight = %d", asm_eight(1, 2, 3, 4, 5, 6, 7, 8));
    assert(asm_eight(100, 0, 0, 0, 0, 0, -3, 1_000_000_000_000) == -2_999_999_999_900,
           "asm_eight = %d", asm_eight(100, 0, 0, 0, 0, 0, -3, 1_000_000_000_000));
    assert(asm_mixed(0, 0, 0, 0, 0, 0, -5, 3) == -2, "asm_mixed = %d", asm_mixed(0, 0, 0, 0, 0, 0, -5, 3));
    io::printfn("weighted=%d eight=%d mixed=%d", asm_weighted(1, 2, 3, 4, 5, 6),
                asm_eight(1, 2, 3, 4, 5, 6, 7, 8), asm_mixed(0, 0, 0, 0, 0, 0, -5, 3));
}
