// Тестовый стенд упражнения a0503. НЕ редактируйте этот файл и abi_check.s —
// правьте call_c3.s.
import std::io;

extern fn long abi_call(void* f, long a, long b, long c, long d);
extern fn long abi_errors();
extern fn void harness_trash();
extern fn long asm_sum_weights(int* a, usz n);

// Эту функцию вызывает ваш ассемблерный код. @export("c3_weight") даёт ей
// «сишное» имя без префикса модуля — иначе символ назывался бы иначе.
fn long c3_weight(int x) @export("c3_weight")
{
    harness_trash();      // проверяет выравнивание стека и портит volatile-регистры
    return (long)x * x + 1;
}

fn void main()
{
    int[6] a = { 1, -2, 3, 0, 10, 1000 };
    long expect = 0;
    foreach (x : a) expect += (long)x * x + 1;
    long r = abi_call(&asm_sum_weights, (long)&a, 6, 0, 0);
    assert(abi_errors() & 1 == 0, "испорчен callee-saved регистр (rbx, rbp, r12-r15)");
    assert(abi_errors() & 4 == 0, "стек не выровнен по 16 байт перед call c3_weight");
    assert(abi_errors() == 0, "нарушение ABI: код %d", abi_errors());
    assert(r == expect, "asm_sum_weights = %d, ожидалось %d", r, expect);
    long r0 = abi_call(&asm_sum_weights, (long)&a, 0, 0, 0);
    assert(r0 == 0, "asm_sum_weights(a, 0) = %d", r0);
    assert(abi_errors() == 0, "нарушение ABI: код %d", abi_errors());
    io::printfn("sum_weights=%d abi=ok", r);
}
