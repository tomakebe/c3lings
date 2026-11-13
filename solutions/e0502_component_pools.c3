// =====================================================================
//  E0502 · Хранилище компонентов на sparse set
// =====================================================================
//
//  Сначала прочитайте engine/docs/05_ecs.md (раздел 3.1).
//
//  ECS в стиле EnTT: у каждого типа компонента — свой пул.
//
//      sparse[index(e)]  -> позиция в плотных массивах или NONE
//      entities[pos]     -> полный Entity (с поколением!)
//      data[pos]         -> сам компонент
//
//  entities и data — параллельные плотные массивы одинаковой длины:
//  при swap-remove переставляются ОБА, и sparse переехавшей сущности
//  исправляется.
//
//  Тонкость: sparse индексируется ИНДЕКСОМ сущности, а индексы
//  переиспользуются. Если сущность 5v1 умерла, не удалив компонент, а
//  потом появилась 5v2, то sparse[5] указывает на компонент 5v1.
//  Поэтому has/get сверяют entities[pos] == e целиком — устаревший
//  компонент не будет выдан новой сущности.
//
//  sparse растёт по требованию: при add для индекса >= sparse.len()
//  дописываем NONE до нужной длины.
//
//  ЗАДАЧА: реализуйте ComponentPool.has, get, add (если компонент уже
//  есть — перезаписать значение и вернуть указатель на него) и remove.
//
import std::io, std::collections::list;

typedef Entity = uint;
const uint INDEX_BITS = 22;
fn uint entity_index(Entity e) => (uint)e & ((1u << INDEX_BITS) - 1);
fn Entity make_entity(uint index, uint gen) => (Entity)((gen << INDEX_BITS) | index);

const uint NONE = uint::max;

struct ComponentPool <Type>
{
    List{uint} sparse;
    List{Entity} entities;
    List{Type} data;
}

fn void ComponentPool.init(&self, Allocator a)
{
    self.sparse.init(a);
    self.entities.init(a);
    self.data.init(a);
}

fn void ComponentPool.free(&self)
{
    self.sparse.free();
    self.entities.free();
    self.data.free();
}

fn sz ComponentPool.len(&self) => self.entities.len();

fn bool ComponentPool.has(&self, Entity e)
{
    uint i = entity_index(e);
    if (i >= self.sparse.len()) return false;
    uint pos = self.sparse[i];
    return pos != NONE && self.entities[pos] == e;
}

fn Type* ComponentPool.get(&self, Entity e)
{
    if (!self.has(e)) return null;
    return self.data.get_ref(self.sparse[entity_index(e)]);
}

fn Type* ComponentPool.add(&self, Entity e, Type value)
{
    Type* existing = self.get(e);
    if (existing)
    {
        *existing = value;
        return existing;
    }
    uint i = entity_index(e);
    while (self.sparse.len() <= i) self.sparse.push(NONE);
    uint pos = self.sparse[i];
    if (pos != NONE)
    {
        // Устаревший компонент умершей сущности с тем же индексом:
        // просто занимаем его место.
        self.entities[pos] = e;
        self.data[pos] = value;
        return self.data.get_ref(pos);
    }
    self.sparse[i] = (uint)self.entities.len();
    self.entities.push(e);
    self.data.push(value);
    return self.data.get_ref(self.data.len() - 1);
}

fn bool ComponentPool.remove(&self, Entity e)
{
    if (!self.has(e)) return false;
    uint i = entity_index(e);
    uint pos = self.sparse[i];
    sz last = self.entities.len() - 1;
    if (pos != last)
    {
        Entity moved = self.entities[last];
        self.entities[pos] = moved;
        self.data[pos] = self.data[last];
        self.sparse[entity_index(moved)] = pos;
    }
    self.sparse[i] = NONE;
    (void)self.entities.pop();
    (void)self.data.pop();
    return true;
}

// ---------------------------------------------------------------------

struct Position { float x, y; }
struct Health { int hp; int max_hp; }

fn void main()
{
    ComponentPool{Position} pos;
    ComponentPool{Health} health;
    pos.init(mem);
    health.init(mem);
    defer { pos.free(); health.free(); }

    Entity[10] es;
    for (uint i = 0; i < 10; i++) es[i] = make_entity(i, 1);

    for (int i = 0; i < 10; i++) pos.add(es[i], { (float)i, (float)i * 2 });
    for (int i = 0; i < 10; i += 2) health.add(es[i], { 100 - i, 100 });
    assert(pos.len() == 10 && health.len() == 5);
    assert(pos.has(es[3]) && !health.has(es[3]) && health.has(es[4]));
    assert(health.get(es[3]) == null && health.get(es[4]).hp == 96);

    // add существующего — перезапись, без дубликата.
    Health* h = health.add(es[4], { 7, 100 });
    assert(h.hp == 7 && health.len() == 5 && health.get(es[4]).hp == 7);

    // Сущность за пределами sparse: пул растёт.
    Entity far = make_entity(1000, 1);
    pos.add(far, { -1, -1 });
    assert(pos.has(far) && pos.get(far).x == -1.0f && !pos.has(make_entity(999, 1)));

    // swap-remove: данные и сущности переставляются вместе.
    assert(pos.remove(es[0]));
    assert(!pos.has(es[0]) && !pos.remove(es[0]));
    assert(pos.get(far).y == -1.0f, "moved component must stay reachable");
    for (sz k = 0; k < pos.len(); k++)
    {
        Entity e = pos.entities[k];
        assert(pos.get(e) == pos.data.get_ref(k), "entities[] and data[] out of sync");
    }

    // Устаревший компонент: es[6] умерла, не удалив Health; индекс 6 переиспользован.
    Entity reborn = make_entity(6, 2);
    assert(!health.has(reborn) && health.get(reborn) == null, "a stale component must not leak to a new entity");
    health.add(reborn, { 1, 1 });
    assert(health.get(reborn).hp == 1 && !health.has(es[6]) && health.len() == 5);

    // «Система»: лечим всех, у кого есть Health, плотным обходом.
    foreach (&hh : health.data.array_view()) hh.hp = hh.max_hp;
    int total_hp = 0;
    foreach (hh : health.data.array_view()) total_hp += hh.hp;
    float sum_x = 0;
    foreach (p : pos.data.array_view()) sum_x += p.x;
    io::printfn("pos: %d components, sum_x=%.1f; health: %d components, total_hp=%d", pos.len(), sum_x, health.len(), total_hp);
    io::printf("pos entities:");
    foreach (e : pos.entities.array_view()) io::printf(" %d", entity_index(e));
    io::printn();
    io::printn("component pools OK");
}
