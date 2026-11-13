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
    int c0 = clampi((x - r) / CELL, 0, GRID_COLS - 1);
    int c1 = clampi((x + r) / CELL, 0, GRID_COLS - 1);
    int r0 = clampi((y - r) / CELL, 0, GRID_ROWS - 1);
    int r1 = clampi((y + r) / CELL, 0, GRID_ROWS - 1);
    for (int row = r0; row <= r1; row++)
    {
        for (int col = c0; col <= c1; col++)
        {
            int c = row * GRID_COLS + col;
            if (self.count[c] == CELL_CAP) { self.overflow++; continue; }
            self.items[c][self.count[c]++] = e;
        }
    }
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
    for (int c = 0; c < GRID_COLS * GRID_ROWS; c++)
    {
        for (int i = 0; i < g.count[c]; i++)
        {
            for (int j = i + 1; j < g.count[c]; j++)
            {
                uint a = g.items[c][i];
                uint b = g.items[c][j];
                Collider* ca = w.colliders.get(a);
                Collider* cb = w.colliders.get(b);
                if (!(ca.mask & cb.layer) && !(cb.mask & ca.layer)) continue;
                tests++;
                Transform* ta = w.transforms.get(a);
                Transform* tb = w.transforms.get(b);
                long dx = (long)ta.x - tb.x;
                long dy = (long)ta.y - tb.y;
                long rr = (long)(ca.radius + cb.radius);
                if (dx * dx + dy * dy >= rr * rr) continue;
                uint lo = a < b ? a : b;
                uint hi = a < b ? b : a;
                if (!already_reported(q, lo, hi)) q.push({ lo, hi });
            }
        }
    }
    return tests;
}
