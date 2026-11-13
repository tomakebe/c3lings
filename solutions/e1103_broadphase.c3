// =====================================================================
//  e1103 · Broadphase: sort-and-sweep и равномерная сетка
// =====================================================================
//
//  Сначала прочитайте engine/docs/11_physics.md (раздел «Broadphase»).
//
//  Проверять каждую пару тел — O(n²): 300 тел дают 44 850 тестов за
//  шаг, 5000 тел — 12,5 млн. Задача broadphase — дёшево выбросить пары,
//  которые ЗАВЕДОМО не пересекаются, и отдать narrowphase'у короткий
//  список кандидатов (пересекающиеся AABB).
//
//  1) Sort-and-sweep (sweep-and-prune, SAP). Сортируем тела по min.x и
//     идём слева направо, держа список «активных» (тех, чей интервал по
//     x ещё не кончился). Новое тело сравниваем только с активными.
//
//        x ──►  [==A==]
//                  [===B====]          активные при входе C: {B}
//                         [==C==]      (A уже закончился — выброшен)
//
//     Трюк, ради которого SAP любят: между кадрами тела почти не
//     двигаются, и массив остаётся почти отсортированным. Сортировка
//     ВСТАВКАМИ на почти отсортированном массиве — O(n + k), где k —
//     число инверсий. Поэтому мы храним порядок `order` между кадрами
//     и пересортировываем его вставками. Число обменов (swaps) равно
//     числу инверсий — его и проверяет main().
//
//  2) Равномерная сетка. Мир 100×100 режем на клетки CELL×CELL. Каждое
//     тело кладём во ВСЕ клетки, которые задевает его AABB, и проверяем
//     пары только внутри клетки. Проблема: пара тел, накрывающих две
//     общие клетки, найдётся дважды. Классическое решение без хеш-сета:
//     сообщать пару только в той клетке, где лежит левый-нижний угол
//     ПЕРЕСЕЧЕНИЯ их AABB, т.е. в клетке
//         (max(cellA.min.x, cellB.min.x), max(cellA.min.y, cellB.min.y)).
//     Для неограниченного мира вместо плотного массива берут хеш
//     (cx, cy) -> bucket (spatial hash) — логика та же.
//
//  ЗАДАЧА: допишите insertion sort + sweep в `Sap.update` и заполнение/
//  обход клеток в `grid_pairs`. main() сверит оба результата с
//  перебором O(n²).
//
import std::io, std::math, std::sort, std::collections::list;

alias Vec2 = float[<2>];

struct Aabb
{
    Vec2 min;
    Vec2 max;
}

struct Pair
{
    int a;
    int b;
}

const float WORLD = 100;
const float CELL = 10;
const int GRID = (int)(WORLD / CELL);
const int N = 300;

fn bool overlap(Aabb a, Aabb b)
{
    return a.min.x <= b.max.x && b.min.x <= a.max.x
        && a.min.y <= b.max.y && b.min.y <= a.max.y;
}

// ------------------------------------------------------------------ O(n²)
fn void brute_pairs(Aabb[] boxes, List{Pair}* out)
{
    for (int i = 0; i < boxes.len; i++)
    {
        for (int j = i + 1; j < boxes.len; j++)
        {
            if (overlap(boxes[i], boxes[j])) out.push({ i, j });
        }
    }
}

// ------------------------------------------------------------------ SAP
struct Sap
{
    List{int} order;    // индексы тел, отсортированные по min.x (живут между кадрами)
    List{int} active;
    long swaps;         // обменов при последней сортировке
    long tests;         // вызовов overlap() при последнем sweep
}

fn void Sap.free(&self)
{
    self.order.free();
    self.active.free();
}

fn void Sap.update(&self, Aabb[] boxes, List{Pair}* out)
{
    if (self.order.len() != boxes.len)
    {
        self.order.clear();
        for (int i = 0; i < boxes.len; i++) self.order.push(i);
    }
    self.swaps = 0;
    self.tests = 0;

    // 1. Сортировка вставками по min.x (строгое сравнение: равные не меняем).
    for (sz i = 1; i < self.order.len(); i++)
    {
        sz j = i;
        while (j > 0 && boxes[self.order[j - 1]].min.x > boxes[self.order[j]].min.x)
        {
            int tmp = self.order[j - 1];
            self.order[j - 1] = self.order[j];
            self.order[j] = tmp;
            self.swaps++;
            j--;
        }
    }

    // 2. Sweep: выбрасываем из active закончившиеся интервалы, проверяем остальных.
    self.active.clear();
    foreach (idx : self.order)
    {
        Aabb box = boxes[idx];
        sz k = 0;
        while (k < self.active.len())
        {
            int other = self.active[k];
            if (boxes[other].max.x < box.min.x)
            {
                self.active.remove_at(k);
                continue;
            }
            self.tests++;
            if (overlap(boxes[other], box)) out.push({ math::min(other, idx), math::max(other, idx) });
            k++;
        }
        self.active.push(idx);
    }
}

// ------------------------------------------------------------------ сетка
fn int cell_of(float v) => math::clamp((int)(v / CELL), 0, GRID - 1);

fn long grid_pairs(Aabb[] boxes, List{Pair}* out)
{
    List{int}[GRID * GRID] cells;
    defer foreach (&c : cells) c.free();
    long tests = 0;

    // 1. Каждое тело — во все клетки, которые накрывает его AABB.
    foreach (i, b : boxes)
    {
        for (int cy = cell_of(b.min.y); cy <= cell_of(b.max.y); cy++)
        {
            for (int cx = cell_of(b.min.x); cx <= cell_of(b.max.x); cx++)
            {
                cells[cy * GRID + cx].push((int)i);
            }
        }
    }
    // 2. Пары внутри клетки + правило «сообщать только в клетке угла пересечения».
    for (int cy = 0; cy < GRID; cy++)
    {
        for (int cx = 0; cx < GRID; cx++)
        {
            List{int}* cell = &cells[cy * GRID + cx];
            for (sz i = 0; i < cell.len(); i++)
            {
                for (sz j = i + 1; j < cell.len(); j++)
                {
                    Aabb a = boxes[(*cell)[i]];
                    Aabb b = boxes[(*cell)[j]];
                    tests++;
                    if (!overlap(a, b)) continue;
                    int ox = math::max(cell_of(a.min.x), cell_of(b.min.x));
                    int oy = math::max(cell_of(a.min.y), cell_of(b.min.y));
                    if (ox != cx || oy != cy) continue;
                    int ia = (*cell)[i];
                    int ib = (*cell)[j];
                    out.push({ math::min(ia, ib), math::max(ia, ib) });
                }
            }
        }
    }
    return tests;
}

// ------------------------------------------------------------------ проверка
uint rng_state = 12345;
fn float rnd(float lo, float hi)
{
    rng_state = rng_state * 1664525 + 1013904223;
    return lo + (float)(rng_state >> 8) / (float)(1 << 24) * (hi - lo);
}

fn int cmp_pair(Pair x, Pair y) => x.a != y.a ? x.a - y.a : x.b - y.b;

fn void normalize(List{Pair}* l)
{
    foreach (&p : l)
    {
        if (p.a > p.b) { int t = p.a; p.a = p.b; p.b = t; }
    }
    quicksort(l, &cmp_pair);
}

fn void expect_same(String what, List{Pair}* got, List{Pair}* want)
{
    normalize(got);
    assert(got.len() == want.len(), "%s: found %d pairs, expected %d", what, got.len(), want.len());
    for (sz i = 0; i < want.len(); i++)
    {
        Pair g = (*got)[i];
        Pair w = (*want)[i];
        assert(g.a == w.a && g.b == w.b, "%s: pair #%d is (%d,%d), expected (%d,%d)", what, i, g.a, g.b, w.a, w.b);
    }
}

fn void main()
{
    Aabb[N] boxes;
    foreach (&b : boxes)
    {
        Vec2 p = { rnd(0, 94), rnd(0, 94) };
        Vec2 s = { rnd(1, 6), rnd(1, 6) };
        *b = { p, p + s };
    }
    Sap sap;
    defer sap.free();
    long first_swaps;

    for (int frame = 1; frame <= 2; frame++)
    {
        List{Pair} brute; defer brute.free();
        List{Pair} swept; defer swept.free();
        List{Pair} grid; defer grid.free();

        brute_pairs(&boxes, &brute);
        normalize(&brute);
        sap.update(&boxes, &swept);
        long grid_tests = grid_pairs(&boxes, &grid);
        expect_same("sap", &swept, &brute);
        expect_same("grid", &grid, &brute);

        long brute_tests = (long)N * (N - 1) / 2;
        assert(sap.tests * 4 < brute_tests, "sap does too many tests: %d", sap.tests);
        assert(grid_tests * 4 < brute_tests, "grid does too many tests: %d", grid_tests);
        if (frame == 1) first_swaps = sap.swaps;
        if (frame == 2) assert(sap.swaps * 20 < first_swaps, "insertion sort should exploit temporal coherence");
        io::printfn("frame %d: pairs=%d  sap swaps=%d  sap/grid both match brute force", frame, brute.len(), sap.swaps);

        // Сдвигаем тела чуть-чуть: порядок по x почти сохраняется.
        foreach (&b : boxes)
        {
            Vec2 d = { rnd(-0.5f, 0.5f), rnd(-0.5f, 0.5f) };
            b.min += d;
            b.max += d;
        }
    }
    io::printn("temporal coherence: frame 2 needs far fewer swaps");
}
