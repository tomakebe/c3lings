// Тестовый стенд упражнения a0506. НЕ редактируйте этот файл и abi_check.s —
// правьте sort.s.
import std::io;

extern fn long abi_call(void* f, long a, long b, long c, long d);
extern fn long abi_errors();
extern fn CInt asm_cmp_desc(void* a, void* b);
extern fn void asm_sort_desc(long* a, usz n);

fn void main()
{
    long x = 5;
    long y = 7;
    long big = long::max;
    long small = long::min;
    assert(asm_cmp_desc(&x, &y) > 0, "cmp_desc(5, 7) должно быть > 0 (7 идёт раньше)");
    assert(asm_cmp_desc(&y, &x) < 0, "cmp_desc(7, 5) должно быть < 0");
    assert(asm_cmp_desc(&x, &x) == 0, "cmp_desc(5, 5) должно быть 0");
    assert(asm_cmp_desc(&big, &small) < 0, "cmp_desc(LONG_MAX, LONG_MIN) должно быть < 0 — переполнение?");
    assert(asm_cmp_desc(&small, &big) > 0, "cmp_desc(LONG_MIN, LONG_MAX) должно быть > 0 — переполнение?");
    long[*] k = { 1_099_511_627_776, 0 };
    assert(asm_cmp_desc(&k[0], &k[1]) < 0, "cmp_desc(2^40, 0) должно быть < 0 — младшие 32 бита разности равны 0!");

    long[9] a = { 3, -1, long::max, 42, 0, long::min, 42, 1_099_511_627_776, -100 };
    abi_call(&asm_sort_desc, (long)&a, a.len, 0, 0);
    assert(abi_errors() == 0, "asm_sort_desc нарушила ABI: код %d", abi_errors());
    for (usz i = 1; i < a.len; i++) assert(a[i - 1] >= a[i], "массив не отсортирован: %s", a);
    io::printfn("%s", a);
    io::printn("abi=ok");
}
