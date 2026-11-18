// =====================================================================
//  a1504 · A JIT for a stack machine (RPN)
// =====================================================================
//
//  The bytecode is reverse Polish notation: CONST k pushes a number onto
//  the stack, ARG pushes the argument x, ADD/SUB/MUL pop two values and
//  push the result, NEG negates the top. The interpreter (in main.c3)
//  does a switch on every instruction and reads and writes a stack array —
//  that is dozens of cycles per operation. A JIT translates the program
//  into machine code ONCE, and from then on it runs at the speed of a
//  native function.
//
//  The simplest code generation scheme: bytecode stack = machine stack.
//
//      CONST k   ->  mov rax, k ; push rax
//      ARG       ->  push rdi               (x arrived in rdi per System V)
//      ADD       ->  pop rcx ; pop rax ; add rax, rcx ; push rax
//      SUB       ->  pop rcx ; pop rax ; sub rax, rcx ; push rax
//      MUL       ->  pop rcx ; pop rax ; imul rax, rcx ; push rax
//      NEG       ->  pop rax ; neg rax ; push rax
//      end       ->  pop rax ; ret          (the result is in rax)
//
//  Note the order in SUB: the RIGHT operand is popped first. At the end
//  the stack returns to its original state, so `ret` will find its
//  return address. The function calls nothing, so there is no need to
//  think about stack alignment.
//
//  This is inefficient code (every value goes through memory), but it is
//  correct and many times faster than the interpreter. Real JITs go on to
//  allocate registers, fold constants (CONST 3; CONST 4; ADD ->
//  CONST 7), and so on.
//
//  TASK: complete the ADD, SUB, MUL, NEG cases in compile(). The emitter
//  (emit.c3) is already done: e.push, e.pop, e.mov_imm64, e.add, e.sub,
//  e.imul, e.neg, e.ret.
//
module jit;

enum Op : char
{
    CONST,
    ARG,
    ADD,
    SUB,
    MUL,
    NEG,
}

struct Instr
{
    Op op;
    long arg;
}

fn void compile(Emitter* e, Instr[] prog)
{
    foreach (ins : prog)
    {
        switch (ins.op)
        {
            case CONST:
                e.mov_imm64(RAX, ins.arg);
                e.push(RAX);
            case ARG:
                e.push(RDI);
            case ADD:
            case SUB:
            case MUL:
            case NEG:
                unreachable("TODO: compile %s", ins.op);
        }
    }
    e.pop(RAX);
    e.ret();
}
