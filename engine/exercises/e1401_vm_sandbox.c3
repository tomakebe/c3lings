// =====================================================================
//  e1401 · Песочница для скрипта: стековая VM с бюджетом инструкций
// =====================================================================
//
//  Сначала прочитайте engine/docs/14_scripting.md (разделы «Стековая VM»
//  и «Песочница»).
//
//  Скрипт геймплея — чужой код внутри вашего кадра. Его мог написать
//  дизайнер, моддер или вы сами в три часа ночи. Движок обязан пережить
//  ЛЮБОЙ байткод: бесконечный цикл, бесконечную рекурсию, мусорный
//  адрес перехода. Падать или зависать нельзя — кадр должен закончиться
//  вовремя, а скрипт — получить понятную ошибку и быть выключен.
//
//  Три линии обороны, которые есть в любой игровой VM:
//
//    1. Бюджет инструкций. Цикл диспетчеризации считает выполненные
//       инструкции; когда счётчик достигает бюджета — выходим с ошибкой
//       BUDGET_EXCEEDED. (В Lua то же делает debug.sethook с count,
//       в Luau — interrupt-колбэк.) Проверка стоит ДО выполнения
//       очередной инструкции: бюджет 20 = ровно 20 выполненных инструкций.
//    2. Проверки стека. push в полный стек -> STACK_OVERFLOW, pop из
//       пустого -> STACK_UNDERFLOW. Никаких выходов за границы массива.
//    3. Проверка pc. Перед выборкой инструкции pc должен лежать в
//       [0, code.len). Иначе — BAD_JUMP (сюда же попадает «провалились
//       за конец программы без HALT»).
//
//  Ошибки — это Optional'ы C3: `fn int? Vm.run(...)` и `self.pop()!`
//  пробрасывают ошибку наверх без единого if. Это ровно та модель, что
//  нужна VM: любая инструкция может «упасть», и падение должно
//  немедленно завершить выполнение скрипта.
//
//  Диспетчеризация — обычный `switch` по опкоду внутри `while (true)`.
//  Для порядка операндов бинарных операций: на стеке `a b` (b — вершина),
//  поэтому сначала снимаем b, потом a, и кладём `a - b`.
//
//  ЗАДАЧА:
//    * сделайте push/pop безопасными (STACK_OVERFLOW / STACK_UNDERFLOW);
//    * в начале каждой итерации Vm.run проверьте бюджет и pc;
//    * реализуйте опкоды SUB, MUL, LT, JZ (ADD уже есть как образец).
//  main() сам проверит VM на арифметике, цикле и «вредных» программах.
//
module vm_budget;
import std::io;

excuse STACK_OVERFLOW, STACK_UNDERFLOW, BUDGET_EXCEEDED, BAD_JUMP, BAD_OPCODE;

enum Op : char
{
    PUSH,   // arg -> push(arg)
    POP,    // pop()
    DUP,    // a -> a a
    ADD,    // a b -> a+b
    SUB,    // a b -> a-b
    MUL,    // a b -> a*b
    LT,     // a b -> (a<b ? 1 : 0)
    JMP,    // pc = arg
    JZ,     // a -> ; if a == 0: pc = arg
    HALT,   // остановиться, результат = вершина стека
}

struct Instr
{
    Op op;
    int arg;
}

const int STACK_MAX = 8;

struct Vm
{
    int[STACK_MAX] stack;
    int sp;      // число элементов в стеке
    int pc;
    int steps;   // сколько инструкций выполнено
}

fn void? Vm.push(&self, int v)
{
    // TODO: если стек полон — вернуть STACK_OVERFLOW
    self.stack[self.sp++] = v;
}

fn int? Vm.pop(&self)
{
    // TODO: если стек пуст — вернуть STACK_UNDERFLOW
    return self.stack[--self.sp];
}

fn int? Vm.run(&self, Instr[] code, int budget)
{
    self.sp = 0;
    self.pc = 0;
    self.steps = 0;
    while (true)
    {
        // TODO: проверка бюджета (BUDGET_EXCEEDED) и границ pc (BAD_JUMP)
        Instr ins = code[self.pc++];
        self.steps++;
        switch (ins.op)
        {
            case PUSH: self.push(ins.arg)!;
            case POP: self.pop()!;
            case DUP:
                int a = self.pop()!;
                self.push(a)!;
                self.push(a)!;
            case ADD:
                int b = self.pop()!;
                int a = self.pop()!;
                self.push(a + b)!;
            case SUB:
                break; // TODO
            case MUL:
                break; // TODO
            case LT:
                break; // TODO
            case JMP:
                self.pc = ins.arg;
            case JZ:
                break; // TODO: снять значение; если 0 — перейти на ins.arg
            case HALT:
                return self.pop()!;
        }
    }
}

fn void main()
{
    Vm vm;

    // (2 + 3) * 4 - 1 = 19
    Instr[] arith = {
        { PUSH, 2 }, { PUSH, 3 }, { ADD, 0 }, { PUSH, 4 }, { MUL, 0 },
        { PUSH, 1 }, { SUB, 0 }, { HALT, 0 },
    };
    int r = vm.run(arith, 100)!!;
    assert(r == 19, "arith: got %d", r);
    io::printfn("arith = %d (steps %d)", r, vm.steps);

    // счётчик: n = 0; while (n < 5) n = n + 1; результат n
    Instr[] loop = {
        { PUSH, 0 },          // 0: n
        { DUP, 0 },           // 1: n n
        { PUSH, 5 },          // 2: n n 5
        { LT, 0 },            // 3: n (n<5)
        { JZ, 8 },            // 4: n
        { PUSH, 1 },          // 5: n 1
        { ADD, 0 },           // 6: n+1
        { JMP, 1 },           // 7
        { HALT, 0 },          // 8
    };
    r = vm.run(loop, 1000)!!;
    assert(r == 5, "loop: got %d", r);
    io::printfn("loop = %d (steps %d)", r, vm.steps);
    assert(vm.steps == 41);

    // тот же цикл, но бюджет мал: скрипт должен быть прерван, а не зависнуть
    if (catch err = vm.run(loop, 20))
    {
        assert(err == BUDGET_EXCEEDED);
        io::printfn("loop with budget 20: %s after %d steps", err, vm.steps);
        assert(vm.steps == 20);
    }
    else
    {
        unreachable("budget was not enforced");
    }

    // бесконечный цикл злонамеренного моддера
    Instr[] forever = { { JMP, 0 } };
    int? fr = vm.run(forever, 1000);
    if (catch err = fr) io::printfn("forever: %s", err);
    assert(@catch(fr) == BUDGET_EXCEEDED);

    // переполнение стека
    Instr[] bomb = { { PUSH, 1 }, { JMP, 0 } };
    int? br = vm.run(bomb, 1000);
    if (catch err = br) io::printfn("bomb: %s (sp = %d)", err, vm.sp);
    assert(@catch(br) == STACK_OVERFLOW);
    assert(vm.sp == STACK_MAX);

    // опустошение стека
    Instr[] under = { { PUSH, 1 }, { ADD, 0 }, { HALT, 0 } };
    int? ur = vm.run(under, 1000);
    if (catch err = ur) io::printfn("under: %s", err);
    assert(@catch(ur) == STACK_UNDERFLOW);

    // прыжок за пределы кода
    Instr[] wild = { { JMP, 99 } };
    int? wr = vm.run(wild, 1000);
    if (catch err = wr) io::printfn("wild: %s", err);
    assert(@catch(wr) == BAD_JUMP);

    // «упал» с конца программы без HALT — тоже BAD_JUMP
    Instr[] fall = { { PUSH, 1 } };
    assert(@catch(vm.run(fall, 1000)) == BAD_JUMP);

    io::printn("vm sandbox ok");
}
