// ---------------------------------------------------------------------
//  mini::ecs — ECS на разреженных множествах (sparse sets), глава 05.
//
//  Каждый тип компонента хранится в своём SparseSet:
//
//      sparse[entity] -> позиция в dense      (entity = индекс хендла)
//      dense[i]       -> entity
//      data[i]        -> компонент            (плотно, без дыр)
//
//  Сущность e имеет компонент, если sparse[e] < len && dense[sparse[e]] == e.
//  Удаление — «swap-remove»: последний элемент переезжает на место
//  удалённого, поэтому данные всегда плотные и итерация — линейный проход.
// ---------------------------------------------------------------------
module mini::ecs;
import mini::core;

struct SparseSet <Type>
{
    uint[core::MAX_ENTITIES] sparse;
    uint[core::MAX_ENTITIES] dense;
    Type[core::MAX_ENTITIES] data;
    uint len;
}

fn bool SparseSet.has(&self, uint e)
{
    uint i = self.sparse[e];
    return i < self.len && self.dense[i] == e;
}

<* Добавить компонент или перезаписать существующий. *>
fn void SparseSet.set(&self, uint e, Type value)
{
    if (self.has(e))
    {
        self.data[self.sparse[e]] = value;
        return;
    }
    self.sparse[e] = self.len;
    self.dense[self.len] = e;
    self.data[self.len] = value;
    self.len++;
}

<* Указатель на компонент или null. *>
fn Type* SparseSet.get(&self, uint e)
{
    if (!self.has(e)) return null;
    return &self.data[self.sparse[e]];
}

<* Удалить компонент (если есть) перестановкой последнего на его место. *>
fn void SparseSet.remove(&self, uint e)
{
    if (!self.has(e)) return;
    uint i = self.sparse[e];
    uint last = self.len - 1;
    uint moved = self.dense[last];
    self.dense[i] = moved;
    self.data[i] = self.data[last];
    self.sparse[moved] = i;
    self.len--;
}

// ----------------------------------------------------------- компоненты
struct Transform { int x; int y; int angle; }     // x, y в FX; angle 0..31
struct Velocity { int vx; int vy; }               // FX за тик
struct Collider { int radius; uint layer; uint mask; }
struct Sprite { char glyph; int size; }           // size: радиус в клетках экрана
struct Lifetime { int ticks; }

enum Kind : char
{
    SHIP,
    BULLET,
    ASTEROID,
}

struct Tag { Kind kind; int size; }               // size астероида: 3, 2, 1

// ----------------------------------------------------------- мир
struct World
{
    HandlePool pool;
    Handle[core::MAX_ENTITIES] handle_of;   // index -> текущий хендл
    SparseSet{Transform} transforms;
    SparseSet{Velocity} velocities;
    SparseSet{Collider} colliders;
    SparseSet{Sprite} sprites;
    SparseSet{Lifetime} lifetimes;
    SparseSet{Tag} tags;
    uint[core::MAX_ENTITIES] doomed;        // отложенное удаление
    uint doomed_count;
}

fn Handle World.spawn(&self)
{
    Handle h = self.pool.alloc()!!;
    self.handle_of[h.index] = h;
    return h;
}

fn bool World.alive(&self, Handle h) => self.pool.valid(h);

fn bool World.is_doomed(&self, uint e)
{
    for (uint i = 0; i < self.doomed_count; i++) if (self.doomed[i] == e) return true;
    return false;
}

// Удалять сущности посреди итерации по SparseSet нельзя (swap-remove
// перемешает dense под ногами). Поэтому системы только помечают, а
// реальное удаление делает flush() в конце тика.
fn void World.destroy_later(&self, uint e)
{
    if (!self.pool.alive[e] || self.is_doomed(e)) return;
    self.doomed[self.doomed_count++] = e;
}

fn void World.flush(&self)
{
    for (uint i = 0; i < self.doomed_count; i++)
    {
        uint e = self.doomed[i];
        self.transforms.remove(e);
        self.velocities.remove(e);
        self.colliders.remove(e);
        self.sprites.remove(e);
        self.lifetimes.remove(e);
        self.tags.remove(e);
        self.pool.free(self.handle_of[e]);
    }
    self.doomed_count = 0;
}

// Контрольная сумма всего состояния, в порядке индексов сущностей
// (а не dense-массивов) — не зависит от истории перестановок.
fn uint World.checksum(&self)
{
    uint h = core::FNV_BASIS;
    for (uint e = 0; e < core::MAX_ENTITIES; e++)
    {
        if (!self.pool.alive[e]) continue;
        h = core::fnv_int(h, (int)e);
        if (Transform* t = self.transforms.get(e))
        {
            h = core::fnv_int(h, t.x);
            h = core::fnv_int(h, t.y);
            h = core::fnv_int(h, t.angle);
        }
        if (Velocity* v = self.velocities.get(e))
        {
            h = core::fnv_int(h, v.vx);
            h = core::fnv_int(h, v.vy);
        }
        if (Tag* g = self.tags.get(e))
        {
            h = core::fnv_int(h, (int)g.kind);
            h = core::fnv_int(h, g.size);
        }
    }
    return h;
}
