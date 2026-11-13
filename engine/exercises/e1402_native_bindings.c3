// =====================================================================
//  e1402 · Нативные привязки: таблица функций, линковка, арность
// =====================================================================
//
//  Сначала прочитайте engine/docs/14_scripting.md (раздел «Привязки»).
//
//  Скрипт сам по себе ничего не умеет: всё полезное (нанести урон,
//  проиграть звук, заспавнить врага) делает движок. Мост между ними —
//  таблица нативных функций. У всех нативов ОДНА сигнатура:
//
//      alias NativeFn = fn int?(int[] args, void* ctx);
//
//  * args — окно стека VM (срез `stack[base:arity]`): аргументы не
//    копируются, натив читает их прямо со стека, как в Lua C API;
//  * ctx  — непрозрачный указатель на хост (игра, мир);
//  * int? — натив может «бросить» ошибку, и она остановит скрипт.
//
//  Писать трамплин `args -> параметры` руками для каждой функции скучно
//  и опасно. В C++ это делают шаблоны (sol2, LuaBridge), в C3 — макрос
//  с рефлексией. Число параметров функции известно компилятору:
//
//      $Typeof($f)::params.len          // $f = &add  ->  2
//
//  а срез можно «распаковать» в аргументы вызова оператором `...`:
//
//      $f(...a[:2])                     // то же, что $f(a[0], a[1])
//
//  Длина распаковываемого среза обязана быть константой времени
//  компиляции и не может быть нулевой — функции без параметров
//  обрабатываются отдельной веткой `$if`. Лямбда внутри макроса может
//  ссылаться на compile-time параметр `$f` (это не захват переменной —
//  `$f` подставляется как константа).
//
//  Линковка. Скрипт ссылается на натив ПО ИМЕНИ (так его пишет человек),
//  но искать строку на каждом вызове дорого. Поэтому при загрузке
//  `link()` один раз заменяет имена индексами и сразу проверяет арность —
//  опечатка в имени функции всплывёт при загрузке уровня, а не через
//  20 минут игры. VM при этом всё равно проверяет арность и наличие
//  аргументов: байткод мог прийти из файла в обход link().
//
//  ЗАДАЧА:
//    * NativeTable.find — линейный поиск по имени, иначе UNKNOWN_NATIVE;
//    * макрос @bind — регистрация обычной функции с арностью из рефлексии;
//    * link() — подставить индекс натива и проверить арность (ARITY_MISMATCH);
//    * опкод CALL в Vm.run — проверки, вызов с окном стека, результат на стек.
//
module native_bindings;
import std::io;

excuse STACK_OVERFLOW, STACK_UNDERFLOW, UNKNOWN_NATIVE, ARITY_MISMATCH, TABLE_FULL, DIV_BY_ZERO;

// ---------------------------------------------------------------- natives

// Единая сигнатура «нативной» функции, видимой из скрипта:
//   args — окно стека VM с аргументами (args[0] — первый аргумент),
//   ctx  — указатель на хост-объект (мир, игра), который VM не понимает.
alias NativeFn = fn int?(int[] args, void* ctx);

struct Native
{
    String name;
    int arity;
    NativeFn func;
}

const int MAX_NATIVES = 16;

struct NativeTable
{
    Native[MAX_NATIVES] items;
    int count;
}

fn int? NativeTable.add(&self, String name, int arity, NativeFn func)
{
    if (self.count >= MAX_NATIVES) return TABLE_FULL~;
    self.items[self.count] = { name, arity, func };
    return self.count++;
}

fn int? NativeTable.find(&self, String name)
{
    // TODO: найти натив по имени и вернуть его индекс
    return UNKNOWN_NATIVE~;
}

// Регистрирует ОБЫЧНУЮ функцию C3 вида `fn int f(int, int, ...)`:
// арность берётся из рефлексии, а прослойка-трамплин (args -> параметры)
// генерируется компилятором.
macro int? @bind(NativeTable* table, String name, $f)
{
    // TODO: настоящая арность и настоящий трамплин вместо null
    return table.add(name, 0, null);
}

// ---------------------------------------------------------------- VM

enum Op : char
{
    PUSH,   // arg -> push(arg)
    POP,
    CALL,   // arg = индекс нативной функции, arg2 = сколько аргументов передаёт скрипт
    HALT,
}

struct Instr
{
    Op op;
    int arg;
    int arg2;
}

// Так байткод выглядит ДО линковки: вызовы ссылаются на натив по имени.
struct SrcInstr
{
    Op op;
    int arg;
    int arg2;
    String name;
}

const int STACK_MAX = 16;

struct Vm
{
    int[STACK_MAX] stack;
    int sp;
    NativeTable* natives;
    void* ctx;
}

fn void? Vm.push(&self, int v)
{
    if (self.sp >= STACK_MAX) return STACK_OVERFLOW~;
    self.stack[self.sp++] = v;
}

fn int? Vm.pop(&self)
{
    if (self.sp <= 0) return STACK_UNDERFLOW~;
    return self.stack[--self.sp];
}

// Линковка: имена -> индексы, один раз при загрузке скрипта, а не на
// каждом вызове. Здесь же ловим неизвестные функции и неверную арность,
// пока скрипт ещё не начал работать.
fn void? link(NativeTable* natives, SrcInstr[] src, Instr[] out)
{
    foreach (i, s : src)
    {
        out[i] = { s.op, s.arg, s.arg2 };
        // TODO: для CALL — найти натив по s.name, проверить арность
        //       (s.arg2 — сколько аргументов передаёт скрипт),
        //       записать индекс в out[i].arg
    }
}

fn int? Vm.run(&self, Instr[] code)
{
    self.sp = 0;
    for (int pc = 0; pc < code.len; pc++)
    {
        Instr ins = code[pc];
        switch (ins.op)
        {
            case PUSH: self.push(ins.arg)!;
            case POP: self.pop()!;
            case CALL:
                // TODO: Native* n = &self.natives.items[ins.arg];
                //   1) арность натива должна совпасть с ins.arg2 (ARITY_MISMATCH)
                //   2) на стеке должно быть не меньше arity значений (STACK_UNDERFLOW)
                //   3) вызвать n.func с окном стека и self.ctx, пробросив ошибку
                //   4) снять аргументы и положить результат
                break;
            case HALT:
                return self.pop()!;
        }
    }
    return self.pop()!;
}

// ---------------------------------------------------------------- host

fn int add(int a, int b) => a + b;
fn int mul(int a, int b) => a * b;
fn int clamp(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);
fn int answer() => 42;

struct Game
{
    int gold;
    int calls;
}

// «Ручная» привязка: ей нужен контекст и она может вернуть ошибку.
fn int? give_gold(int[] args, void* ctx)
{
    Game* g = ctx;
    g.gold += args[0];
    g.calls++;
    return g.gold;
}

fn int? safe_div(int[] args, void* ctx)
{
    if (args[1] == 0) return DIV_BY_ZERO~;
    return args[0] / args[1];
}

fn int? run_src(Vm* vm, SrcInstr[] src)
{
    Instr[32] code;
    link(vm.natives, src, code[:src.len])!;
    return vm.run(code[:src.len]);
}

fn void main()
{
    NativeTable natives;
    @bind(&natives, "add", &add)!!;
    @bind(&natives, "mul", &mul)!!;
    @bind(&natives, "clamp", &clamp)!!;
    @bind(&natives, "answer", &answer)!!;
    natives.add("give_gold", 1, &give_gold)!!;
    natives.add("div", 2, &safe_div)!!;

    assert(natives.count == 6);
    assert(natives.items[0].arity == 2);
    assert(natives.items[2].arity == 3);
    assert(natives.items[3].arity == 0);
    assert(natives.find("clamp")!! == 2);
    assert(@catch(natives.find("fly")) == UNKNOWN_NATIVE);
    for (int i = 0; i < natives.count; i++)
    {
        io::printfn("native %d: %s/%d", i, natives.items[i].name, natives.items[i].arity);
    }

    Game game = { .gold = 10 };
    Vm vm = { .natives = &natives, .ctx = &game };

    // give_gold(clamp(mul(add(2, 3), 4), 0, 15)) -> 10 + 15 = 25
    SrcInstr[] prog = {
        { PUSH, 2, 0, "" }, { PUSH, 3, 0, "" },
        { CALL, 0, 2, "add" },
        { PUSH, 4, 0, "" },
        { CALL, 0, 2, "mul" },
        { PUSH, 0, 0, "" }, { PUSH, 15, 0, "" },
        { CALL, 0, 3, "clamp" },
        { CALL, 0, 1, "give_gold" },
        { HALT, 0, 0, "" },
    };
    int r = run_src(&vm, prog)!!;
    assert(r == 25 && game.gold == 25 && game.calls == 1, "got %d", r);
    io::printfn("prog = %d, gold = %d", r, game.gold);

    SrcInstr[] p2 = { { CALL, 0, 0, "answer" }, { PUSH, 6, 0, "" }, { CALL, 0, 2, "div" } };
    r = run_src(&vm, p2)!!;
    assert(r == 7);
    io::printfn("answer / 6 = %d", r);

    // ошибки линковки ловятся ДО запуска
    SrcInstr[] typo = { { PUSH, 1, 0, "" }, { CALL, 0, 1, "give_gld" } };
    int? e1 = run_src(&vm, typo);
    if (catch err = e1) io::printfn("typo: %s", err);
    assert(@catch(e1) == UNKNOWN_NATIVE);

    SrcInstr[] arity = { { PUSH, 1, 0, "" }, { CALL, 0, 1, "add" } };
    int? e2 = run_src(&vm, arity);
    if (catch err = e2) io::printfn("arity: %s", err);
    assert(@catch(e2) == ARITY_MISMATCH);

    // ошибка ВНУТРИ нативной функции пробрасывается в скрипт и останавливает его
    SrcInstr[] dz = { { PUSH, 1, 0, "" }, { PUSH, 0, 0, "" }, { CALL, 0, 2, "div" }, { CALL, 0, 1, "give_gold" } };
    int? e3 = run_src(&vm, dz);
    if (catch err = e3) io::printfn("div: %s", err);
    assert(@catch(e3) == DIV_BY_ZERO);
    assert(game.gold == 25 && game.calls == 1, "give_gold must not run after a failed call");

    // испорченный байткод (без линковки): аргументов на стеке меньше, чем нужно
    Instr[] raw = { { CALL, 0, 2 } };
    int? e4 = vm.run(raw);
    if (catch err = e4) io::printfn("raw: %s", err);
    assert(@catch(e4) == STACK_UNDERFLOW);

    io::printn("bindings ok");
}
