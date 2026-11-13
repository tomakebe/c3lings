// =====================================================================
//  E0301 · Плотный массив и swap-remove
// =====================================================================
//
//  Сначала прочитайте engine/docs/03_containers.md (разделы 1 и 3).
//
//  Плотный (packed) массив — без дыр: обход идёт подряд по памяти.
//  Удаление из середины за O(1) — перестановкой с последним:
//
//      до:     [A][B][C][D][E]      remove(B)
//      после:  [A][E][C][D]         E переехал на место B
//
//  Порядок теряется, зато массив остаётся плотным. Но у E изменился
//  индекс! Поэтому нужны ДВЕ таблицы:
//
//      owner_of[i]   — кто владеет элементом в позиции i (плотная сторона)
//      index_of[id]  — где сейчас элемент владельца id (или -1)
//
//  При перемещении обновляются обе. Инвариант, который проверяет main:
//      для всех i < len:  index_of[owner_of[i]] == i
//
//  Отдельная ловушка — удаление ВО ВРЕМЯ обхода. После swap-remove в
//  текущую позицию i переехал последний элемент, и его тоже надо
//  проверить: не увеличивайте i в этом случае.
//
//  ЗАДАЧА: реализуйте Packed.add, Packed.remove и Packed.remove_dead.
//
import std::io;

const int CAP = 64;

struct Particle
{
    float x;
    int life;
}

struct Packed
{
    Particle[CAP] items;
    int[CAP] owner_of;     // позиция -> владелец
    int[CAP] index_of;     // владелец -> позиция или -1
    int len;
}

fn void Packed.init(&self)
{
    self.len = 0;
    foreach (&i : self.index_of) *i = -1;
}

// Добавить элемент владельцу id (у владельца не больше одного элемента).
fn bool Packed.add(&self, int id, Particle p)
{
    // TODO: отказать, если места нет или у владельца уже есть элемент;
    //       дописать в конец и связать обе таблицы
    return false;
}

fn Particle* Packed.get(&self, int id)
{
    int i = self.index_of[id];
    return i < 0 ? null : &self.items[i];
}

fn bool Packed.remove(&self, int id)
{
    // TODO: swap-remove с обновлением owner_of/index_of
    return false;
}

// Удалить все элементы с life <= 0. Возвращает число удалённых.
fn int Packed.remove_dead(&self)
{
    // TODO: обойти массив и удалить все элементы с life <= 0.
    //       Осторожно: после swap-remove в позицию i переезжает другой элемент.
    return 0;
}

fn void Packed.check(&self)
{
    for (int i = 0; i < self.len; i++)
    {
        assert(self.index_of[self.owner_of[i]] == i, "index_of/owner_of out of sync at %d", i);
    }
    int live = 0;
    foreach (idx : self.index_of) if (idx >= 0) live++;
    assert(live == self.len, "index_of has %d live entries, len is %d", live, self.len);
}

fn void Packed.print(&self, String label)
{
    io::printf("%-14s", label);
    for (int i = 0; i < self.len; i++) io::printf(" %d", self.owner_of[i]);
    io::printn();
}

fn void main()
{
    Packed p;
    p.init();
    for (int id = 10; id < 16; id++) assert(p.add(id, { (float)id, id - 10 }));
    assert(!p.add(12, {}), "an owner may have only one element");
    p.check();
    p.print("added:");

    assert(p.remove(11));
    p.check();
    p.print("remove 11:");
    assert(p.owner_of[1] == 15, "the last element must move into the hole");
    assert(p.get(15).x == 15.0f, "lookup after the move");
    assert(p.get(11) == null && !p.remove(11));

    assert(p.remove(15));       // удаление элемента, который уже переезжал
    assert(p.remove(14));       // удаление последнего
    p.check();
    p.print("remove 15,14:");

    // Удаление во время обхода: у 10 life 0, а последний (30) тоже мёртв —
    // после удаления 10 он переедет в позицию 0, и его нельзя пропустить.
    for (int id = 20; id <= 30; id++) p.add(id, { (float)id, id % 3 });
    p.print("more:");
    int removed = p.remove_dead();
    p.check();
    p.print("remove_dead:");
    for (int i = 0; i < p.len; i++) assert(p.items[i].life > 0, "a dead particle survived at %d", i);
    io::printfn("removed %d, alive %d", removed, p.len);
    assert(removed == 5 && p.len == 9);
    io::printn("swap-remove OK");
}
