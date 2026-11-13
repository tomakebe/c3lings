// =====================================================================
//  e0804 · Равномерная сетка (uniform grid)
// =====================================================================
//
//  Сначала прочитайте engine/docs/08_scene.md (раздел 8.1).
//
//  «Кто находится в этом прямоугольнике?» — самый частый вопрос к
//  сцене: камера (что рисовать), AI (кого я вижу), физика (с кем я
//  могу столкнуться), звук (какие источники рядом). Перебор всех N
//  объектов — O(N) на запрос, O(N^2) на «все со всеми».
//
//  Равномерная сетка делит мир на клетки размера CELL. Объект с
//  координатами (x, y) лежит в клетке (x / CELL, y / CELL). Запрос
//  прямоугольника проверяет только объекты из клеток, которые
//  прямоугольник задевает.
//
//  Как хранить содержимое клеток? Наивно — List в каждой клетке:
//  тысячи мелких аллокаций и прыжки по памяти. В движках (и в
//  broadphase физики, и в частицах на GPU) делают «компактную сетку»
//  через сортировку подсчётом — перестраивают её целиком каждый кадр:
//
//      1) count[c]  — сколько объектов в клетке c;
//      2) start[c]  — префиксная сумма: start[0]=0,
//                     start[c+1] = start[c] + count[c];
//      3) раскладываем: entries[start[c] + k] = id.
//
//      start:   0  0  2  2  5  6 ...          (CELLS + 1 элементов)
//      entries: [7 3][ ][1 9 4][8] ...         — объекты клетки c лежат
//                                                в entries[start[c]..start[c+1])
//
//  Два линейных прохода по объектам, один по клеткам, ноль аллокаций,
//  и содержимое каждой клетки лежит в памяти подряд. Перестроить
//  такую сетку для 10 000 объектов — микросекунды; это обычно дешевле,
//  чем аккуратно перемещать объекты между клетками.
//
//  ЗАДАЧА: реализуйте
//    * Grid.build — сортировку подсчётом, как описано выше;
//    * Grid.query — сбор id всех объектов внутри прямоугольника
//      [min_x, max_x] x [min_y, max_y] (границы включительно).
//      Увеличивайте self.tested для каждого объекта, который вы
//      проверили на попадание, — так тест сравнит работу с перебором.
//
import std::io;
import std::sort;

const int WORLD = 256;          // мир: [0, WORLD) x [0, WORLD)
const int CELL = 32;
const int GRID_W = WORLD / CELL;
const int CELLS = GRID_W * GRID_W;
const int N = 400;

struct Point { int x, y; }

struct Grid
{
    int[CELLS] count;
    int[CELLS + 1] start;
    int[N] entries;
    int tested;
}

fn int cell_coord(int v) => v < 0 ? 0 : (v >= WORLD ? GRID_W - 1 : v / CELL);
fn int cell_index(int cx, int cy) => cy * GRID_W + cx;
fn int cell_of(Point p) => cell_index(cell_coord(p.x), cell_coord(p.y));

fn void Grid.build(&self, Point[] pts)
{
    self.count[..] = 0;
    foreach (p : pts) self.count[cell_of(p)]++;
    self.start[0] = 0;
    for (int c = 0; c < CELLS; c++) self.start[c + 1] = self.start[c] + self.count[c];
    // count переиспользуем как «сколько уже положили в клетку».
    self.count[..] = 0;
    foreach (id, p : pts)
    {
        int c = cell_of(p);
        self.entries[self.start[c] + self.count[c]++] = (int)id;
    }
}

// Возвращает число найденных id, записанных в out.
fn int Grid.query(&self, Point[] pts, int min_x, int min_y, int max_x, int max_y, int[] out)
{
    int n = 0;
    for (int cy = cell_coord(min_y); cy <= cell_coord(max_y); cy++)
    {
        for (int cx = cell_coord(min_x); cx <= cell_coord(max_x); cx++)
        {
            int c = cell_index(cx, cy);
            for (int k = self.start[c]; k < self.start[c + 1]; k++)
            {
                int id = self.entries[k];
                Point p = pts[id];
                self.tested++;
                if (p.x >= min_x && p.x <= max_x && p.y >= min_y && p.y <= max_y) out[n++] = id;
            }
        }
    }
    return n;
}

// ---------------------------------------------------------------------
// Ниже — тесты. Менять не нужно.
// ---------------------------------------------------------------------

// Детерминированный генератор (LCG) с фиксированным seed.
struct Rng { uint state; }
fn int Rng.next(&self, int bound)
{
    self.state = self.state * 1664525 + 1013904223;
    return (int)((self.state >> 8) % (uint)bound);
}

fn int brute(Point[] pts, int min_x, int min_y, int max_x, int max_y, int[] out)
{
    int n = 0;
    foreach (id, p : pts)
    {
        if (p.x >= min_x && p.x <= max_x && p.y >= min_y && p.y <= max_y) out[n++] = (int)id;
    }
    return n;
}

fn void check_query(Grid* g, Point[] pts, String label, int x0, int y0, int x1, int y1)
{
    int[N] got;
    int[N] want;
    g.tested = 0;
    int n = g.query(pts, x0, y0, x1, y1, &got);
    int m = brute(pts, x0, y0, x1, y1, &want);
    quicksort(got[:n]);
    assert(n == m, "%s: grid found %d, brute force found %d", label, n, m);
    for (int i = 0; i < n; i++) assert(got[i] == want[i], "%s: different ids", label);
    assert(g.tested < N || x1 - x0 >= WORLD - 1, "%s: grid tested as many points as brute force", label);
    uint sum = 0;
    for (int i = 0; i < n; i++) sum = sum * 31 + (uint)got[i];
    io::printfn("%-8s found=%3d tested=%3d (brute force: %d) checksum=%d", label, n, g.tested, N, sum);
}

fn void main()
{
    Point[N] pts;
    Rng rng = { 12345 };
    foreach (&p : pts) *p = { rng.next(WORLD), rng.next(WORLD) };

    Grid g;
    g.build(&pts);
    assert(g.start[CELLS] == N, "prefix sum must end at N");
    for (int c = 0; c < CELLS; c++)
    {
        for (int k = g.start[c]; k < g.start[c + 1]; k++)
        {
            assert(cell_of(pts[g.entries[k]]) == c, "entry stored in the wrong cell");
        }
    }

    check_query(&g, &pts, "small", 40, 40, 70, 70);
    check_query(&g, &pts, "edge", 0, 0, 31, 31);
    check_query(&g, &pts, "strip", 0, 100, 255, 110);
    check_query(&g, &pts, "all", 0, 0, 255, 255);

    // Кадр 2: все объекты сдвинулись — просто перестраиваем сетку.
    foreach (&p : pts) *p = { (p.x + 37) % WORLD, (p.y + 91) % WORLD };
    g.build(&pts);
    check_query(&g, &pts, "moved", 40, 40, 70, 70);
    io::printn("uniform grid ok");
}
