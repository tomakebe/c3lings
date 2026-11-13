// Тестовый стенд упражнения a0505. НЕ редактируйте этот файл и abi_check.s —
// правьте apply.s.
import std::io;

alias IntFn = fn int(int);

extern fn long abi_call(void* f, long a, long b, long c, long d);
extern fn long abi_errors();
extern fn void harness_trash();
extern fn void asm_apply(int* a, usz n, IntFn f);
extern fn int asm_fold(int* a, usz n, int init, void* f);

fn int twice(int x) { harness_trash(); return x * 2; }
fn int square_minus_one(int x) { harness_trash(); return x * x - 1; }
fn int add(int acc, int x) { harness_trash(); return acc + x; }
fn int max(int acc, int x) { harness_trash(); return x > acc ? x : acc; }

fn void check_abi(String what)
{
    assert(abi_errors() & 1 == 0, "%s: испорчен callee-saved регистр", what);
    assert(abi_errors() & 4 == 0, "%s: стек не выровнен по 16 байт перед call", what);
    assert(abi_errors() == 0, "%s: нарушение ABI, код %d", what, abi_errors());
}

fn void main()
{
    int[5] a = { 1, 2, 3, -4, 5 };
    abi_call(&asm_apply, (long)&a, 5, (long)(void*)&twice, 0);
    check_abi("asm_apply");
    assert(a == (int[5]){ 2, 4, 6, -8, 10 }, "после asm_apply(twice): %s", a);
    abi_call(&asm_apply, (long)&a, 3, (long)(void*)&square_minus_one, 0);
    check_abi("asm_apply");
    assert(a == (int[5]){ 3, 15, 35, -8, 10 }, "после asm_apply(square_minus_one, n=3): %s", a);
    int s = (int)abi_call(&asm_fold, (long)&a, 5, 0, (long)(void*)&add);
    check_abi("asm_fold");
    assert(s == 55, "asm_fold(add) = %d", s);
    int m = (int)abi_call(&asm_fold, (long)&a, 5, -1000, (long)(void*)&max);
    check_abi("asm_fold");
    assert(m == 35, "asm_fold(max) = %d", m);
    int e = (int)abi_call(&asm_fold, (long)&a, 0, 77, (long)(void*)&add);
    assert(e == 77, "asm_fold(n=0) = %d", e);
    io::printfn("%s sum=%d max=%d abi=ok", a, s, m);
}
