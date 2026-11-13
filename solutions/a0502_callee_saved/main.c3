// Тестовый стенд упражнения a0502. НЕ редактируйте этот файл и abi_check.s —
// правьте sumsq.s. Функции вызываются через abi_call, который проверяет,
// что callee-saved регистры пережили вызов.
import std::io;

extern fn long abi_call(void* f, long a, long b, long c, long d);
extern fn long abi_errors();
extern fn long asm_sumsq(long a, long b, long c);
extern fn long asm_poly3(long x, long a, long b, long c);

fn void main()
{
    long r1 = abi_call(&asm_sumsq, 1, 2, 3, 0);
    assert(r1 == 14, "asm_sumsq(1,2,3) = %d", r1);
    assert(abi_errors() & 1 == 0, "asm_sumsq испортила callee-saved регистр (rbx, rbp, r12-r15)");
    assert(abi_errors() == 0, "asm_sumsq нарушила ABI: код %d", abi_errors());
    long r2 = abi_call(&asm_poly3, 2, 1, 10, 100);
    assert(r2 == 1 * 4 + 10 * 2 + 100, "asm_poly3(2; 1,10,100) = %d", r2);
    assert(abi_errors() & 1 == 0, "asm_poly3 испортила callee-saved регистр (rbx, rbp, r12-r15)");
    assert(abi_errors() == 0, "asm_poly3 нарушила ABI: код %d", abi_errors());
    io::printfn("sumsq=%d poly3=%d abi=ok", r1, r2);
}
