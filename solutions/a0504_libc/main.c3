// Тестовый стенд упражнения a0504. НЕ редактируйте этот файл и abi_check.s —
// правьте libc.s.
import std::io;

extern fn long abi_call(void* f, long a, long b, long c, long d);
extern fn long abi_errors();
extern fn CInt asm_format(char* buf, usz size, long n, double x);
extern fn usz asm_total_len(ZString a, ZString b);

fn void main()
{
    char[64] buf;
    CInt len = asm_format(&buf, buf.len, 42, 3.14159);
    io::printfn("[%s] len=%d", (ZString)&buf, len);
    assert(len == 11, "asm_format вернула %d", len);
    len = asm_format(&buf, buf.len, -7, -0.5);
    io::printfn("[%s] len=%d", (ZString)&buf, len);
    long total = abi_call(&asm_total_len, (long)(void*)"hello", (long)(void*)", world!", 0, 0);
    assert(abi_errors() & 1 == 0, "asm_total_len испортила callee-saved регистр");
    assert(abi_errors() == 0, "нарушение ABI: код %d", abi_errors());
    assert(total == 13, "asm_total_len = %d", total);
    io::printfn("total_len=%d abi=ok", total);
}
