// =====================================================================
//  E0503 · Запросы, системы и отложенные команды
// =====================================================================
//
//  Сначала прочитайте engine/docs/05_ecs.md (разделы 4–5).
//
//  Мир — менеджер сущностей + пулы компонентов из E0502 (уже готовы).
//  Теперь нужны:
//
//  1. ЗАПРОС (view) по двум компонентам — макрос с trailing-блоком:
//
//         @view2(&w.pos, &w.vel; Entity e, Position* p, Velocity* v)
//         {
//             *p += ...;
//         };
//
//     Он обходит МЕНЬШИЙ из двух пулов (плотно, по entities[]) и для
//     каждой сущности, у которой есть компонент и во втором пуле,
//     вызывает тело с указателями на оба компонента. Каждую проверенную
//     сущность считайте в глобальном view_visits — main проверит, что
//     обходился именно меньший пул.
//     (Внутри тела такого макроса нельзя писать `continue` — используйте if.)
//
//  2. COMMAND BUFFER. Системы НЕ уничтожают и не создают сущности во
//     время обхода (это swap-remove в пулах, которые сейчас обходятся!).
//     Вместо этого они пишут команды в w.commands, а World.flush()
//     применяет их после системы:
//       * SPAWN_SPARK — создать сущность с Position = cmd.pos и Lifetime 3;
//       * DESTROY     — уничтожить сущность: удалить её из ВСЕХ пулов и
//                       освободить id. Одна сущность может быть поставлена
//                       в очередь дважды (сгорела в лаве и истекла) —
//                       второй DESTROY для мёртвой сущности игнорируется.
//     Команды применяются в порядке записи, затем очередь очищается.
//
//  ЗАДАЧА: напишите тело макроса @view2, World.destroy_now и World.flush.
//
import std::io, std::collections::list;

// ---------------- сущности и пулы (готово) ----------------
typedef Entity = uint;
const uint INDEX_BITS = 22;
fn uint entity_index(Entity e) => (uint)e & ((1u << INDEX_BITS) - 1);
fn uint entity_gen(Entity e) => (uint)e >> INDEX_BITS;
fn Entity make_entity(uint index, uint gen) => (Entity)((gen << INDEX_BITS) | index);
const uint NONE = uint::max;

struct ComponentPool <Type>
{
    List{uint} sparse;
    List{Entity} entities;
    List{Type} data;
}
fn void ComponentPool.init(&self, Allocator a) { self.sparse.init(a); self.entities.init(a); self.data.init(a); }
fn void ComponentPool.free(&self) { self.sparse.free(); self.entities.free(); self.data.free(); }
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
    if (existing) { *existing = value; return existing; }
    uint i = entity_index(e);
    while (self.sparse.len() <= i) self.sparse.push(NONE);
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
// -----------------------------------------------------------

alias Vec2 = float[<2>];
struct Position { Vec2 p; }
struct Velocity { Vec2 v; }
struct Health { int hp; }
struct Lifetime { int ticks; }

enum CmdKind { DESTROY, SPAWN_SPARK }
struct Command { CmdKind kind; Entity e; Vec2 pos; }

struct World
{
    List{ushort} gens;
    List{uint} free_ids;
    usz live;
    ComponentPool{Position} pos;
    ComponentPool{Velocity} vel;
    ComponentPool{Health} health;
    ComponentPool{Lifetime} life;
    List{Command} commands;
}

fn void World.init(&self)
{
    self.gens.init(mem); self.free_ids.init(mem); self.commands.init(mem);
    self.pos.init(mem); self.vel.init(mem); self.health.init(mem); self.life.init(mem);
}

fn void World.free(&self)
{
    self.gens.free(); self.free_ids.free(); self.commands.free();
    self.pos.free(); self.vel.free(); self.health.free(); self.life.free();
}

fn Entity World.create(&self)
{
    uint i;
    if (self.free_ids.len() > 0)
    {
        i = self.free_ids.pop()!!;
    }
    else
    {
        i = (uint)self.gens.len();
        self.gens.push(1);
    }
    self.live++;
    return make_entity(i, self.gens[i]);
}

fn bool World.alive(&self, Entity e)
{
    uint i = entity_index(e);
    return i < self.gens.len() && self.gens[i] == entity_gen(e);
}

int view_visits;

macro @view2(a, b; @body(Entity e, x, y))
{
    // TODO: обойти меньший из пулов a и b; для каждой сущности e
    //       (view_visits++) найти компонент во втором пуле и, если он есть,
    //       вызвать @body(e, указатель_из_a, указатель_из_b).
    //       Указатель в «своём» пуле — a.data.get_ref(k), в другом — get(e).
}

fn void World.destroy_now(&self, Entity e)
{
    // TODO: мёртвую сущность игнорировать; удалить из всех четырёх пулов,
    //       увеличить поколение, индекс — в free_ids, live--
}

fn void World.flush(&self)
{
    // TODO: применить команды по порядку (switch по c.kind), очистить очередь
}

// ---------------- системы (готово) ----------------

fn void movement_system(World* w)
{
    @view2(&w.pos, &w.vel; Entity e, Position* p, Velocity* v)
    {
        p.p += v.v;
    };
}

fn void lava_system(World* w)
{
    @view2(&w.health, &w.pos; Entity e, Health* h, Position* p)
    {
        if (p.p.x > 50 && h.hp > 0)
        {
            h.hp -= 25;
            if (h.hp <= 0)
            {
                w.commands.push({ DESTROY, e, {} });
                w.commands.push({ SPAWN_SPARK, (Entity)0, p.p });
            }
        }
    };
}

fn void lifetime_system(World* w)
{
    foreach (k, &l : w.life.data.array_view())
    {
        l.ticks--;
        if (l.ticks <= 0) w.commands.push({ DESTROY, w.life.entities[k], {} });
    }
}

fn void main()
{
    World w;
    w.init();
    defer w.free();

    // 40 «ходоков» идут вправо с разной скоростью, у всех есть здоровье;
    // у части — ограниченное время жизни. 200 неподвижных декораций.
    for (int i = 0; i < 40; i++)
    {
        Entity e = w.create();
        w.pos.add(e, { { 0, (float)i } });
        w.vel.add(e, { { (float)(i % 5 + 1) * 2, 0 } });
        w.health.add(e, { 50 });
        if (i % 4 == 0) w.life.add(e, { 30 + i });
    }
    for (int i = 0; i < 200; i++) w.pos.add(w.create(), { { -10, (float)i } });

    view_visits = 0;
    movement_system(&w);
    io::printfn("movement visited %d (pos=%d vel=%d)", view_visits, w.pos.len(), w.vel.len());
    assert(view_visits == 40, "the view must iterate the smaller pool");

    for (int tick = 1; tick <= 40; tick++)
    {
        movement_system(&w);
        lava_system(&w);
        lifetime_system(&w);
        w.flush();
        assert(w.commands.len() == 0, "flush must clear the command buffer");
        if (tick % 8 == 0)
        {
            io::printfn("tick %2d: live=%3d pos=%3d vel=%2d health=%2d life=%2d",
                        tick, w.live, w.pos.len(), w.vel.len(), w.health.len(), w.life.len());
        }
        // Инвариант: ни в одном пуле нет мёртвых сущностей.
        foreach (e : w.pos.entities.array_view()) assert(w.alive(e), "dead entity left in a pool");
        foreach (e : w.life.entities.array_view()) assert(w.alive(e), "dead entity left in a pool");
    }
    // Все ходоки дошли до лавы и сгорели, их искры догорели.
    assert(w.vel.len() == 0 && w.health.len() == 0 && w.life.len() == 0);
    assert(w.live == 200 && w.pos.len() == 200);

    // Двойной DESTROY одной сущности в одном кадре.
    Entity x = w.create();
    w.pos.add(x, { { 1, 1 } });
    sz free_before = w.free_ids.len();
    w.commands.push({ DESTROY, x, {} });
    w.commands.push({ DESTROY, x, {} });
    w.flush();
    assert(!w.alive(x) && w.live == 200 && w.free_ids.len() == free_before + 1, "second DESTROY must be ignored");
    io::printfn("after double destroy: live=%d free_ids=%d", w.live, w.free_ids.len());
    io::printn("queries & systems OK");
}
