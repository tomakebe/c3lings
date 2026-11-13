// =====================================================================
//  115 · Байткодовая виртуальная машина
// =====================================================================
//
//  Lua, Python, Ruby (YARV), Java (JVM), .NET, Wren, игровые скрипты
//  (UnrealScript, Squirrel), регулярки, eBPF в ядре Linux, шейдерные
//  интерпретаторы — внутри все они исполняют байткод: компактный поток
//  инструкций для воображаемого процессора.
//
//  ПОЧЕМУ БАЙТКОД, А НЕ ОБХОД AST
//  ------------------------------
//  Tree-walking интерпретатор прыгает по указателям узлов, разбросанных
//  по куче, и на каждом узле — виртуальный вызов/switch. Байткод — плотный
//  массив байт: отличная локальность, простая сериализация (кеш
//  скомпилированных скриптов), а цикл «прочитать опкод -> выполнить»
//  компилятор превращает в компактную таблицу переходов. Типичный выигрыш
//  — 3–10 раз.
//
//  СТЕКОВАЯ ИЛИ РЕГИСТРОВАЯ
//  ------------------------
//  * Стековая (JVM, CPython, WebAssembly, наша): операнды на стеке
//    значений, `ADD` снимает два и кладёт сумму. Простой компилятор,
//    короткие инструкции, но больше инструкций на выражение.
//  * Регистровая (Lua 5, Dalvik): `ADD r1, r2, r3`. Меньше инструкций и
//    диспетчеризаций, но инструкции длиннее и компилятор сложнее.
//
//  НАШ НАБОР ИНСТРУКЦИЙ (операнды — little-endian сразу после опкода)
//  ------------------------------------------------------------------
//      PUSH  i32        ... -> ... imm
//      POP              ... a -> ...
//      DUP              ... a -> ... a a
//      ADD SUB MUL DIV MOD LT EQ    ... a b -> ... (a op b)   (LT/EQ дают 0/1)
//      NOT              ... a -> ... (a == 0 ? 1 : 0)
//      JMP   i32        pc = addr
//      JZ    i32        ... a -> ...;  if (a == 0) pc = addr
//      LOAD  u8         ... -> ... stack[base + k]
//      STORE u8         ... a -> ...;  stack[base + k] = a
//      CALL  i32 u8     вызвать функцию по адресу addr с n аргументами
//      RET              ... v -> (вернуться, положить v на стек вызывающего)
//      PRINT            ... a -> ...;  напечатать a
//      HALT
//
//  КАДРЫ ВЫЗОВОВ. Аргументы уже лежат на стеке, когда выполняется CALL.
//  Кадр запоминает адрес возврата и старую базу; новая база =
//  sp - nargs, так что аргументы становятся локальными 0..nargs-1, а
//  выше функция может держать свои локальные через STORE в следующие
//  слоты (предварительно сделав PUSH для места). RET: снять значение,
//  sp = base (выбросить аргументы и локальные), восстановить pc и base,
//  положить значение.
//
//  ДИСПЕТЧЕРИЗАЦИЯ. Сердце VM — цикл со switch по опкоду. В C3 атрибут
//  `@jump` у switch гарантирует реализацию через таблицу переходов, а
//  `nextcase` внутри такого switch — переход по таблице прямо из конца
//  обработчика («threaded code», как computed goto в CPython/LuaJIT): у
//  каждого обработчика свой косвенный переход, и предсказатель ветвлений
//  учится на парах «инструкция -> следующая». Можно писать и обычный
//  `while (true) switch (...) @jump`, это тоже корректно.
//
//  БЕЗОПАСНОСТЬ. Байткод может прийти из файла — VM обязана проверять
//  переполнение/опустошение стека, деление на ноль, выход pc за код,
//  неизвестные опкоды, и сообщать об ошибке, а не падать. В C3 это
//  естественно выражается Optional: `fn int? Vm.run(...)`.
//
//  ЗАДАЧА: реализуйте Vm.exec — цикл исполнения. Помощники push/pop/
//  read_i32/read_u8 и ассемблер уже есть. Программы в main собраны
//  вручную; они проверят арифметику, циклы, рекурсию и ошибки.
//
import std::io;
import std::collections::list;

enum Op : char
{
    HALT, PUSH, POP, DUP,
    ADD, SUB, MUL, DIV, MOD, LT, EQ, NOT,
    JMP, JZ, LOAD, STORE, CALL, RET, PRINT,
}

excuse STACK_OVERFLOW, STACK_UNDERFLOW, DIV_BY_ZERO, BAD_OPCODE, PC_OUT_OF_RANGE;

const STACK_MAX = 256;
const FRAMES_MAX = 64;

struct Frame
{
    sz ret_pc;
    sz base;
}

struct Vm
{
    char[] code;
    sz pc;
    int[STACK_MAX] stack;
    sz sp;
    sz base;
    Frame[FRAMES_MAX] frames;
    sz fp;
    DString out;       // всё, что напечатал PRINT, через пробел
    long steps;
}

fn void? Vm.push(&self, int v) @inline
{
    if (self.sp >= STACK_MAX) return STACK_OVERFLOW~;
    self.stack[self.sp++] = v;
}

fn int? Vm.pop(&self) @inline
{
    if (self.sp <= self.base) return STACK_UNDERFLOW~;   // нельзя снимать чужой кадр
    return self.stack[--self.sp];
}

fn char? Vm.read_u8(&self) @inline
{
    if (self.pc >= self.code.len) return PC_OUT_OF_RANGE~;
    return self.code[self.pc++];
}

fn int? Vm.read_i32(&self) @inline
{
    if (self.pc + 4 > self.code.len) return PC_OUT_OF_RANGE~;
    uint v = self.code[self.pc] | (uint)self.code[self.pc + 1] << 8
           | (uint)self.code[self.pc + 2] << 16 | (uint)self.code[self.pc + 3] << 24;
    self.pc += 4;
    return (int)v;
}

fn void? Vm.jump(&self, int addr) @inline
{
    if (addr < 0 || addr >= self.code.len) return PC_OUT_OF_RANGE~;
    self.pc = addr;
}

// Исполнить код с начала. Результат — значение на вершине стека в момент HALT
// (или 0, если стек пуст).
fn int? Vm.exec(&self, char[] code)
{
    self.code = code;
    self.pc = 0;
    self.sp = 0;
    self.base = 0;
    self.fp = 0;
    self.out.clear();
    // TODO: цикл: прочитать опкод (read_u8), проверить, что он < Op::len
    //       (иначе BAD_OPCODE~), Op::from_ordinal(...), switch по нему.
    //       Используйте `!` для проброса ошибок помощников: `int b = self.pop()!;`
    //       PRINT: self.out.appendf("%d ", v). Каждый шаг: self.steps++.
    while (true)
    {
        self.steps++;
        char raw = self.read_u8()!;
        if (raw >= Op::len) return BAD_OPCODE~;
        switch (Op::from_ordinal(raw)) @jump
        {
            case HALT:
                return self.sp > 0 ? self.stack[self.sp - 1] : 0;
            case PUSH:
                self.push(self.read_i32()!)!;
            case POP:
                self.pop()!;
            case DUP:
                int a = self.pop()!;
                self.push(a)!;
                self.push(a)!;
            case ADD:
            case SUB:
            case MUL:
            case DIV:
            case MOD:
            case LT:
            case EQ:
                int b = self.pop()!;
                int a = self.pop()!;
                int r;
                switch (Op::from_ordinal(raw))
                {
                    case ADD: r = a + b;
                    case SUB: r = a - b;
                    case MUL: r = a * b;
                    case DIV:
                        if (b == 0) return DIV_BY_ZERO~;
                        r = a / b;
                    case MOD:
                        if (b == 0) return DIV_BY_ZERO~;
                        r = a % b;
                    case LT: r = a < b ? 1 : 0;
                    case EQ: r = a == b ? 1 : 0;
                    default: unreachable();
                }
                self.push(r)!;
            case NOT:
                self.push(self.pop()! == 0 ? 1 : 0)!;
            case JMP:
                self.jump(self.read_i32()!)!;
            case JZ:
                int addr = self.read_i32()!;
                if (self.pop()! == 0) self.jump(addr)!;
            case LOAD:
                sz slot = self.base + self.read_u8()!;
                if (slot >= self.sp) return STACK_UNDERFLOW~;
                self.push(self.stack[slot])!;
            case STORE:
                sz slot = self.base + self.read_u8()!;
                int v = self.pop()!;
                if (slot >= self.sp) return STACK_UNDERFLOW~;
                self.stack[slot] = v;
            case CALL:
                int addr = self.read_i32()!;
                char nargs = self.read_u8()!;
                if (self.fp >= FRAMES_MAX) return STACK_OVERFLOW~;
                if (self.sp - self.base < nargs) return STACK_UNDERFLOW~;
                self.frames[self.fp++] = { self.pc, self.base };
                self.base = self.sp - nargs;
                self.jump(addr)!;
            case RET:
                int v = self.pop()!;
                if (self.fp == 0) return STACK_UNDERFLOW~;
                Frame f = self.frames[--self.fp];
                self.sp = self.base;
                self.base = f.base;
                self.pc = f.ret_pc;
                self.push(v)!;
            case PRINT:
                self.out.appendf("%d ", self.pop()!);
        }
    }
}

// ---------------------------------------------------------------- ассемблер

struct Asm
{
    List{char} code;
}

fn void Asm.op(&self, Op op) => self.code.push((char)op.ordinal);
fn void Asm.i32(&self, int v)
{
    for (int i = 0; i < 4; i++) self.code.push((char)((uint)v >> (8 * i)));
}
fn void Asm.push(&self, int v) { self.op(PUSH); self.i32(v); }
fn void Asm.load(&self, char k) { self.op(LOAD); self.code.push(k); }
fn void Asm.store(&self, char k) { self.op(STORE); self.code.push(k); }
fn sz Asm.here(&self) => self.code.len();
// Переход вперёд: вернуть позицию операнда, чтобы потом пропатчить.
fn sz Asm.jump_fwd(&self, Op op) { self.op(op); sz at = self.here(); self.i32(-1); return at; }
fn void Asm.jump_to(&self, Op op, sz addr) { self.op(op); self.i32((int)addr); }
fn void Asm.patch(&self, sz at, sz addr)
{
    for (int i = 0; i < 4; i++) self.code[at + i] = (char)((uint)addr >> (8 * i));
}
fn void Asm.call(&self, sz addr, char nargs) { self.op(CALL); self.i32((int)addr); self.code.push(nargs); }

fn char[] Asm.finish(&self) => self.code.array_view();

// ---------------------------------------------------------------- программы

fn int? run(Vm* vm, Asm* a, String title)
{
    int? r = vm.exec(a.finish());
    if (catch err = r)
    {
        io::printfn("%-10s -> error %s", title, err);
        return err~;
    }
    io::printfn("%-10s -> %d   printed: %s", title, r, vm.out.str_view());
    return r;
}

fn void main()
{
    Vm* vm = mem::new(Vm);
    vm.out = dstring::new(mem);
    defer { vm.out.free(); free(vm); }

    // 1. (2 + 3) * 7 - 10 / 3
    Asm a;
    a.push(2); a.push(3); a.op(ADD); a.push(7); a.op(MUL);
    a.push(10); a.push(3); a.op(DIV); a.op(SUB); a.op(HALT);
    assert(run(vm, &a, "arith")!! == 32);
    a.code.free();

    // 2. sum = 0; i = 1; while (i < 101) { sum += i; i += 1 }; print sum
    //    локальные: 0 = sum, 1 = i
    Asm b;
    b.push(0); b.push(1);
    sz loop = b.here();
    b.load(1); b.push(101); b.op(LT);
    sz exit = b.jump_fwd(JZ);
    b.load(0); b.load(1); b.op(ADD); b.store(0);
    b.load(1); b.push(1); b.op(ADD); b.store(1);
    b.jump_to(JMP, loop);
    b.patch(exit, b.here());
    b.load(0); b.op(PRINT); b.load(0); b.op(HALT);
    assert(run(vm, &b, "sum")!! == 5050);
    b.code.free();

    // 3. рекурсивный fib(n): if (n < 2) return n; return fib(n-1) + fib(n-2)
    //    печатаем fib(0..15)
    Asm c;
    sz skip = c.jump_fwd(JMP);
    sz fib = c.here();
    c.load(0); c.push(2); c.op(LT);
    sz rec = c.jump_fwd(JZ);
    c.load(0); c.op(RET);
    c.patch(rec, c.here());
    c.load(0); c.push(1); c.op(SUB); c.call(fib, 1);
    c.load(0); c.push(2); c.op(SUB); c.call(fib, 1);
    c.op(ADD); c.op(RET);
    c.patch(skip, c.here());
    c.push(0);                                // локальная 0 = i
    sz l2 = c.here();
    c.load(0); c.push(16); c.op(LT);
    sz done = c.jump_fwd(JZ);
    c.load(0); c.call(fib, 1); c.op(PRINT);
    c.load(0); c.push(1); c.op(ADD); c.store(0);
    c.jump_to(JMP, l2);
    c.patch(done, c.here());
    c.push(20); c.call(fib, 1); c.op(HALT);
    vm.steps = 0;
    assert(run(vm, &c, "fib")!! == 6765);
    assert(vm.out.str_view() == "0 1 1 2 3 5 8 13 21 34 55 89 144 233 377 610 ");
    io::printfn("fib program executed %d instructions", vm.steps);
    c.code.free();

    // 4. ошибки
    Asm d;
    d.push(1); d.push(0); d.op(DIV); d.op(HALT);
    assert(@catch(run(vm, &d, "div0")) == DIV_BY_ZERO);
    d.code.free();

    Asm e;
    e.op(ADD); e.op(HALT);
    assert(@catch(run(vm, &e, "underflow")) == STACK_UNDERFLOW);
    e.code.free();

    Asm f;
    sz top = f.here();
    f.push(1); f.jump_to(JMP, top);           // бесконечный push
    assert(@catch(run(vm, &f, "overflow")) == STACK_OVERFLOW);
    f.code.free();

    Asm g;
    sz self_call = g.here();
    g.call(self_call, 0);                     // бесконечная рекурсия
    assert(@catch(run(vm, &g, "deep")) == STACK_OVERFLOW);
    g.code.free();

    char[*] junk = { 200 };
    assert(@catch(vm.exec(&junk)) == BAD_OPCODE);
    char[*] trunc = { (char)Op.PUSH.ordinal, 1, 2 };
    assert(@catch(vm.exec(&trunc)) == PC_OUT_OF_RANGE);
    io::printn("all VM checks passed");
}
