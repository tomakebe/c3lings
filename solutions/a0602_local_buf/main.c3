// Тестовый стенд упражнения a0602. НЕ редактируйте этот файл и abi_check.s —
// правьте local_buf.s.
import std::io;

extern fn long abi_call(void* f, long a, long b, long c, long d);
extern fn long abi_errors();
extern fn void harness_trash();
extern fn long asm_sum_squares16();

// Заполняет buf[i] = i*i для i < n.
fn void c3_fill(int* buf, usz n) @export("c3_fill")
{
    harness_trash();
    for (usz i = 0; i < n; i++) buf[i] = (int)(i * i);
}

fn void main()
{
    long r = abi_call(&asm_sum_squares16, 0, 0, 0, 0);
    assert(abi_errors() & 4 == 0, "стек не выровнен по 16 байт перед call c3_fill");
    assert(abi_errors() == 0, "нарушение ABI: код %d", abi_errors());
    assert(r == 1240, "asm_sum_squares16 = %d", r);
    io::printfn("sum_squares16=%d abi=ok", r);
}
