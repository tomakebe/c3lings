// =====================================================================
//  e1405 · Горячая перезагрузка скрипта с сохранением состояния
// =====================================================================
//
//  Сначала прочитайте engine/docs/14_scripting.md (раздел «Горячая
//  перезагрузка»).
//
//  Главная причина, по которой студии вообще держат скриптовый слой, —
//  скорость итерации. Дизайнер правит файл, жмёт Ctrl+S и через долю
//  секунды видит результат в ЗАПУЩЕННОЙ игре — без перезапуска уровня и
//  без потери состояния (счёт, позиция босса, таймеры).
//
//  Сложность в том, что состояние принадлежит СТАРОЙ версии кода:
//
//      v1.globals = [ score, ticks ]          values = [ 3, 3 ]
//      v2.globals = [ combo, score, ticks ]   values = [ ?, ?, ? ]
//
//  Байткод обращается к глобальным по ИНДЕКСУ (это быстро), но индексы
//  между версиями не стабильны. Стабильны ИМЕНА. Поэтому при reload:
//
//    * есть в обеих версиях -> переносим значение (по имени!);
//    * только в новой       -> инициализатор новой версии;
//    * только в старой      -> выбрасываем.
//
//  Второе правило: никогда не подменяйте работающий код непроверенным.
//  Файл могли сохранить на полуслове. Сначала validate() (индексы
//  глобальных и адреса переходов в пределах), и только если всё хорошо —
//  атомарная подмена. При ошибке игра продолжает на старом коде, а
//  редактор показывает сообщение.
//
//  (В Lua то же самое делают, перезагружая chunk и переписывая функции
//  в существующих таблицах; данные живут в таблицах и переживают reload.)
//
//  ЗАДАЧА:
//    * Program.validate — LOAD/STORE: индекс в [0, globals.len), иначе
//      BAD_GLOBAL; JMP: адрес в [0, code.len), иначе BAD_JUMP;
//    * Instance.reload — перенос состояния по именам, заполнение
//      ReloadReport, подмена программы (только после успешной проверки).
//
module script_hot_reload;
import std::io;

excuse STACK_OVERFLOW, STACK_UNDERFLOW, BAD_GLOBAL, BAD_JUMP, TOO_MANY_GLOBALS;

enum Op : char { PUSH, LOAD, STORE, ADD, JMP, END }
struct Instr { Op op; int arg; }

// «Скомпилированный модуль» скрипта. Глобальные переменные в байткоде —
// это индексы, а их ИМЕНА остаются в таблице globals: именно по именам
// мы будем переносить состояние при перезагрузке.
struct Program
{
    int version;
    String[] globals;
    int[] inits;
    Instr[] code;
}

const int MAX_GLOBALS = 8;

struct Instance
{
    Program* prog;
    int[MAX_GLOBALS] values;
}

struct ReloadReport
{
    int kept;
    int added;
    int removed;
}

fn int? Program.find(&self, String name)
{
    foreach (i, g : self.globals)
    {
        if (g == name) return (int)i;
    }
    return BAD_GLOBAL~;
}

// Проверяем байткод ДО того, как пустить его в игру: индексы глобальных
// переменных и адреса переходов должны быть в пределах.
fn void? Program.validate(&self)
{
    if (self.globals.len > MAX_GLOBALS) return TOO_MANY_GLOBALS~;
    // TODO: проверить аргументы LOAD/STORE и JMP
}

fn void? Instance.load(&self, Program* p)
{
    p.validate()!;
    self.prog = p;
    foreach (i, v : p.inits) self.values[i] = v;
}

// Горячая перезагрузка: новый код, СТАРОЕ состояние.
//   * переменная есть в обеих версиях -> значение переносится
//     (даже если её индекс поменялся!);
//   * только в новой                  -> инициализатор новой версии;
//   * только в старой                 -> выбрасывается.
// Если новая версия не проходит validate(), ничего не меняется:
// игра продолжает работать на старом коде.
fn ReloadReport? Instance.reload(&self, Program* next)
{
    // TODO: проверить next; собрать новый массив значений по именам
    //       (self.prog.find(name) подскажет старый индекс); посчитать
    //       kept/added/removed; подменить values и prog.
    ReloadReport rep;
    self.prog = next;
    return rep;
}

fn void? Instance.tick(&self)
{
    int[8] stack;
    int sp;
    int pc;
    while (true)
    {
        Instr ins = self.prog.code[pc++];
        switch (ins.op)
        {
            case PUSH:
                if (sp >= 8) return STACK_OVERFLOW~;
                stack[sp++] = ins.arg;
            case LOAD:
                if (sp >= 8) return STACK_OVERFLOW~;
                stack[sp++] = self.values[ins.arg];
            case STORE:
                if (sp < 1) return STACK_UNDERFLOW~;
                self.values[ins.arg] = stack[--sp];
            case ADD:
                if (sp < 2) return STACK_UNDERFLOW~;
                sp--;
                stack[sp - 1] += stack[sp];
            case JMP: pc = ins.arg;
            case END: return;
        }
    }
}

fn int Instance.get(&self, String name) => self.values[self.prog.find(name)!!];

fn void Instance.print(&self)
{
    io::printf("  v%d:", self.prog.version);
    foreach (i, g : self.prog.globals) io::printf(" %s=%d", g, self.values[i]);
    io::printn();
}

fn void print_report(ReloadReport r)
{
    io::printfn("  reload: kept %d, added %d, removed %d", r.kept, r.added, r.removed);
}

fn void main()
{
    // v1: ticks += 1; score += 1
    Program v1 = {
        .version = 1,
        .globals = { "score", "ticks" },
        .inits = { 0, 0 },
        .code = {
            { LOAD, 1 }, { PUSH, 1 }, { ADD, 0 }, { STORE, 1 },
            { LOAD, 0 }, { PUSH, 1 }, { ADD, 0 }, { STORE, 0 },
            { END, 0 },
        },
    };
    // v2: дизайнер добавил комбо (и переставил переменные!):
    //     ticks += 1; score += combo
    Program v2 = {
        .version = 2,
        .globals = { "combo", "score", "ticks" },
        .inits = { 5, 0, 0 },
        .code = {
            { LOAD, 2 }, { PUSH, 1 }, { ADD, 0 }, { STORE, 2 },
            { LOAD, 1 }, { LOAD, 0 }, { ADD, 0 }, { STORE, 1 },
            { END, 0 },
        },
    };
    // v3: сохранили файл на полуслове — ссылка на несуществующую переменную
    Program v3 = {
        .version = 3,
        .globals = { "score" },
        .inits = { 0 },
        .code = { { LOAD, 7 }, { END, 0 } },
    };
    // v4: от счёта отказались, остались только тики
    Program v4 = {
        .version = 4,
        .globals = { "ticks" },
        .inits = { 100 },
        .code = { { LOAD, 0 }, { PUSH, 1 }, { ADD, 0 }, { STORE, 0 }, { END, 0 } },
    };

    Instance inst;
    inst.load(&v1)!!;
    for (int i = 0; i < 3; i++) inst.tick()!!;
    io::printn("after 3 ticks:");
    inst.print();
    assert(inst.get("score") == 3 && inst.get("ticks") == 3);

    ReloadReport r = inst.reload(&v2)!!;
    print_report(r);
    assert(r.kept == 2 && r.added == 1 && r.removed == 0);
    assert(inst.get("score") == 3, "score must survive the reload");
    assert(inst.get("ticks") == 3);
    assert(inst.get("combo") == 5, "new variable gets its initializer");
    for (int i = 0; i < 2; i++) inst.tick()!!;
    io::printn("after 2 more ticks:");
    inst.print();
    assert(inst.get("score") == 13 && inst.get("ticks") == 5);

    ReloadReport? bad = inst.reload(&v3);
    if (catch err = bad) io::printfn("  reload v3 rejected: %s", err);
    assert(@catch(bad) == BAD_GLOBAL);
    assert(inst.prog.version == 2, "a broken reload must keep the old program");
    inst.tick()!!;
    io::printn("after 1 more tick:");
    inst.print();
    assert(inst.get("score") == 18 && inst.get("ticks") == 6);

    r = inst.reload(&v4)!!;
    print_report(r);
    assert(r.kept == 1 && r.added == 0 && r.removed == 2);
    inst.tick()!!;
    io::printn("after 1 more tick:");
    inst.print();
    assert(inst.get("ticks") == 7, "ticks must continue from 6, not from the initializer 100");

    // и прыжки валидируются тоже
    Program v5 = { .version = 5, .globals = { "ticks" }, .inits = { 0 }, .code = { { JMP, 9 } } };
    assert(@catch(inst.reload(&v5)) == BAD_JUMP);
    assert(inst.prog.version == 4);

    io::printn("hot reload ok");
}
