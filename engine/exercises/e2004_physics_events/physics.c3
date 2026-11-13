// ---------------------------------------------------------------------
//  mini::physics — интеграция, тороидальный мир и коллизии кругов
//  с broadphase на равномерной сетке (глава 11).
//
//      мир 64x24 клетки, сетка 8x3 ячеек по 8x8 клеток
//      +-------+-------+-------+ ...
//      |  o    |       |   O   |      каждый коллайдер попадает во ВСЕ
//      |    o--+--o    |       |      ячейки, которые задевает его AABB
//      +-------+-------+-------+
//
//  Narrowphase: круги пересекаются, если dx^2 + dy^2 < (ra + rb)^2
//  (в long: квадраты FX-координат не помещаются в int с запасом).
//  Пара может встретиться в нескольких ячейках — её надо сообщить ОДИН раз.
// ---------------------------------------------------------------------
module mini::physics;
import mini::core, mini::ecs, mini::events;

const int WORLD_W = 64 * core::FX;
const int WORLD_H = 24 * core::FX;
const int CELL = 8 * core::FX;
const int GRID_COLS = 8;
const int GRID_ROWS = 3;
const int CELL_CAP = 32;

struct Grid
{
    uint[CELL_CAP][GRID_COLS * GRID_ROWS] items;
    int[GRID_COLS * GRID_ROWS] count;
    int overflow;
}

fn int wrap(int v, int size)
{
    v %= size;
    return v < 0 ? v + size : v;
}

<* Сдвинуть всё, что движется; координаты заворачиваются (тор). *>
fn int integrate(World* w)
{
    for (uint i = 0; i < w.velocities.len; i++)
    {
        uint e = w.velocities.dense[i];
        Transform* t = w.transforms.get(e);
        if (!t) continue;
        Velocity v = w.velocities.data[i];
        t.x = wrap(t.x + v.vx, WORLD_W);
        t.y = wrap(t.y + v.vy, WORLD_H);
    }
    return (int)w.velocities.len;
}

fn int clampi(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

<* Положить e во все ячейки, которые задевает квадрат [x-r, x+r] x [y-r, y+r]. *>
fn void Grid.insert(&self, uint e, int x, int y, int r)
{
    // TODO: диапазон ячеек по x и y (clampi в границы сетки), вставить в каждую
    (void)e; (void)x; (void)y; (void)r;
}

fn void Grid.build(&self, World* w)
{
    *self = {};
    for (uint i = 0; i < w.colliders.len; i++)
    {
        uint e = w.colliders.dense[i];
        Transform* t = w.transforms.get(e);
        if (!t) continue;
        self.insert(e, t.x, t.y, w.colliders.data[i].radius);
    }
}

fn bool already_reported(EventQueue* q, uint a, uint b)
{
    foreach (ev : q.pending()) if (ev.a == a && ev.b == b) return true;
    return false;
}

<*
 Для каждой ячейки проверить все пары (i < j). Пара интересна, если
 (a.mask & b.layer) || (b.mask & a.layer). При пересечении кругов —
 push события {min(a,b), max(a,b)}, если такой пары ещё нет в pending().
 Вернуть число проверенных пар (для профайлера).
*>
fn int detect_collisions(World* w, Grid* g, EventQueue* q)
{
    int tests = 0;
    // TODO
    (void)w; (void)g; (void)q;
    return tests;
}
