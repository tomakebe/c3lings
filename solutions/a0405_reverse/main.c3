// Тестовый стенд упражнения a0405. НЕ редактируйте этот файл — правьте reverse.s.
import std::io;

extern fn void asm_reverse(int* a, usz n);
extern fn long asm_index_of(long* a, usz n, long key);

fn void main()
{
    int[7] a = { 1, 2, 3, 4, 5, 6, 7 };
    asm_reverse(&a, 7);
    assert(a == (int[7]){ 7, 6, 5, 4, 3, 2, 1 }, "после asm_reverse(a, 7): %s", a);
    asm_reverse(&a, 4);
    assert(a == (int[7]){ 4, 5, 6, 7, 3, 2, 1 }, "после asm_reverse(a, 4): %s", a);
    asm_reverse(&a, 1);
    asm_reverse(&a, 0);
    assert(a == (int[7]){ 4, 5, 6, 7, 3, 2, 1 }, "n = 0 или 1 не должны ничего менять: %s", a);
    long[5] b = { 10, -20, 30, -20, 50 };
    assert(asm_index_of(&b, 5, -20) == 1, "asm_index_of(b, -20) = %d", asm_index_of(&b, 5, -20));
    assert(asm_index_of(&b, 5, 50) == 4, "asm_index_of(b, 50) = %d", asm_index_of(&b, 5, 50));
    assert(asm_index_of(&b, 5, 99) == -1, "asm_index_of(b, 99) = %d", asm_index_of(&b, 5, 99));
    assert(asm_index_of(&b, 0, 10) == -1, "asm_index_of(b, n=0) = %d", asm_index_of(&b, 0, 10));
    io::printfn("%s idx=%d %d", a, asm_index_of(&b, 5, -20), asm_index_of(&b, 5, 99));
}
