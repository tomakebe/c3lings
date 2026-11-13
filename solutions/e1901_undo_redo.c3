// =====================================================================
//  e1901 · Undo/redo: паттерн «команда»
// =====================================================================
//
//  Редактор без отмены — не редактор: художник не будет экспериментировать,
//  если любая ошибка стоит часа работы. Отмену проектируют с первого
//  дня, потому что «прикрутить потом» почти невозможно: каждое изменение
//  данных должно проходить через одну точку.
//
//  Паттерн «команда»: каждое изменение — объект, который знает, как себя
//  СДЕЛАТЬ и как ОТМЕНИТЬ. Команда хранит всё нужное для отмены (старое
//  значение!), а не вычисляет его при отмене.
//
//      history: [c0][c1][c2][c3]          cursor = 4 (сколько применено)
//      undo:    c3.undo(); cursor = 3     [c0][c1][c2]|[c3]
//      redo:    c3.do();   cursor = 4
//      новая команда при cursor < len:    хвост [c3] ОТБРАСЫВАЕТСЯ
//                                         (ветку redo больше не догнать)
//
//  Команды здесь — простые данные (struct + enum вида), а не объекты с
//  виртуальными методами: их легко хранить в массиве, сериализовать
//  (сохранить историю вместе со сценой), показать списком в UI
//  («Undo: Move Player»).
//
//  ЗАДАЧА: реализуйте apply_command, History.execute, undo и redo.
//
import std::io;

const int MAX_ENTITIES = 8;
const int MAX_HISTORY = 32;

struct Entity
{
    bool alive;
    int x;
    int y;
    int color;
}

struct Scene
{
    Entity[MAX_ENTITIES] e;
}

enum CmdKind
{
    SET_X,
    SET_Y,
    SET_COLOR,
    SPAWN,      // оживить сущность target (old/new не используются)
}

struct Command
{
    CmdKind kind;
    int target;
    int old_value;   // заполняется при execute — до изменения
    int new_value;
}

fn int* field_of(Scene* s, Command* c)
{
    switch (c.kind)
    {
        case SET_X: return &s.e[c.target].x;
        case SET_Y: return &s.e[c.target].y;
        case SET_COLOR: return &s.e[c.target].color;
        default: return null;
    }
}

// Применить (undo == false) или отменить (undo == true) команду.
fn void apply_command(Scene* s, Command* c, bool undo)
{
    if (c.kind == SPAWN)
    {
        s.e[c.target] = undo ? (Entity){} : (Entity){ .alive = true };
        return;
    }
    *field_of(s, c) = undo ? c.old_value : c.new_value;
}

struct History
{
    Command[MAX_HISTORY] cmds;
    int len;
    int cursor;
}

// Выполнить новую команду: запомнить старое значение, применить,
// отбросить ветку redo, добавить в историю.
fn void History.execute(&self, Scene* s, Command c)
{
    if (c.kind != SPAWN) c.old_value = *field_of(s, &c);
    apply_command(s, &c, false);
    self.len = self.cursor;          // ветка redo умирает
    assert(self.len < MAX_HISTORY);
    self.cmds[self.len++] = c;
    self.cursor = self.len;
}

fn bool History.undo(&self, Scene* s)
{
    if (self.cursor == 0) return false;
    apply_command(s, &self.cmds[--self.cursor], true);
    return true;
}

fn bool History.redo(&self, Scene* s)
{
    if (self.cursor == self.len) return false;
    apply_command(s, &self.cmds[self.cursor++], false);
    return true;
}

// ---------------------------------------------------------------------
// Ниже ничего менять не нужно.

fn uint scene_hash(Scene* s)
{
    uint h = 2166136261;
    foreach (e : s.e)
    {
        h = (h ^ (uint)e.alive) * 16777619;
        h = (h ^ (uint)e.x) * 16777619;
        h = (h ^ (uint)e.y) * 16777619;
        h = (h ^ (uint)e.color) * 16777619;
    }
    return h;
}

fn void main()
{
    Scene s;
    History h;
    uint empty = scene_hash(&s);

    h.execute(&s, { SPAWN, 0, 0, 0 });
    h.execute(&s, { SET_X, 0, 0, 10 });
    h.execute(&s, { SET_Y, 0, 0, 20 });
    h.execute(&s, { SET_X, 0, 0, 15 });
    h.execute(&s, { SPAWN, 1, 0, 0 });
    h.execute(&s, { SET_COLOR, 1, 0, 0xFF0000 });
    uint full = scene_hash(&s);
    assert(s.e[0].x == 15 && s.e[1].alive);

    assert(h.undo(&s) && h.undo(&s), "две отмены");
    assert(!s.e[1].alive && s.e[0].x == 15);
    assert(h.undo(&s));
    assert(s.e[0].x == 10, "отмена возвращает СТАРОЕ значение (10), а не 0");
    assert(h.redo(&s) && h.redo(&s) && h.redo(&s));
    assert(!h.redo(&s), "больше нечего повторять");
    assert(scene_hash(&s) == full, "undo + redo возвращает ровно то же состояние");

    while (h.undo(&s)) {}
    assert(scene_hash(&s) == empty, "отмена всего — пустая сцена");
    assert(!h.undo(&s));

    // новая ветка: после двух redo выполняем новую команду
    h.redo(&s);
    h.redo(&s);
    h.execute(&s, { SET_Y, 0, 0, -5 });
    assert(h.len == 3 && !h.redo(&s), "ветка redo должна быть отброшена");
    io::printfn("history len=%d cursor=%d entity0=(%d,%d)", h.len, h.cursor, s.e[0].x, s.e[0].y);
    io::printfn("scene hash %08x", scene_hash(&s));
}
