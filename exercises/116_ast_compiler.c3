// =====================================================================
//  116 · Компилятор AST -> байткод
// =====================================================================
//
//  В упражнении 115 программы собирались руками. Теперь пишем то, что
//  стоит между парсером и VM в любом скриптовом языке: компилятор,
//  превращающий дерево (AST) в линейный байткод. Clang/rustc делают
//  то же самое (AST -> IR), только с бóльшим числом шагов.
//
//  ГЛАВНЫЕ ПРИЁМЫ
//  --------------
//  1. Выражения на стековой машине — это обход дерева в ПОСТФИКСНОМ
//     порядке: сначала скомпилировать левое поддерево (его значение
//     окажется на стеке), потом правое, потом опкод операции.
//     `(a + 2) * b`  ->  LOAD a; PUSH 2; ADD; LOAD b; MUL
//
//  2. Переменные разрешаются при КОМПИЛЯЦИИ в номера слотов: VM не знает
//     имён, только `LOAD 3`. Мы делаем предварительный проход, собираем
//     все `let` (функциональная область видимости, как `var` в JS),
//     в начале программы резервируем по `PUSH 0` на каждую переменную,
//     и дальше имя -> слот. Обращение к необъявленному имени — ошибка
//     компиляции, а не времени исполнения.
//
//  3. Управление потоком — переходы с ЗАПЛАТКАМИ (backpatching). Когда
//     компилируем `if`, адрес конца ещё неизвестен: выпускаем
//     `JZ ????`, запоминаем позицию операнда, компилируем тело и потом
//     вписываем настоящий адрес:
//
//         <cond>                    while:   top: <cond>
//         JZ else_                             JZ end
//         <then>                               <body>
//         JMP end                              JMP top      (назад — адрес известен)
//       else_: <else>                        end:
//       end:
//
//  4. Ленивые && и || тоже компилируются в переходы: правая часть
//     не вычисляется, если результат ясен по левой (`d != 0 && x / d > 1`
//     не должен делить на ноль!). Результат нормализуем к 0/1 через
//     двойной NOT.
//         a && b:  <a>; JZ f; <b>; NOT; NOT; JMP end; f: PUSH 0; end:
//         a || b:  <a>; JZ r; PUSH 1; JMP end; r: <b>; NOT; NOT; end:
//
//  5. У VM есть только LT и EQ. Остальное — перестановки и NOT:
//     a > b == b < a;  a <= b == !(b < a);  a >= b == !(a < b);  a != b == !(a == b).
//     (Перестановка операндов меняет порядок вычисления — у нас выражения
//     без побочных эффектов, но в языке с вызовами функций так делать
//     нельзя без временных переменных.)
//
//  6. Свёртка констант (constant folding) — простейшая оптимизация:
//     если поддерево состоит только из чисел, вычислим его при
//     компиляции и выпустим один PUSH. `2 * 3 + 4` -> `PUSH 10`.
//     Деление на константный ноль НЕ сворачиваем — ошибка должна
//     произойти там же и тогда же, что и без оптимизации. Это общий
//     принцип: оптимизация не меняет наблюдаемое поведение.
//
//  ЗАДАЧА: реализуйте const_value, Compiler.expr и Compiler.stmt.
//  VM (из 115, плюс NEG), AST, предварительный проход и обвязка готовы.
//
import std::io;
import std::collections::list;

// ================================================================ VM (готово)

enum Op : char
{
    HALT, PUSH, POP, ADD, SUB, MUL, DIV, MOD, LT, EQ, NOT, NEG,
    JMP, JZ, LOAD, STORE, PRINT,
}

excuse STACK_OVERFLOW, STACK_UNDERFLOW, DIV_BY_ZERO, BAD_CODE;

struct Vm
{
    int[256] stack;
    sz sp;
    DString out;
}

fn int? Vm.run(&self, char[] code)
{
    sz pc = 0;
    self.sp = 0;
    self.out.clear();
    while (true)
    {
        if (pc >= code.len) return BAD_CODE~;
        char raw = code[pc++];
        if (raw >= Op::len) return BAD_CODE~;
        Op op = Op::from_ordinal(raw);
        int imm;
        if (op == PUSH || op == JMP || op == JZ)
        {
            if (pc + 4 > code.len) return BAD_CODE~;
            imm = (int)((uint)code[pc] | (uint)code[pc + 1] << 8 | (uint)code[pc + 2] << 16 | (uint)code[pc + 3] << 24);
            pc += 4;
        }
        if (op == LOAD || op == STORE)
        {
            if (pc >= code.len) return BAD_CODE~;
            imm = code[pc++];
        }
        switch (op) @jump
        {
            case HALT: return self.sp > 0 ? self.stack[self.sp - 1] : 0;
            case PUSH:
                if (self.sp >= 256) return STACK_OVERFLOW~;
                self.stack[self.sp++] = imm;
            case POP:
                if (self.sp < 1) return STACK_UNDERFLOW~;
                self.sp--;
            case ADD: case SUB: case MUL: case DIV: case MOD: case LT: case EQ:
                if (self.sp < 2) return STACK_UNDERFLOW~;
                int b = self.stack[--self.sp];
                int a = self.stack[self.sp - 1];
                int r;
                switch (op)
                {
                    case ADD: r = a + b;
                    case SUB: r = a - b;
                    case MUL: r = a * b;
                    case DIV: if (b == 0) return DIV_BY_ZERO~; r = a / b;
                    case MOD: if (b == 0) return DIV_BY_ZERO~; r = a % b;
                    case LT: r = a < b ? 1 : 0;
                    case EQ: r = a == b ? 1 : 0;
                    default: unreachable();
                }
                self.stack[self.sp - 1] = r;
            case NOT:
                if (self.sp < 1) return STACK_UNDERFLOW~;
                self.stack[self.sp - 1] = self.stack[self.sp - 1] == 0 ? 1 : 0;
            case NEG:
                if (self.sp < 1) return STACK_UNDERFLOW~;
                self.stack[self.sp - 1] = -self.stack[self.sp - 1];
            case JMP:
                pc = imm;
            case JZ:
                if (self.sp < 1) return STACK_UNDERFLOW~;
                if (self.stack[--self.sp] == 0) pc = imm;
            case LOAD:
                if (imm >= self.sp) return BAD_CODE~;
                if (self.sp >= 256) return STACK_OVERFLOW~;
                self.stack[self.sp++] = self.stack[imm];
            case STORE:
                if (self.sp < 1 || imm >= self.sp - 1) return BAD_CODE~;
                self.stack[imm] = self.stack[--self.sp];
            case PRINT:
                if (self.sp < 1) return STACK_UNDERFLOW~;
                self.out.appendf("%d ", self.stack[--self.sp]);
        }
    }
}

// ================================================================ AST (готово)

enum ExprKind : char { NUM, VAR, NEG, NOT, BIN }
enum BinOp : char { ADD, SUB, MUL, DIV, MOD, LT, GT, LE, GE, EQ, NE, AND, OR }

struct Expr
{
    ExprKind kind;
    int value;          // NUM
    String name;        // VAR
    BinOp op;           // BIN
    Expr* lhs;          // BIN; операнд NEG/NOT
    Expr* rhs;          // BIN
}

enum StmtKind : char { LET, SET, PRINT, IF, WHILE }

struct Stmt
{
    StmtKind kind;
    String name;        // LET, SET
    Expr* expr;         // значение / условие
    Stmt*[] body;       // IF (then), WHILE
    Stmt*[] else_body;  // IF
}

// Конструкторы (узлы живут во временной арене — освобождаются разом в конце @pool).
fn Expr* num(int v) => mem::tnew(Expr, { .kind = NUM, .value = v });
fn Expr* v(String name) => mem::tnew(Expr, { .kind = VAR, .name = name });
fn Expr* neg(Expr* e) => mem::tnew(Expr, { .kind = NEG, .lhs = e });
fn Expr* not(Expr* e) => mem::tnew(Expr, { .kind = NOT, .lhs = e });
fn Expr* bin(BinOp op, Expr* l, Expr* r) => mem::tnew(Expr, { .kind = BIN, .op = op, .lhs = l, .rhs = r });
fn Stmt* s_let(String name, Expr* e) => mem::tnew(Stmt, { .kind = LET, .name = name, .expr = e });
fn Stmt* s_set(String name, Expr* e) => mem::tnew(Stmt, { .kind = SET, .name = name, .expr = e });
fn Stmt* s_print(Expr* e) => mem::tnew(Stmt, { .kind = PRINT, .expr = e });
fn Stmt* s_while(Expr* c, Stmt*... body) => mem::tnew(Stmt, { .kind = WHILE, .expr = c, .body = @tclone_slice(body) });
fn Stmt* s_if(Expr* c, Stmt*[] then, Stmt*[] els = {}) => mem::tnew(Stmt, { .kind = IF, .expr = c, .body = @tclone_slice(then), .else_body = @tclone_slice(els) });

// ================================================================ компилятор

excuse UNDEFINED_VARIABLE, TOO_MANY_LOCALS;

struct Compiler
{
    List{char} code;
    List{String} locals;
}

fn void Compiler.emit(&self, Op op) => self.code.push((char)op.ordinal);
fn void Compiler.emit_i32(&self, int x)
{
    for (int i = 0; i < 4; i++) self.code.push((char)((uint)x >> (8 * i)));
}
fn void Compiler.emit_push(&self, int x) { self.emit(PUSH); self.emit_i32(x); }
fn void Compiler.emit_slot(&self, Op op, char slot) { self.emit(op); self.code.push(slot); }
fn sz Compiler.here(&self) => self.code.len();
// Выпустить переход с неизвестным адресом; вернуть позицию операнда.
fn sz Compiler.emit_jump(&self, Op op) { self.emit(op); sz at = self.here(); self.emit_i32(-1); return at; }
// Вписать в операнд перехода текущий адрес.
fn void Compiler.patch_here(&self, sz at)
{
    sz target = self.here();
    for (int i = 0; i < 4; i++) self.code[at + i] = (char)((uint)target >> (8 * i));
}
fn void Compiler.emit_jump_to(&self, Op op, sz target) { self.emit(op); self.emit_i32((int)target); }

fn char? Compiler.slot_of(&self, String name)
{
    foreach (i, l : self.locals) if (l == name) return (char)i;
    return UNDEFINED_VARIABLE~;
}

fn void? Compiler.declare_all(&self, Stmt*[] stmts)
{
    foreach (s : stmts)
    {
        if (s.kind == LET && !@ok(self.slot_of(s.name)))
        {
            if (self.locals.len() >= 250) return TOO_MANY_LOCALS~;
            self.locals.push(s.name);
        }
        self.declare_all(s.body)!;
        self.declare_all(s.else_body)!;
    }
}

// Значение выражения, если оно вычислимо при компиляции.
// Переменные — не константы. Деление/остаток на ноль — не сворачивать.
// AND/OR сворачиваются, только если обе части константны.
fn int? const_value(Expr* e)
{
    // TODO
    return UNDEFINED_VARIABLE~;
}

fn void? Compiler.expr(&self, Expr* e)
{
    // TODO: 1) если const_value(e) удалось — PUSH и выйти;
    //       2) VAR -> LOAD слот; NEG/NOT -> операнд + опкод;
    //       3) BIN: AND/OR через переходы, сравнения через LT/EQ/NOT,
    //          арифметика: lhs, rhs, опкод.
}

fn void? Compiler.stmt(&self, Stmt* s)
{
    // TODO: LET/SET -> выражение + STORE; PRINT -> выражение + PRINT;
    //       IF и WHILE — с заплатками (см. шапку). Пустой else — без лишнего JMP.
}

// Скомпилировать программу. Результат программы — значение переменной
// `result` (если она есть): её мы кладём на стек перед HALT.
fn char[]? Compiler.compile(&self, Stmt*[] prog)
{
    self.code.clear();
    self.locals.clear();
    self.declare_all(prog)!;
    foreach (l : self.locals) self.emit_push(0);
    foreach (s : prog) self.stmt(s)!;
    if (try slot = self.slot_of("result")) self.emit_slot(LOAD, slot);
    self.emit(HALT);
    return self.code.array_view();
}

// ================================================================ проверка

fn int? run(Compiler* c, Vm* vm, String title, Stmt*[] prog)
{
    char[] code = c.compile(prog)!;
    int r = vm.run(code)!;
    io::printfn("%-8s %4d bytes -> result=%d out: %s", title, code.len, r, vm.out.str_view());
    return r;
}

fn void main()
{
    Compiler c;
    c.code.init(mem);
    c.locals.init(mem);
    Vm vm;
    // Важно: нулевой DString/List при первом росте берёт ВРЕМЕННЫЙ аллокатор
    // (tmem). Первый appendf случится внутри @pool — память исчезнет вместе с ним.
    vm.out = dstring::new(mem);
    defer { c.code.free(); c.locals.free(); vm.out.free(); }

    @pool()
    {
        // 1. Свёртка констант: let result = 2 * 3 + 4 * (10 - 8) - -1
        Stmt*[*] p1 = {
            s_let("result", bin(SUB, bin(ADD, bin(MUL, num(2), num(3)), bin(MUL, num(4), bin(SUB, num(10), num(8)))), neg(num(-1)))),
        };
        assert(run(&c, &vm, "fold", &p1)!! == 13);
        // PUSH 0 (5) + PUSH 13 (5) + STORE (2) + LOAD (2) + HALT (1)
        assert(c.code.len() == 15, "expression was not folded: %d bytes", c.code.len());

        // 2. Фибоначчи циклом
        Stmt*[*] p2 = {
            s_let("a", num(0)), s_let("b", num(1)), s_let("n", num(12)),
            s_while(bin(GT, v("n"), num(0)),
                s_print(v("a")),
                s_let("t", bin(ADD, v("a"), v("b"))),
                s_set("a", v("b")),
                s_set("b", v("t")),
                s_set("n", bin(SUB, v("n"), num(1)))),
            s_let("result", v("a")),
        };
        assert(run(&c, &vm, "fib", &p2)!! == 144);
        assert(vm.out.str_view() == "0 1 1 2 3 5 8 13 21 34 55 89 ");

        // 3. FizzBuzz-коды: 15 -> -15, 3 -> -3, 5 -> -5, иначе число
        Stmt*[*] p3 = {
            s_let("i", num(1)),
            s_while(bin(LE, v("i"), num(15)),
                s_if(bin(AND, bin(EQ, bin(MOD, v("i"), num(3)), num(0)), bin(EQ, bin(MOD, v("i"), num(5)), num(0))),
                    { s_print(num(-15)) },
                    { s_if(bin(EQ, bin(MOD, v("i"), num(3)), num(0)),
                        { s_print(num(-3)) },
                        { s_if(bin(NE, bin(MOD, v("i"), num(5)), num(0)),
                            { s_print(v("i")) },
                            { s_print(num(-5)) }) }) }),
                s_set("i", bin(ADD, v("i"), num(1)))),
        };
        run(&c, &vm, "fizz", &p3)!!;
        assert(vm.out.str_view() == "1 2 -3 4 -5 -3 7 8 -3 -5 11 -3 13 14 -15 ");

        // 4. Простые числа < 60 — вложенные циклы и ||, >=
        Stmt*[*] p4 = {
            s_let("n", num(2)), s_let("result", num(0)),
            s_while(bin(LT, v("n"), num(60)),
                s_let("d", num(2)), s_let("prime", num(1)),
                s_while(bin(AND, v("prime"), not(bin(GT, bin(MUL, v("d"), v("d")), v("n")))),
                    s_if(bin(EQ, bin(MOD, v("n"), v("d")), num(0)), { s_set("prime", num(0)) }),
                    s_set("d", bin(ADD, v("d"), num(1)))),
                s_if(bin(OR, bin(GE, v("n"), num(50)), not(v("prime"))), {}, { s_print(v("n")) }),
                s_set("result", bin(ADD, v("result"), v("prime"))),
                s_set("n", bin(ADD, v("n"), num(1)))),
        };
        assert(run(&c, &vm, "primes", &p4)!! == 17);

        // 5. && не вычисляет правую часть: деления на ноль нет
        Stmt*[*] p5 = {
            s_let("z", num(0)),
            s_let("result", bin(OR, bin(AND, v("z"), bin(DIV, num(1), v("z"))), bin(GT, num(3), v("z")))),
        };
        assert(run(&c, &vm, "lazy", &p5)!! == 1, "&& / || must short-circuit and yield 0/1");

        // 6. деление на константный ноль не сворачивается, а падает при исполнении
        Stmt*[*] p6 = { s_let("result", bin(DIV, num(1), num(0))) };
        assert(@catch(run(&c, &vm, "div0", &p6)) == DIV_BY_ZERO);
        // 7. необъявленная переменная — ошибка компиляции
        Stmt*[*] p7 = { s_print(v("ghost")) };
        assert(@catch(c.compile(&p7)) == UNDEFINED_VARIABLE);
    };
    io::printn("compiler OK");
}
