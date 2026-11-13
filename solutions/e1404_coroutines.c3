// =====================================================================
//  e1404 · Сопрограммы для геймплея: WAIT, планировщик, квант времени
// =====================================================================
//
//  Сначала прочитайте engine/docs/14_scripting.md (раздел «Сопрограммы»).
//
//  Геймплей — это последовательности во времени: «открыть дверь,
//  подождать 3 секунды, закрыть». Без сопрограмм это превращается в
//  конечный автомат с полем `state` и таймером в каждом объекте. Со
//  сопрограммами скрипт пишется линейно:
//
//      say "opens"
//      wait 3
//      say "closes"
//
//  Как это устроено. Наша VM не использует стек хоста для выполнения
//  скрипта: pc, стек значений и локальные переменные лежат в структуре
//  Script. Значит, «приостановить» скрипт — это просто ВЫЙТИ из
//  resume(), сохранив pc. Следующий resume() продолжит с того же места.
//  Такие сопрограммы называют stackless (по отношению к хосту) — они
//  дешёвые: тысяча скриптов = тысяча маленьких структур, а не тысяча
//  стеков ОС.
//
//      tick 0           tick 1          tick 2          tick 3
//      door: SAY,WAIT  (спит)          (спит)          SAY, END
//            ^ return                                  ^ resume с pc=2
//
//  Планировщик (Scheduler) на каждом тике:
//    1. будит скрипты, у которых `now >= wake_tick` (WAITING -> READY);
//    2. даёт каждому готовому скрипту ОДИН квант (resume) — в порядке
//       добавления, так что всё детерминировано;
//    3. если скрипт упал (в т.ч. съел весь квант SLICE_BUDGET, не дойдя
//       до WAIT — классический «забыл yield в цикле»), помечает его
//       FAULTED и продолжает работать с остальными. Один плохой скрипт
//       не должен вешать игру.
//
//  WAIT n: уснуть на n тиков; WAIT 0 означает «уступить до следующего
//  тика» (то есть wake_tick = now + 1, как и для n = 1).
//
//  ЗАДАЧА:
//    * в Script.resume реализуйте WAIT (state, wake_tick, выход) и END;
//    * в Scheduler.tick — пробуждение и обработку ошибки скрипта
//      (state = FAULTED, сохранить error, напечатать
//      "t=<now> <name>: FAULT <error>").
//
module script_coroutines;
import std::io;

excuse STACK_OVERFLOW, STACK_UNDERFLOW, BUDGET_EXCEEDED;

enum Op : char
{
    PUSH,   // push(arg)
    POP,
    DUP,
    ADD,    // a b -> a+b
    LOAD,   // push(locals[arg])
    STORE,  // locals[arg] = pop()
    JNZ,    // if pop() != 0: pc = arg
    JMP,
    SAY,    // напечатать strings[arg]
    SAYV,   // напечатать strings[arg] и pop()
    WAIT,   // уснуть на arg тиков (минимум 1) — точка yield
    END,    // скрипт завершён
}

struct Instr { Op op; int arg; }

enum State : char
{
    READY,
    WAITING,
    DONE,
    FAULTED,
}

const int STACK_MAX = 8;
const int SLICE_BUDGET = 64;   // сколько инструкций скрипт может выполнить за один resume

// Всё состояние сопрограммы лежит ЗДЕСЬ, а не на стеке хоста.
// Поэтому yield — это просто return из resume(), а продолжение —
// повторный вызов resume() с того же pc.
struct Script
{
    String name;
    Instr[] code;
    String[] strings;
    int pc;
    int[STACK_MAX] stack;
    int sp;
    int[4] locals;
    State state;
    long wake_tick;
    fault error;
}

fn void? Script.push(&self, int v)
{
    if (self.sp >= STACK_MAX) return STACK_OVERFLOW~;
    self.stack[self.sp++] = v;
}

fn int? Script.pop(&self)
{
    if (self.sp <= 0) return STACK_UNDERFLOW~;
    return self.stack[--self.sp];
}

// Выполняет скрипт, пока он не уснёт (WAIT), не закончится (END)
// или не исчерпает бюджет кванта. Возвращает ошибку, если скрипт упал.
fn void? Script.resume(&self, long now)
{
    for (int steps = 0; steps < SLICE_BUDGET; steps++)
    {
        Instr ins = self.code[self.pc++];
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
            case LOAD: self.push(self.locals[ins.arg])!;
            case STORE: self.locals[ins.arg] = self.pop()!;
            case JNZ: if (self.pop()! != 0) self.pc = ins.arg;
            case JMP: self.pc = ins.arg;
            case SAY:
                io::printfn("t=%d %s: %s", now, self.name, self.strings[ins.arg]);
            case SAYV:
                io::printfn("t=%d %s: %s %d", now, self.name, self.strings[ins.arg], self.pop()!);
            case WAIT:
                self.state = WAITING;
                self.wake_tick = now + (ins.arg < 1 ? 1 : ins.arg);
                return;
            case END:
                self.state = DONE;
                return;
        }
    }
    return BUDGET_EXCEEDED~;
}

struct Scheduler
{
    Script*[8] scripts;
    int count;
    long now;
}

fn void Scheduler.add(&self, Script* s)
{
    s.state = READY;
    s.pc = 0;
    s.sp = 0;
    self.scripts[self.count++] = s;
}

// Один игровой тик: будим тех, чьё время пришло, и даём каждому
// готовому скрипту один квант. Порядок — порядок добавления, поэтому
// результат детерминирован.
fn void Scheduler.tick(&self)
{
    for (int i = 0; i < self.count; i++)
    {
        Script* s = self.scripts[i];
        if (s.state == WAITING && self.now >= s.wake_tick) s.state = READY;
        if (s.state != READY) continue;
        if (catch err = s.resume(self.now))
        {
            s.state = FAULTED;
            s.error = err;
            io::printfn("t=%d %s: FAULT %s", self.now, s.name, err);
        }
    }
    self.now++;
}

fn bool Scheduler.all_finished(&self)
{
    for (int i = 0; i < self.count; i++)
    {
        State st = self.scripts[i].state;
        if (st != DONE && st != FAULTED) return false;
    }
    return true;
}

fn void main()
{
    // дверь: открыться, подождать 3 тика, закрыться
    Script door = {
        .name = "door",
        .strings = { "opens", "closes" },
        .code = {
            { SAY, 0 }, { WAIT, 3 }, { SAY, 1 }, { END, 0 },
        },
    };

    // стражник: обойти 3 точки, на каждой постоять 2 тика
    //   locals[0] = 3
    //   loop: SAYV "patrol, left" locals[0]
    //         locals[0] += -1 ; WAIT 2 ; if locals[0] != 0 goto loop
    Script guard = {
        .name = "guard",
        .strings = { "patrol, left", "done" },
        .code = {
            { PUSH, 3 }, { STORE, 0 },                       // 0..1
            { LOAD, 0 }, { SAYV, 0 },                        // 2..3  loop:
            { LOAD, 0 }, { PUSH, -1 }, { ADD, 0 }, { STORE, 0 }, // 4..7
            { WAIT, 2 },                                     // 8
            { LOAD, 0 }, { JNZ, 2 },                         // 9..10
            { SAY, 1 }, { END, 0 },                          // 11..12
        },
    };

    // багованный скрипт моддера: забыл WAIT в цикле
    Script hog = {
        .name = "hog",
        .strings = { "spinning" },
        .code = {
            { SAY, 0 }, { WAIT, 1 },
            { JMP, 2 },
        },
    };

    // уступает кадр каждый тик (WAIT 0 == «до следующего тика»)
    Script blink = {
        .name = "blink",
        .strings = { "on", "off" },
        .code = {
            { SAY, 0 }, { WAIT, 0 }, { SAY, 1 }, { WAIT, 0 }, { SAY, 0 }, { END, 0 },
        },
    };

    Scheduler sched;
    sched.add(&door);
    sched.add(&guard);
    sched.add(&hog);
    sched.add(&blink);

    while (!sched.all_finished())
    {
        assert(sched.now < 100, "scheduler never finished");
        sched.tick();
    }

    io::printfn("finished at t=%d", sched.now);
    assert(door.state == DONE && guard.state == DONE && blink.state == DONE);
    assert(hog.state == FAULTED && hog.error == BUDGET_EXCEEDED);
    assert(guard.locals[0] == 0);
    assert(sched.now == 7);
    io::printn("coroutines ok");
}
