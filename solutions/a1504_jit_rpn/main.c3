// Драйвер упражнения a1504. Этот файл НЕ нужно править — правьте compile.c3.
import std::io, jit;

alias JitFn = fn long(long);

extern fn void* jit_make(char* code, long len);
extern fn long jit_free(void* p, long len);

fn long interpret(Instr[] prog, long x)
{
    long[64] st;
    int sp = 0;
    foreach (ins : prog)
    {
        switch (ins.op)
        {
            case CONST: st[sp++] = ins.arg;
            case ARG: st[sp++] = x;
            case ADD: sp--; st[sp - 1] += st[sp];
            case SUB: sp--; st[sp - 1] -= st[sp];
            case MUL: sp--; st[sp - 1] *= st[sp];
            case NEG: st[sp - 1] = -st[sp - 1];
        }
    }
    assert(sp == 1);
    return st[0];
}

fn void test(String name, Instr[] prog)
{
    Emitter e;
    jit::compile(&e, prog);
    void* code = jit_make(&e.buf, (long)e.len);
    assert(code != null);
    defer (void)jit_free(code, (long)e.len);
    JitFn f = (JitFn)code;
    for (long x = -20; x <= 20; x++)
    {
        assert(f(x) == interpret(prog, x), "%s: x=%d jit=%d interp=%d", name, x, f(x), interpret(prog, x));
    }
    io::printfn("%-22s %2d bytes  f(3) = %d, f(-5) = %d", name, e.len, f(3), f(-5));
}

fn void main()
{
    // 42
    test("42", { { CONST, 42 } });
    // x * x + 3 * x - 7
    test("x*x + 3*x - 7", { { ARG, 0 }, { ARG, 0 }, { MUL, 0 }, { CONST, 3 }, { ARG, 0 }, { MUL, 0 }, { ADD, 0 }, { CONST, 7 }, { SUB, 0 } });
    // -(x - 10) * (x + 1000000000000)
    test("-(x-10)*(x+1e12)", { { ARG, 0 }, { CONST, 10 }, { SUB, 0 }, { NEG, 0 }, { ARG, 0 }, { CONST, 1_000_000_000_000 }, { ADD, 0 }, { MUL, 0 } });
    // x^5
    test("x^5", { { ARG, 0 }, { ARG, 0 }, { MUL, 0 }, { ARG, 0 }, { MUL, 0 }, { ARG, 0 }, { MUL, 0 }, { ARG, 0 }, { MUL, 0 } });
}
