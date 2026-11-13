// =====================================================================
//  e1902 · Транзакции и слияние команд
// =====================================================================
//
//  Две проблемы простой истории команд (e1901):
//
//  1) Одно действие пользователя — много изменений. «Выровнять 30
//     объектов по сетке» — 60 команд SET, а Ctrl+Z должен отменить всё
//     действие разом. Решение — ТРАНЗАКЦИИ: begin("Align") ... commit().
//     Единица undo — транзакция, а не команда. Если действие прервалось
//     (ошибка, Esc посреди перетаскивания) — cancel() откатывает всё,
//     что успело примениться, и в историю ничего не попадает.
//
//         cmds:  [a][b][c][d][e][f]
//         txns:  {Move: a}{Align: b c d e}{Color: f}
//
//  2) Перетаскивание ползунка генерирует изменение КАЖДЫЙ кадр. 200
//     записей «x = 10.1, 10.2, ...» в истории — бесполезны. Решение —
//     СЛИЯНИЕ (coalescing): если новая транзакция имеет тот же ключ
//     слияния (merge_key, например «drag #17 поля x сущности 3»), что и
//     последняя, и состоит из одной команды над тем же полем, — просто
//     обновить new_value последней команды. old_value остаётся
//     исходным, и один Ctrl+Z вернёт значение до начала перетаскивания.
//     Сливать можно только с ВЕРХУШКОЙ истории (не после undo).
//
//  (Unreal: FScopedTransaction + Modify(); Godot: EditorUndoRedoManager
//  с create_action(name, MERGE_ENDS); Qt: QUndoCommand::mergeWith.)
//
//  ЗАДАЧА: реализуйте begin, commit, cancel, undo и логику слияния в commit.
//
import std::io;

const int MAX_CMDS = 64;
const int MAX_TXNS = 32;

struct Command
{
    int target;      // индекс значения в «документе»
    int old_value;
    int new_value;
}

struct Transaction
{
    String name;
    int first;       // индекс первой команды в cmds
    int count;
    int merge_key;   // 0 — не сливать
}

struct Editor
{
    int[8] doc;                    // редактируемые данные
    Command[MAX_CMDS] cmds;
    int cmd_len;
    Transaction[MAX_TXNS] txns;
    int txn_len;
    int cursor;                    // число применённых транзакций
    bool open;
    Transaction pending;
}

fn void Editor.begin(&self, String name, int merge_key = 0)
{
    assert(!self.open, "вложенные транзакции не поддерживаются");
    // TODO: отбросить ветку redo (и транзакции, и их команды), открыть pending
    self.open = true;
    self.pending = { .name = name, .first = self.cmd_len, .merge_key = merge_key };
}

// Изменить значение внутри открытой транзакции (готово).
fn void Editor.set(&self, int target, int value)
{
    assert(self.open, "set вне транзакции");
    self.cmds[self.cmd_len++] = { target, self.doc[target], value };
    self.pending.count++;
    self.doc[target] = value;
}

fn void Editor.commit(&self)
{
    assert(self.open);
    self.open = false;
    if (self.pending.count == 0) return;          // пустая транзакция — не нужна
    // TODO: слияние с верхушкой истории; иначе добавить транзакцию
    self.txns[self.txn_len++] = self.pending;
    self.cursor = self.txn_len;
}

// Откатить незавершённую транзакцию.
fn void Editor.cancel(&self)
{
    assert(self.open);
    // TODO: отменить команды pending в ОБРАТНОМ порядке
    self.open = false;
}

fn bool Editor.undo(&self)
{
    if (self.cursor == 0) return false;
    // TODO: отменить все команды транзакции в обратном порядке
    self.cursor--;
    return true;
}

fn bool Editor.redo(&self)
{
    if (self.cursor == self.txn_len) return false;
    Transaction* t = &self.txns[self.cursor++];
    for (int i = t.first; i < t.first + t.count; i++) self.doc[self.cmds[i].target] = self.cmds[i].new_value;
    return true;
}

// ---------------------------------------------------------------------
// Ниже ничего менять не нужно.

fn void Editor.print(&self)
{
    io::printf("doc:");
    foreach (v : self.doc) io::printf(" %d", v);
    io::printf(" | history:");
    for (int i = 0; i < self.txn_len; i++)
    {
        io::printf(" %s%s(%d)", i < self.cursor ? "" : "~", self.txns[i].name, self.txns[i].count);
    }
    io::printn();
}

fn void main()
{
    Editor ed;

    ed.begin("Move");
    ed.set(0, 5);
    ed.commit();

    // одно действие — много изменений, повторная запись в одно поле
    ed.begin("Align");
    for (int i = 1; i < 6; i++) ed.set(i, i * 10);
    ed.set(1, 11);
    ed.commit();
    ed.print();

    assert(ed.undo());
    assert(ed.doc[1] == 0 && ed.doc[5] == 0 && ed.doc[0] == 5, "undo транзакции целиком, в обратном порядке");
    assert(ed.redo() && ed.doc[1] == 11);

    // перетаскивание: 50 кадров, один merge_key
    for (int frame = 1; frame <= 50; frame++)
    {
        ed.begin("Drag x", 17);
        ed.set(7, frame * 2);
        ed.commit();
    }
    ed.print();
    assert(ed.txn_len == 3, "50 кадров перетаскивания — одна запись");
    assert(ed.undo() && ed.doc[7] == 0, "одна отмена возвращает значение до перетаскивания");
    assert(ed.redo() && ed.doc[7] == 100);

    // отменённое перетаскивание (Esc)
    ed.begin("Drag y", 18);
    ed.set(6, 1);
    ed.set(6, 2);
    ed.cancel();
    assert(ed.doc[6] == 0 && ed.cmd_len == 8, "cancel откатывает и ничего не оставляет");

    // undo, затем новое действие — ветка redo отброшена
    ed.undo();
    ed.begin("Paint");
    ed.set(6, 42);
    ed.commit();
    assert(ed.txn_len == 3 && !ed.redo());
    // слияние не должно склеивать с транзакцией с другим ключом
    ed.begin("Drag x", 17);
    ed.set(7, 1);
    ed.commit();
    assert(ed.txn_len == 4);
    ed.print();
    io::printfn("commands stored: %d", ed.cmd_len);
}
