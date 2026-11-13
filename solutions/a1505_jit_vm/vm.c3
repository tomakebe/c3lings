// Байт-код и эталонный интерпретатор. Этот файл НЕ нужно править.
module jit;

alias HostFn = fn long(long);
HostFn[2] host_table;

enum Op : char
{
    CONST,   // push arg
    ARG,     // push x
    LOAD,    // push local[arg]           (arg = 0..6)
    STORE,   // local[arg] = pop
    ADD,     // b = pop, a = pop, push a + b
    SUB,     // ... a - b
    MUL,     // ... a * b
    LT,      // ... a < b ? 1 : 0   (знаковое)
    JZ,      // if (pop == 0) goto arg    (arg — индекс инструкции байт-кода)
    JMP,     // goto arg
    CALL,    // v = pop, push host_table[arg](v)
    RET,     // return pop
}

struct Instr
{
    Op op;
    long arg;
}

fn long interpret(Instr[] prog, long x)
{
    long[64] st;
    long[7] local;
    int sp = 0;
    usz pc = 0;
    while (true)
    {
        Instr ins = prog[pc++];
        switch (ins.op)
        {
            case CONST: st[sp++] = ins.arg;
            case ARG: st[sp++] = x;
            case LOAD: st[sp++] = local[ins.arg];
            case STORE: local[ins.arg] = st[--sp];
            case ADD: sp--; st[sp - 1] += st[sp];
            case SUB: sp--; st[sp - 1] -= st[sp];
            case MUL: sp--; st[sp - 1] *= st[sp];
            case LT: sp--; st[sp - 1] = st[sp - 1] < st[sp] ? 1 : 0;
            case JZ: if (st[--sp] == 0) pc = (usz)ins.arg;
            case JMP: pc = (usz)ins.arg;
            case CALL: st[sp - 1] = host_table[ins.arg](st[sp - 1]);
            case RET: return st[--sp];
        }
    }
}
