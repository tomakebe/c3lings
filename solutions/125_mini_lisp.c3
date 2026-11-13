// =====================================================================
//  125 · Финальный босс: интерпретатор мини-Lisp
// =====================================================================
//
//  Последнее упражнение собирает всё вместе: рекурсивные структуры
//  данных, арены, Optional-ошибки, таблицы функций, разбор текста и
//  — главное — вычислитель (evaluator), сердце любого языка.
//
//  Lisp выбран не случайно. Его синтаксис — это сразу его AST:
//  `(+ 1 (* 2 3))` — список из символа `+`, числа и вложенного списка.
//  Парсер тривиален, и всё внимание достаётся семантике: окружениям,
//  замыканиям, особым формам, хвостовым вызовам. Скриптовые языки
//  игр (GOAL в Jak & Daxter, Lisp в AutoCAD и Emacs, Scheme в
//  GIMP/Guile, Janet, Fennel) и конфиги многих систем растут отсюда.
//
//  УСТРОЙСТВО (что уже написано)
//  -----------------------------
//  * Value — один тип на все значения, с тегом Kind: NIL (пустой
//    список `()`), BOOL (#t/#f), NUM (long), SYM, PAIR (cons-ячейка:
//    car + cdr), BUILTIN (указатель на функцию C3), LAMBDA (параметры,
//    тело, окружение — ЗАМЫКАНИЕ). Список (1 2 3) — это цепочка пар
//    (1 . (2 . (3 . ()))).
//  * Память: все значения выделяются во временной арене (`mem::tnew`
//    внутри @pool в main). Сборщика мусора нет — арена освобождается
//    целиком в конце. Для скриптов уровня/кадра это реальная стратегия;
//    долгоживущему интерпретатору нужен GC (mark-sweep по корням).
//  * Reader — рекурсивный спуск по тексту, `'x` — сахар для (quote x).
//  * Printer — обратно в текст.
//  * Встроенные функции: + - * / < = > cons car cdr list null? eq? not.
//  * Env — цепочка кадров; кадр — связный список привязок имя->значение.
//    Поиск идёт от текущего кадра к родителям (лексическая область
//    видимости). define создаёт привязку в ТЕКУЩЕМ кадре, set! меняет
//    СУЩЕСТВУЮЩУЮ (ищет вверх по цепочке).
//
//  ВЫЧИСЛИТЕЛЬ — ВАША ЗАДАЧА
//  -------------------------
//  eval(x, env):
//  * число, булево, (), функции — вычисляются сами в себя;
//  * символ — значение из окружения (нет — UNBOUND_SYMBOL);
//  * список (head args...) — либо ОСОБАЯ ФОРМА (head — символ из
//    списка ниже, аргументы вычисляются по своим правилам), либо
//    ВЫЗОВ: вычислить head и все аргументы, затем применить.
//
//  Особые формы:
//      (quote x)                   x без вычисления
//      (if c a b?)                 b по умолчанию — ()
//      (define name expr)          привязать в текущем кадре; результат — символ name
//      (define (f p...) body...)   сахар для (define f (lambda (p...) body...))
//      (lambda (p...) body...)     замыкание: запомнить ТЕКУЩЕЕ окружение!
//      (let ((n v)...) body...)    новый кадр; v вычисляются в СТАРОМ окружении
//      (begin e...)                по очереди; результат — последнее ( () если пусто)
//      (set! name expr)            изменить существующую привязку; результат — значение
//      (and e...) / (or e...)      ленивые; (and) = #t, (or) = #f; результат — последнее
//                                  вычисленное значение
//  Ложь — только #f и (). Всё остальное (включая 0) — истина.
//
//  Применение lambda: новый кадр, родитель — окружение ЗАМЫКАНИЯ (не
//  вызывающего! это и есть лексическая область видимости), параметры
//  привязаны к аргументам; число аргументов должно совпадать
//  (ARITY_MISMATCH). Тело — как begin. Не функция — NOT_A_FUNCTION.
//
//  ХВОСТОВЫЕ ВЫЗОВЫ (TCO)
//  ----------------------
//  В Lisp циклы пишутся рекурсией: (count-to n acc) вызывает сам себя
//  последним действием. Наивный eval на каждом шаге уходит в рекурсию
//  C3 — и 100 000 итераций переполнят стек. Решение — eval как ЦИКЛ:
//  когда результат формы — это значение другого выражения в «хвостовой
//  позиции» (ветка if, последнее выражение begin/let/тела lambda, последний
//  аргумент and/or), не вызываем eval рекурсивно, а заменяем x (и env) и
//  идём на следующую итерацию `while (true)`. Рекурсивные вызовы eval
//  остаются только для НЕхвостовых позиций (условие if, аргументы,
//  не-последние выражения). Scheme ТРЕБУЕТ это по стандарту. main
//  проверяет TCO, измеряя максимальную глубину рекурсии eval.
//
//  ЗАДАЧА: реализуйте Env.lookup/define/set и eval. Остальное готово.
//  Ожидаемый вывод — в checks; ошибки должны быть ровно такими, как там.
//
module lisp;
import std::io;

excuse UNBOUND_SYMBOL, NOT_A_FUNCTION, ARITY_MISMATCH, TYPE_ERROR, SYNTAX_ERROR, DIV_BY_ZERO, BAD_FORM;

// ================================================================ значения

enum Kind : char { NIL, BOOL, NUM, SYM, PAIR, BUILTIN, LAMBDA }

alias BuiltinFn = fn Value*?(Value* args);

struct Value
{
    Kind kind;
    long num;           // NUM; BOOL: 0/1
    String sym;         // SYM; имя BUILTIN
    Value* car;         // PAIR; LAMBDA: параметры
    Value* cdr;         // PAIR; LAMBDA: тело (список выражений)
    Env* env;           // LAMBDA
    BuiltinFn builtin;  // BUILTIN
}

Value nil_value = { .kind = NIL };
Value true_value = { .kind = BOOL, .num = 1 };
Value false_value = { .kind = BOOL, .num = 0 };
Value* nil = &nil_value;

fn Value* make_num(long n) => mem::tnew(Value, { .kind = NUM, .num = n });
fn Value* make_sym(String s) => mem::tnew(Value, { .kind = SYM, .sym = s });
fn Value* cons(Value* a, Value* b) => mem::tnew(Value, { .kind = PAIR, .car = a, .cdr = b });
fn Value* make_bool(bool b) => b ? &true_value : &false_value;
fn Value* make_lambda(Value* params, Value* body, Env* env) => mem::tnew(Value, { .kind = LAMBDA, .car = params, .cdr = body, .env = env });

fn bool Value.is_truthy(&self) => !(self.kind == NIL || (self.kind == BOOL && self.num == 0));
fn bool Value.is_sym(&self, String name) => self.kind == SYM && self.sym == name;

fn Value*? Value.first(&self) => self.kind == PAIR ? self.car : BAD_FORM~;
fn Value*? Value.rest(&self) => self.kind == PAIR ? self.cdr : BAD_FORM~;
fn Value*? Value.second(&self) => self.rest()!.first();
fn Value*? Value.third(&self) => self.rest()!.rest()!.first();

fn sz Value.length(&self)
{
    sz n = 0;
    for (Value* v = self; v.kind == PAIR; v = v.cdr) n++;
    return n;
}

// ================================================================ окружение

struct Binding
{
    String name;
    Value* value;
    Binding* next;
}

struct Env
{
    Binding* first;
    Env* parent;
}

fn Env* new_env(Env* parent) => mem::tnew(Env, { .parent = parent });

fn Value*? Env.lookup(&self, String name)
{
    // TODO: искать в этом кадре, затем в родителях; нет — UNBOUND_SYMBOL~
    for (Env* e = self; e; e = e.parent)
    {
        for (Binding* b = e.first; b; b = b.next)
        {
            if (b.name == name) return b.value;
        }
    }
    return UNBOUND_SYMBOL~;
}

// Создать (или перезаписать) привязку в ЭТОМ кадре.
fn void Env.define(&self, String name, Value* value)
{
    // TODO
    for (Binding* b = self.first; b; b = b.next)
    {
        if (b.name == name)
        {
            b.value = value;
            return;
        }
    }
    self.first = mem::tnew(Binding, { name, value, self.first });
}

// Изменить существующую привязку (ближайшую по цепочке).
fn void? Env.set(&self, String name, Value* value)
{
    // TODO
    for (Env* e = self; e; e = e.parent)
    {
        for (Binding* b = e.first; b; b = b.next)
        {
            if (b.name == name)
            {
                b.value = value;
                return;
            }
        }
    }
    return UNBOUND_SYMBOL~;
}

// ================================================================ reader

struct Reader
{
    String src;
    sz pos;
}

fn void Reader.skip_space(&self)
{
    while (self.pos < self.src.len)
    {
        char c = self.src[self.pos];
        if (c == ';')
        {
            while (self.pos < self.src.len && self.src[self.pos] != '\n') self.pos++;
        }
        else if (c == ' ' || c == '\n' || c == '\t' || c == '\r')
        {
            self.pos++;
        }
        else
        {
            break;
        }
    }
}

fn bool Reader.at_end(&self)
{
    self.skip_space();
    return self.pos >= self.src.len;
}

fn Value*? Reader.read(&self)
{
    self.skip_space();
    if (self.pos >= self.src.len) return SYNTAX_ERROR~;
    char c = self.src[self.pos];
    switch (c)
    {
        case '(':
            self.pos++;
            return self.read_list();
        case ')':
            return SYNTAX_ERROR~;
        case '\'':
            self.pos++;
            return cons(make_sym("quote"), cons(self.read()!, nil));
        default:
            sz start = self.pos;
            while (self.pos < self.src.len)
            {
                char d = self.src[self.pos];
                if (d == '(' || d == ')' || d == ' ' || d == '\n' || d == '\t' || d == '\r' || d == '\'' || d == ';') break;
                self.pos++;
            }
            String tok = self.src[start:self.pos - start];
            if (tok == "#t") return &true_value;
            if (tok == "#f") return &false_value;
            if (try n = tok.to_long()) return make_num(n);
            return make_sym(tok);
    }
}

fn Value*? Reader.read_list(&self)
{
    self.skip_space();
    if (self.pos >= self.src.len) return SYNTAX_ERROR~;
    if (self.src[self.pos] == ')')
    {
        self.pos++;
        return nil;
    }
    Value* head = self.read()!;
    return cons(head, self.read_list()!);
}

// ================================================================ printer

fn void print_value(DString* out, Value* v)
{
    switch (v.kind)
    {
        case NIL: out.append("()");
        case BOOL: out.append(v.num ? "#t" : "#f");
        case NUM: out.appendf("%d", v.num);
        case SYM: out.append(v.sym);
        case BUILTIN: out.appendf("#<builtin %s>", v.sym);
        case LAMBDA: out.append("#<lambda>");
        case PAIR:
            out.append('(');
            Value* it = v;
            while (true)
            {
                print_value(out, it.car);
                it = it.cdr;
                if (it.kind != PAIR) break;
                out.append(' ');
            }
            if (it.kind != NIL)
            {
                out.append(" . ");
                print_value(out, it);
            }
            out.append(')');
    }
}

fn String to_tstring(Value* v)
{
    DString s = dstring::temp();
    print_value(&s, v);
    return s.str_view();
}

// ================================================================ встроенные функции

fn long? num_arg(Value* v) => v.kind == NUM ? v.num : TYPE_ERROR~;

fn Value*? b_add(Value* args)
{
    long acc = 0;
    for (Value* a = args; a.kind == PAIR; a = a.cdr) acc += num_arg(a.car)!;
    return make_num(acc);
}

fn Value*? b_mul(Value* args)
{
    long acc = 1;
    for (Value* a = args; a.kind == PAIR; a = a.cdr) acc *= num_arg(a.car)!;
    return make_num(acc);
}

fn Value*? b_sub(Value* args)
{
    if (args.kind != PAIR) return ARITY_MISMATCH~;
    long acc = num_arg(args.car)!;
    if (args.cdr.kind != PAIR) return make_num(-acc);
    for (Value* a = args.cdr; a.kind == PAIR; a = a.cdr) acc -= num_arg(a.car)!;
    return make_num(acc);
}

fn Value*? b_div(Value* args)
{
    if (args.length() != 2) return ARITY_MISMATCH~;
    long a = num_arg(args.car)!;
    long b = num_arg(args.cdr.car)!;
    if (b == 0) return DIV_BY_ZERO~;
    return make_num(a / b);
}

fn Value*? compare(Value* args, int want)
{
    if (args.length() != 2) return ARITY_MISMATCH~;
    long a = num_arg(args.car)!;
    long b = num_arg(args.cdr.car)!;
    int c = a < b ? -1 : a > b ? 1 : 0;
    return make_bool(c == want);
}
fn Value*? b_lt(Value* args) => compare(args, -1);
fn Value*? b_gt(Value* args) => compare(args, 1);
fn Value*? b_eq(Value* args) => compare(args, 0);

fn Value*? b_cons(Value* args)
{
    if (args.length() != 2) return ARITY_MISMATCH~;
    return cons(args.car, args.cdr.car);
}
fn Value*? b_car(Value* args)
{
    if (args.length() != 1) return ARITY_MISMATCH~;
    if (args.car.kind != PAIR) return TYPE_ERROR~;
    return args.car.car;
}
fn Value*? b_cdr(Value* args)
{
    if (args.length() != 1) return ARITY_MISMATCH~;
    if (args.car.kind != PAIR) return TYPE_ERROR~;
    return args.car.cdr;
}
fn Value*? b_list(Value* args) => args;
fn Value*? b_nullp(Value* args)
{
    if (args.length() != 1) return ARITY_MISMATCH~;
    return make_bool(args.car.kind == NIL);
}
fn Value*? b_not(Value* args)
{
    if (args.length() != 1) return ARITY_MISMATCH~;
    return make_bool(!args.car.is_truthy());
}
fn Value*? b_eqp(Value* args)
{
    if (args.length() != 2) return ARITY_MISMATCH~;
    Value* a = args.car;
    Value* b = args.cdr.car;
    if (a.kind != b.kind) return make_bool(false);
    switch (a.kind)
    {
        case NUM:
        case BOOL: return make_bool(a.num == b.num);
        case SYM: return make_bool(a.sym == b.sym);
        case NIL: return make_bool(true);
        default: return make_bool(a == b);
    }
}

fn Env* global_env()
{
    Env* g = new_env(null);
    String[*] names = { "+", "-", "*", "/", "<", ">", "=", "cons", "car", "cdr", "list", "null?", "not", "eq?" };
    BuiltinFn[*] fns = { &b_add, &b_sub, &b_mul, &b_div, &b_lt, &b_gt, &b_eq, &b_cons, &b_car, &b_cdr, &b_list, &b_nullp, &b_not, &b_eqp };
    foreach (i, n : names) g.define(n, mem::tnew(Value, { .kind = BUILTIN, .sym = n, .builtin = fns[i] }));
    return g;
}

// ================================================================ eval

int depth;        // текущая глубина рекурсии eval
int max_depth;    // максимум за программу (для проверки TCO)

fn Value*? eval(Value* x, Env* env)
{
    depth++;
    if (depth > max_depth) max_depth = depth;
    defer depth--;
    // TODO: см. шапку. Скелет:
    //   while (true)
    //   {
    //       switch (x.kind) { ...самовычислимые...; case SYM: ...; case PAIR: break; }
    //       Value* head = x.car; Value* args = x.cdr;
    //       if (head.kind == SYM) { switch (head.sym) { case "quote": ... case "if": ... } }
    //       ...вызов функции...
    //   }
    //  Полезно: x.second()!, x.third()!, args.length(), Value.is_truthy().
    //  Ошибки неправильных форм (нет аргументов у if и т.п.) — BAD_FORM.
    while (true)
    {
        switch (x.kind)
        {
            case NIL:
            case BOOL:
            case NUM:
            case BUILTIN:
            case LAMBDA:
                return x;
            case SYM:
                return env.lookup(x.sym);
            case PAIR:
                break;
        }
        Value* head = x.car;
        Value* args = x.cdr;
        if (head.kind == SYM)
        {
            switch (head.sym)
            {
                case "quote":
                    if (args.length() != 1) return BAD_FORM~;
                    return args.car;
                case "if":
                    sz n = args.length();
                    if (n != 2 && n != 3) return BAD_FORM~;
                    Value* c = eval(args.car, env)!;
                    if (c.is_truthy())
                    {
                        x = x.third()!;
                    }
                    else
                    {
                        x = n == 3 ? args.cdr.cdr.car : nil;
                    }
                    continue;
                case "define":
                    if (args.length() < 2) return BAD_FORM~;
                    Value* target = args.car;
                    if (target.kind == PAIR)
                    {
                        // (define (f p...) body...)
                        if (target.car.kind != SYM) return BAD_FORM~;
                        env.define(target.car.sym, make_lambda(target.cdr, args.cdr, env));
                        return target.car;
                    }
                    if (target.kind != SYM || args.length() != 2) return BAD_FORM~;
                    env.define(target.sym, eval(args.cdr.car, env)!);
                    return target;
                case "lambda":
                    if (args.length() < 2) return BAD_FORM~;
                    return make_lambda(args.car, args.cdr, env);
                case "set!":
                    if (args.length() != 2 || args.car.kind != SYM) return BAD_FORM~;
                    Value* v = eval(args.cdr.car, env)!;
                    env.set(args.car.sym, v)!;
                    return v;
                case "begin":
                    if (args.kind == NIL) return nil;
                    for (; args.cdr.kind == PAIR; args = args.cdr) eval(args.car, env)!;
                    x = args.car;
                    continue;
                case "let":
                    if (args.length() < 2) return BAD_FORM~;
                    Env* frame = new_env(env);
                    for (Value* b = args.car; b.kind == PAIR; b = b.cdr)
                    {
                        Value* binding = b.car;
                        if (binding.length() != 2 || binding.car.kind != SYM) return BAD_FORM~;
                        frame.define(binding.car.sym, eval(binding.cdr.car, env)!);
                    }
                    env = frame;
                    Value* body = args.cdr;
                    for (; body.cdr.kind == PAIR; body = body.cdr) eval(body.car, env)!;
                    x = body.car;
                    continue;
                case "and":
                case "or":
                    bool is_and = head.sym == "and";
                    if (args.kind == NIL) return make_bool(is_and);
                    for (; args.cdr.kind == PAIR; args = args.cdr)
                    {
                        Value* v = eval(args.car, env)!;
                        if (v.is_truthy() != is_and) return v;
                    }
                    x = args.car;
                    continue;
                default:
                    break;
            }
        }
        // вызов функции
        Value* f = eval(head, env)!;
        Value* evaluated = nil;
        Value** tail = &evaluated;
        for (Value* a = args; a.kind == PAIR; a = a.cdr)
        {
            *tail = cons(eval(a.car, env)!, nil);
            tail = &(*tail).cdr;
        }
        switch (f.kind)
        {
            case BUILTIN:
                return f.builtin(evaluated);
            case LAMBDA:
                if (f.car.length() != evaluated.length()) return ARITY_MISMATCH~;
                Env* frame = new_env(f.env);
                Value* a = evaluated;
                for (Value* p = f.car; p.kind == PAIR; p = p.cdr)
                {
                    if (p.car.kind != SYM) return BAD_FORM~;
                    frame.define(p.car.sym, a.car);
                    a = a.cdr;
                }
                env = frame;
                Value* body = f.cdr;
                for (; body.cdr.kind == PAIR; body = body.cdr) eval(body.car, env)!;
                x = body.car;
                continue;
            default:
                return NOT_A_FUNCTION~;
        }
    }
}

// ================================================================ проверка

const String PROGRAM = `
; --- основы
(define x 10)
(+ x 5 (* 2 3))
(- 10)
(if (< x 20) 'small 'big)
(if #f 1)
'(1 (2 3) () #t)

; --- функции, рекурсия, замыкания
(define (square n) (* n n))
(square 12)
(define fact (lambda (n) (if (< n 2) 1 (* n (fact (- n 1))))))
(fact 15)
(define (fib n) (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))
(fib 20)
(define (make-adder k) (lambda (y) (+ y k)))
(define add5 (make-adder 5))
(add5 37)
(define k 1000)
(add5 1)

; --- списки и функции высшего порядка
(define (map f xs) (if (null? xs) '() (cons (f (car xs)) (map f (cdr xs)))))
(map square '(1 2 3 4))
(map (make-adder 10) (list 1 2 3))
(define (filter p xs) (if (null? xs) '() (if (p (car xs)) (cons (car xs) (filter p (cdr xs))) (filter p (cdr xs)))))
(filter (lambda (n) (= 0 (- n (* 2 (/ n 2))))) '(1 2 3 4 5 6))
(cons 1 2)

; --- let, begin, set!, состояние в замыкании
(let ((a 2) (b 3)) (* a b))
(let ((x 1) (y x)) (+ x y))
(define counter (let ((n 0)) (lambda () (set! n (+ n 1)) n)))
(counter)
(counter)
(begin (define z 3) (* z z))

; --- ленивые and/or, ложь только #f и ()
(and 1 #f (car '()))
(or #f '() 0)
(and)
(not '())

; --- хвостовые вызовы: 100000 итераций без роста глубины
(define (count-to n acc) (if (= n 0) acc (count-to (- n 1) (+ acc 1))))
(count-to 100000 0)

; --- ошибки
(undefined-thing 1)
(car 5)
((lambda (a b) a) 1)
(/ 1 0)
(5 6)
(set! nope 1)
(if)
`;

fn void main()
{
    @pool()
    {
        Env* g = global_env();
        Reader r = { PROGRAM, 0 };
        int errors = 0;
        int count_depth = 0;
        while (!r.at_end())
        {
            Value* expr = r.read()!!;
            depth = 0;
            max_depth = 0;
            Value*? result = eval(expr, g);
            if (catch err = result)
            {
                io::printfn("> %s\n! %s", to_tstring(expr), err);
                errors++;
                continue;
            }
            io::printfn("> %s\n= %s", to_tstring(expr), to_tstring(result));
            if (expr.kind == PAIR && expr.car.is_sym("count-to")) count_depth = max_depth;
        }
        assert(count_depth > 0 && count_depth < 50, "no tail call optimization: eval depth reached %d", count_depth);
        io::printfn("tail-call depth for 100000 iterations: %d", count_depth);

        // синтаксические ошибки reader'а
        Reader bad = { "(+ 1 2", 0 };
        assert(@catch(bad.read()) == SYNTAX_ERROR);
        Reader bad2 = { ")", 0 };
        assert(@catch(bad2.read()) == SYNTAX_ERROR);
        io::printfn("errors reported: %d", errors);
    };
}
