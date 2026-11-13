// =====================================================================
//  E0504 · Архетипная ECS
// =====================================================================
//
//  Сначала прочитайте engine/docs/05_ecs.md (раздел 3.2).
//
//  Архетип — уникальный НАБОР компонентов (битовая маска). Все
//  сущности с одинаковым набором живут в одной таблице, где каждый
//  компонент — отдельный столбец (SoA), а строка — сущность:
//
//      Archetype mask=0b011 {Position, Velocity}
//        entities: [ e1 ][ e3 ][ e8 ]
//        col[POS]:  [ p1 ][ p3 ][ p8 ]      (сырые байты, size = Position::size)
//        col[VEL]:  [ v1 ][ v3 ][ v8 ]
//
//      records[entity] = { архетип, строка }
//
//  Столбцы type-erased: это char* + размер элемента из таблицы
//  COMPONENT_SIZE. Копирование — mem::copy(dst, src, (sz)size).
//
//  Добавить/удалить компонент = ПЕРЕМЕСТИТЬ сущность в другой архетип:
//    1. найти (или создать) архетип с новой маской;
//    2. добавить в него строку (push_row) и скопировать туда все
//       компоненты, которые есть в ОБОИХ архетипах;
//    3. удалить строку из старого архетипа swap-remove'ом (remove_row);
//       если на место удалённой встала другая сущность — поправить её
//       record.row;
//    4. записать новый record.
//
//  Запрос @query(world, mask; Archetype* a) обходит все архетипы, маска
//  которых СОДЕРЖИТ маску запроса, — и внутри их столбцы линейно, без
//  всяких has()/get().
//
//  ЗАДАЧА: реализуйте Archetype.remove_row, World.move_entity и
//  World.get_raw. Остальное готово.
//
import std::io, std::collections::list;

const int POS = 0;
const int VEL = 1;
const int HEALTH = 2;
const int FROZEN = 3;      // «тег» — тоже компонент (здесь 1 байт)
const int NUM_COMPONENTS = 4;

alias Vec2 = float[<2>];
struct Position { Vec2 p; }
struct Velocity { Vec2 v; }
struct Health { int hp; }
struct Frozen { bool yes; }

const usz[NUM_COMPONENTS] COMPONENT_SIZE = { Position::size, Velocity::size, Health::size, Frozen::size };
const String[NUM_COMPONENTS] COMPONENT_NAME = { "Pos", "Vel", "Hp", "Frozen" };

fn uint bit(int c) => 1u << c;

typedef Entity = uint;

struct Archetype
{
    uint mask;
    List{Entity} entities;
    char*[NUM_COMPONENTS] columns;
    usz capacity;
}

fn sz Archetype.len(&self) => self.entities.len();

fn void* Archetype.at(&self, int c, sz row) => self.columns[c] + (usz)row * COMPONENT_SIZE[c];

// Добавляет пустую строку для e, возвращает её номер. (готово)
fn sz Archetype.push_row(&self, Entity e)
{
    if ((usz)self.entities.len() == self.capacity)
    {
        usz cap = self.capacity ? self.capacity * 2 : 8;
        for (int c = 0; c < NUM_COMPONENTS; c++)
        {
            if (self.mask & bit(c))
            {
                self.columns[c] = mem::realloc(self.columns[c], (sz)(cap * COMPONENT_SIZE[c]));
            }
        }
        self.capacity = cap;
    }
    self.entities.push(e);
    return self.entities.len() - 1;
}

// Удаляет строку row swap-remove'ом во ВСЕХ столбцах и в entities.
// Возвращает сущность, переехавшую в row, или NO_ENTITY, если row была последней.
fn Entity Archetype.remove_row(&self, sz row)
{
    sz last = self.entities.len() - 1;
    Entity moved = NO_ENTITY;
    if (row != last)
    {
        for (int c = 0; c < NUM_COMPONENTS; c++)
        {
            if (self.mask & bit(c)) mem::copy(self.at(c, row), self.at(c, last), (sz)COMPONENT_SIZE[c]);
        }
        moved = self.entities[last];
        self.entities[row] = moved;
    }
    (void)self.entities.pop();
    return moved;
}

const Entity NO_ENTITY = (Entity)uint::max;

struct Record
{
    int archetype;     // индекс в World.archetypes
    sz row;
}

struct World
{
    List{Archetype*} archetypes;
    List{Record} records;      // по Entity
    int moves;
}

fn void World.init(&self)
{
    self.archetypes.init(mem);
    self.records.init(mem);
}

fn void World.free(&self)
{
    foreach (a : self.archetypes.array_view())
    {
        foreach (col : a.columns) if (col) free(col);
        a.entities.free();
        free(a);
    }
    self.archetypes.free();
    self.records.free();
}

fn int World.find_or_create(&self, uint mask)
{
    foreach (i, a : self.archetypes.array_view()) if (a.mask == mask) return (int)i;
    Archetype* a = mem::new(Archetype, { .mask = mask });
    a.entities.init(mem);
    self.archetypes.push(a);
    return (int)self.archetypes.len() - 1;
}

fn Entity World.create(&self)
{
    int ai = self.find_or_create(0);
    Entity e = (Entity)self.records.len();
    sz row = self.archetypes[ai].push_row(e);
    self.records.push({ ai, row });
    return e;
}

fn uint World.mask_of(&self, Entity e) => self.archetypes[self.records[(uint)e].archetype].mask;

// Переносит e в архетип new_mask (см. шаги 1–4 в шапке).
fn void World.move_entity(&self, Entity e, uint new_mask)
{
    Record rec = self.records[(uint)e];
    Archetype* from = self.archetypes[rec.archetype];
    if (from.mask == new_mask) return;
    int ti = self.find_or_create(new_mask);
    Archetype* to = self.archetypes[ti];
    sz row = to.push_row(e);
    uint common = from.mask & new_mask;
    for (int c = 0; c < NUM_COMPONENTS; c++)
    {
        if (common & bit(c)) mem::copy(to.at(c, row), from.at(c, rec.row), (sz)COMPONENT_SIZE[c]);
    }
    Entity moved = from.remove_row(rec.row);
    if (moved != NO_ENTITY) self.records.get_ref((uint)moved).row = rec.row;
    self.records[(uint)e] = { ti, row };
    self.moves++;
}

fn void* World.get_raw(&self, Entity e, int c)
{
    Record rec = self.records[(uint)e];
    Archetype* a = self.archetypes[rec.archetype];
    if (!(a.mask & bit(c))) return null;
    return a.at(c, rec.row);
}

macro World.add(&self, Entity e, int c, value)
{
    self.move_entity(e, self.mask_of(e) | bit(c));
    *($Typeof(value)*)self.get_raw(e, c) = value;
}

macro World.remove(&self, Entity e, int c) => self.move_entity(e, self.mask_of(e) & ~bit(c));

macro @query(World* w, uint mask; @body(Archetype* a))
{
    foreach (a : w.archetypes.array_view())
    {
        if ((a.mask & mask) == mask && a.len() > 0) @body(a);
    }
}

fn void main()
{
    World w;
    w.init();
    defer w.free();

    Entity[300] es;
    for (int i = 0; i < 300; i++)
    {
        Entity e = w.create();
        es[i] = e;
        w.add(e, POS, (Position){ { (float)i, 0 } });
        if (i % 2 == 0) w.add(e, VEL, (Velocity){ { 1, (float)(i % 7) } });
        if (i % 3 == 0) w.add(e, HEALTH, (Health){ 100 + i });
    }
    // Часть движущихся «замораживаем» тегом, у части забираем здоровье.
    for (int i = 0; i < 300; i += 10) w.add(es[i], FROZEN, (Frozen){ true });
    for (int i = 0; i < 300; i += 9) w.remove(es[i], HEALTH);

    // Значения пережили все переезды.
    for (int i = 0; i < 300; i++)
    {
        Position* p = w.get_raw(es[i], POS);
        assert(p != null && p.p.x == (float)i, "position of entity %d lost during moves", i);
        Health* h = w.get_raw(es[i], HEALTH);
        bool should = i % 3 == 0 && i % 9 != 0;
        assert((h != null) == should, "health presence wrong for %d", i);
        if (h) assert(h.hp == 100 + i, "health value of %d corrupted", i);
    }
    // Записи согласованы с таблицами.
    foreach (ai, a : w.archetypes.array_view())
    {
        for (sz r = 0; r < a.len(); r++)
        {
            Record rec = w.records[(uint)a.entities[r]];
            assert(rec.archetype == (int)ai && rec.row == r, "record out of sync");
        }
    }

    io::printfn("archetypes=%d moves=%d", w.archetypes.len(), w.moves);
    foreach (a : w.archetypes.array_view())
    {
        if (a.len() == 0) continue;
        io::printf("  {");
        for (int c = 0; c < NUM_COMPONENTS; c++) if (a.mask & bit(c)) io::printf(" %s", COMPONENT_NAME[c]);
        io::printfn(" } x %d", a.len());
    }

    // Система движения: Pos & Vel, но без Frozen — проверяем маску внутри.
    int moved_count = 0;
    for (int tick = 0; tick < 10; tick++)
    {
        @query(&w, bit(POS) | bit(VEL); Archetype* a)
        {
            if (!(a.mask & bit(FROZEN)))
            {
                Position* ps = (Position*)a.columns[POS];
                Velocity* vs = (Velocity*)a.columns[VEL];
                for (sz r = 0; r < a.len(); r++) ps[r].p += vs[r].v;
                if (tick == 0) moved_count += (int)a.len();
            }
        };
    }
    float sum_y = 0;
    @query(&w, bit(POS); Archetype* a)
    {
        Position* ps = (Position*)a.columns[POS];
        for (sz r = 0; r < a.len(); r++) sum_y += ps[r].p.y;
    };
    io::printfn("moving entities=%d, sum of y after 10 ticks=%.1f", moved_count, sum_y);
    float expect_y = 0;
    for (int i = 0; i < 300; i += 2) if (i % 10 != 0) expect_y += 10.0f * (float)(i % 7);
    assert(moved_count == 120 && sum_y == expect_y, "frozen entities must not move");
    io::printn("archetypes OK");
}
