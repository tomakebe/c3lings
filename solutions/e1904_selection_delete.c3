// =====================================================================
//  e1904 · Выделение, удаление и отмена удаления
// =====================================================================
//
//  Самая коварная операция редактора — УДАЛЕНИЕ с возможностью отмены.
//  История хранит команды, ссылающиеся на сущности («сдвинуть #5»).
//  Если удалить #5, а при отмене создать сущность заново в ДРУГОМ
//  слоте (или с другим поколением), все старые команды в истории
//  станут указывать в пустоту или — хуже — на чужой объект.
//
//  Решение через хендлы (глава 03) с «надгробиями» (tombstones):
//
//      состояние слота:  FREE --create--> ALIVE --delete--> DELETED
//                          ^                ^                  |
//                          |                +---- undo --------+
//                          +---- purge (команда ушла из истории), gen++
//
//    * delete не освобождает слот: данные сохраняются В КОМАНДЕ, слот
//      помечается DELETED, поколение НЕ меняется;
//    * create берёт только FREE-слоты — надгробия не переиспользуются;
//    * undo возвращает данные в ТОТ ЖЕ слот с ТЕМ ЖЕ поколением —
//      все хендлы в истории снова действительны;
//    * когда команда удаления окончательно выпадает из истории
//      (лимит глубины, сохранение сцены), слот освобождается и его
//      поколение растёт.
//
//  Альтернатива — стабильные GUID у сущностей и таблица GUID -> хендл
//  (так делают редакторы с сохранением истории на диск).
//
//  Выделение (selection) — тоже набор хендлов, а не указателей. После
//  undo/redo выделение обычно восстанавливают тем, каким оно было до
//  действия: пользователь ожидает видеть выделенным то, что вернул.
//
//  ЗАДАЧА: реализуйте delete_selection и undo_delete.
//
import std::io;

const int SLOTS = 8;
const int MAX_SEL = 8;

struct Handle { ushort index; ushort gen; }

enum SlotState : char
{
    FREE,
    ALIVE,
    DELETED,
}

struct Entity { String name; int x; }

struct Slot
{
    Entity data;
    ushort gen;
    SlotState state;
}

struct World { Slot[SLOTS] slots; }

fn Handle World.create(&self, String name, int x)
{
    for (int i = 0; i < SLOTS; i++)
    {
        Slot* s = &self.slots[i];
        if (s.state != FREE) continue;
        s.state = ALIVE;
        s.data = { name, x };
        return { (ushort)i, s.gen };
    }
    unreachable("world is full");
}

fn bool World.alive(&self, Handle h) => self.slots[h.index].state == ALIVE && self.slots[h.index].gen == h.gen;

fn Entity* World.get(&self, Handle h)
{
    assert(self.alive(h), "мёртвый хендл");
    return &self.slots[h.index].data;
}

struct Selection
{
    Handle[MAX_SEL] items;
    int count;
}

fn void Selection.add(&self, Handle h) { self.items[self.count++] = h; }

struct DeleteCommand
{
    Handle[MAX_SEL] handles;
    Entity[MAX_SEL] saved;
    int count;
}

// Удалить все живые выделенные сущности, сохранив их в cmd.
// Выделение очищается.
fn void delete_selection(World* w, Selection* sel, DeleteCommand* cmd)
{
    cmd.count = 0;
    foreach (h : sel.items[:sel.count])
    {
        if (!w.alive(h)) continue;
        Slot* s = &w.slots[h.index];
        cmd.handles[cmd.count] = h;
        cmd.saved[cmd.count] = s.data;
        cmd.count++;
        s.state = DELETED;
        s.data = {};
    }
    sel.count = 0;
}

// Вернуть удалённые сущности в те же слоты и восстановить выделение.
fn void undo_delete(World* w, DeleteCommand* cmd, Selection* sel)
{
    sel.count = 0;
    for (int i = 0; i < cmd.count; i++)
    {
        Handle h = cmd.handles[i];
        Slot* s = &w.slots[h.index];
        assert(s.state == DELETED && s.gen == h.gen);
        s.state = ALIVE;
        s.data = cmd.saved[i];
        sel.add(h);
    }
}

// Команда удаления больше не может быть отменена: освободить надгробия.
fn void purge_delete(World* w, DeleteCommand* cmd)
{
    for (int i = 0; i < cmd.count; i++)
    {
        Slot* s = &w.slots[cmd.handles[i].index];
        if (s.state != DELETED) continue;
        s.state = FREE;
        s.gen++;
    }
    cmd.count = 0;
}

// ---------------------------------------------------------------------
// Ниже ничего менять не нужно.

struct MoveCommand { Handle target; int dx; }

fn void World.print(&self)
{
    io::printf("world:");
    foreach (i, s : self.slots)
    {
        switch (s.state)
        {
            case FREE: io::printf(" [%d:-]", i);
            case ALIVE: io::printf(" [%d:%s x=%d g%d]", i, s.data.name, s.data.x, s.gen);
            case DELETED: io::printf(" [%d:RIP g%d]", i, s.gen);
        }
    }
    io::printn();
}

fn void main()
{
    World w;
    Handle tree = w.create("tree", 1);
    Handle rock = w.create("rock", 2);
    Handle hero = w.create("hero", 3);
    Handle lamp = w.create("lamp", 4);

    // история: сдвиг камня (хранит хендл!)
    MoveCommand move_rock = { rock, 10 };
    w.get(move_rock.target).x += move_rock.dx;

    Selection sel;
    sel.add(rock);
    sel.add(lamp);
    DeleteCommand del;
    delete_selection(&w, &sel, &del);
    assert(del.count == 2 && sel.count == 0);
    assert(!w.alive(rock) && !w.alive(lamp) && w.alive(hero));
    w.print();

    // новые сущности НЕ занимают надгробия
    Handle bush = w.create("bush", 5);
    assert(bush.index == 4, "create не должен брать DELETED-слоты");

    undo_delete(&w, &del, &sel);
    assert(w.alive(rock) && w.alive(lamp), "undo вернул сущности");
    assert(sel.count == 2 && sel.items[0].index == rock.index, "выделение восстановлено");
    assert(w.get(rock).x == 12, "данные восстановлены");
    // старая команда в истории снова работает: отменим сдвиг
    w.get(move_rock.target).x -= move_rock.dx;
    assert(w.get(rock).x == 2);
    w.print();

    // удалить ещё раз, и команда уходит из истории навсегда
    delete_selection(&w, &sel, &del);
    purge_delete(&w, &del);
    assert(!w.alive(rock));
    Handle coin = w.create("coin", 6);
    assert(coin.index == rock.index && coin.gen == rock.gen + 1, "освобождённый слот — с новым поколением");
    assert(!w.alive(move_rock.target), "старый хендл не должен попасть в монету");
    w.print();
    (void)tree;
}
