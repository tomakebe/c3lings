// Тестовый стенд упражнения a0401. НЕ редактируйте этот файл — правьте index.s.
import std::io;

extern fn int asm_get(int* a, long i);
extern fn void asm_set(int* a, long i, int v);
extern fn long asm_get_long(long* a, long i);

fn void main()
{
    int[6] a = { 10, 20, 30, -40, 50, 60 };
    long[4] b = { 100, -200, 300_000_000_000, 400 };
    assert(asm_get(&a, 0) == 10, "asm_get(a,0) = %d", asm_get(&a, 0));
    assert(asm_get(&a, 2) == 30, "asm_get(a,2) = %d", asm_get(&a, 2));
    assert(asm_get(&a, 3) == -40, "asm_get(a,3) = %d", asm_get(&a, 3));
    assert(asm_get(&a[2], -1) == 20, "asm_get(&a[2],-1) = %d", asm_get(&a[2], -1));
    asm_set(&a, 4, 555);
    assert(a == (int[6]){ 10, 20, 30, -40, 555, 60 }, "asm_set записала не туда: %s", a);
    assert(asm_get_long(&b, 2) == 300_000_000_000, "asm_get_long(b,2) = %d", asm_get_long(&b, 2));
    assert(asm_get_long(&b, 1) == -200, "asm_get_long(b,1) = %d", asm_get_long(&b, 1));
    io::printfn("a[2]=%d a[3]=%d b[2]=%d after set: %s", asm_get(&a, 2), asm_get(&a, 3), asm_get_long(&b, 2), a);
}
