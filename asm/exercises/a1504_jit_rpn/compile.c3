// =====================================================================
//  a1504 · JIT для стековой машины (RPN)
// =====================================================================
//
//  Байт-код — обратная польская запись: CONST k кладёт число на стек,
//  ARG кладёт аргумент x, ADD/SUB/MUL снимают два значения и кладут
//  результат, NEG меняет знак вершины. Интерпретатор (в main.c3) на
//  каждой инструкции делает switch, читает и пишет массив-стек — это
//  десятки тактов на операцию. JIT переводит программу в машинный код
//  ОДИН раз, и дальше она выполняется со скоростью нативной функции.
//
//  Самая простая схема кодогенерации: стек байт-кода = машинный стек.
//
//      CONST k   ->  mov rax, k ; push rax
//      ARG       ->  push rdi               (x пришёл в rdi по System V)
//      ADD       ->  pop rcx ; pop rax ; add rax, rcx ; push rax
//      SUB       ->  pop rcx ; pop rax ; sub rax, rcx ; push rax
//      MUL       ->  pop rcx ; pop rax ; imul rax, rcx ; push rax
//      NEG       ->  pop rax ; neg rax ; push rax
//      конец     ->  pop rax ; ret          (результат — в rax)
//
//  Обратите внимание на порядок в SUB: первым снимается ПРАВЫЙ операнд.
//  Стек в конце возвращается к исходному состоянию, поэтому `ret` найдёт
//  свой адрес возврата. Функция никого не вызывает, значит, о
//  выравнивании стека думать не нужно.
//
//  Это неэффективный код (каждое значение проходит через память), но он
//  корректен и в разы быстрее интерпретатора. Настоящие JIT дальше
//  распределяют регистры, сворачивают константы (CONST 3; CONST 4; ADD ->
//  CONST 7) и т.д.
//
//  ЗАДАЧА: допишите случаи ADD, SUB, MUL, NEG в compile(). Эмиттер
//  (emit.c3) уже готов: e.push, e.pop, e.mov_imm64, e.add, e.sub,
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
