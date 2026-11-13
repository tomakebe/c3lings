// =====================================================================
//  e0805 · Квадродерево (quadtree)
// =====================================================================
//
//  Сначала прочитайте engine/docs/08_scene.md (раздел 8.2).
//
//  Сетка хороша, когда объекты распределены равномерно. Но в
//  реальном уровне 90% объектов толпятся в городе, а вокруг —
//  пустое поле. Мелкая сетка тратит память на пустые клетки,
//  крупная — складывает весь город в одну клетку.
//
//  Квадродерево адаптируется к плотности: узел — квадрат; если в нём
//  больше CAP точек, он делится на 4 равных квадранта, и точки
//  переезжают в детей. Где пусто — дерево мелкое, где густо — глубокое.
//
//      +-------+-------+        квадрант k:  бит 0 = правая половина
//      |   0   |   1   |                     бит 1 = нижняя половина
//      +---+---+-------+
//      | 2 | 3 |   3   |        (y растёт вниз, как на экране)
//      +---+---+       |
//      |   |   |       |
//      +---+---+-------+
//
//  Реализация в духе движка:
//    * все узлы — в одном List{QNode}, ссылки — индексы; 4 ребёнка
//      создаются подряд, и узлу достаточно хранить first_child;
//    * точки в листе — интрузивный односвязный список через массив
//      next[id] (head — первая точка листа). Ни одной аллокации на
//      точку, и нет жёсткого лимита вместимости листа;
//    * MAX_DEPTH ограничивает деление: 10 точек в одной координате
//      иначе делили бы дерево бесконечно.
//
//  Запрос прямоугольника спускается только в те узлы, чей квадрат
//  пересекается с прямоугольником, — остальные поддеревья отсекаются
//  целиком.
//
//  ЗАДАЧА: реализуйте
//    * QuadTree.split   — превратить лист в узел с 4 детьми и
//                         раздать его точки детям;
//    * QuadTree.insert  — спуститься до листа, добавить точку,
//                         при переполнении (count > CAP и depth <
//                         MAX_DEPTH) вызвать split;
//    * QuadTree.query   — рекурсивный поиск; self.visited += 1 на
//                         каждый посещённый узел, self.tested += 1 на
//                         каждую проверенную точку.
//
import std::io;
import std::sort;
import std::collections::list;

const int WORLD = 1024;
const int CAP = 4;
const int MAX_DEPTH = 8;
const int N = 500;
const int NONE = -1;

struct Point { int x, y; }

struct QNode
{
    int x, y, size;     // квадрат [x, x+size) x [y, y+size)
    int depth;
    int first_child;    // NONE у листа; иначе дети first_child .. first_child+3
    int head;           // первая точка листа (список через next[])
    int count;          // число точек в листе
}

struct QuadTree
{
    List{QNode} nodes;
    Point[N] pts;
    int[N] next;
    int visited;
    int tested;
}

fn void QuadTree.init(&self)
{
    self.nodes.push({ 0, 0, WORLD, 0, NONE, NONE, 0 });
}

fn void QuadTree.free(&self) => self.nodes.free();

// В какой квадрант (0..3) узла попадает точка.
fn int quadrant(QNode* n, Point p)
{
    int half = n.size / 2;
    int k = 0;
    if (p.x >= n.x + half) k |= 1;
    if (p.y >= n.y + half) k |= 2;
    return k;
}

// Добавить точку id в начало списка листа.
fn void QuadTree.push_point(&self, int node, int id)
{
    self.next[id] = self.nodes[node].head;
    self.nodes[node].head = id;
    self.nodes[node].count++;
}

fn void QuadTree.split(&self, int node)
{
    // TODO:
    //   1. Скопируйте узел: `QNode n = self.nodes[node];` (копия, а не
    //      указатель: self.nodes.push может перевыделить память List,
    //      и указатель на элемент станет висячим!).
    //   2. Запомните first = (int)self.nodes.len() и добавьте 4 ребёнка
    //      размера n.size / 2 (квадрант k: бит 0 — правая половина,
    //      бит 1 — нижняя), depth + 1, first_child = head = NONE.
    //   3. Пройдите по списку точек n.head -> next[] и раздайте их
    //      детям через push_point(first + quadrant(&n, ...), id).
    //      Осторожно: push_point перезаписывает next[id].
    //   4. Сделайте узел внутренним: first_child = first, head = NONE, count = 0.
    //   5. Все точки могли уйти в одного ребёнка — если он переполнен
    //      (count > CAP && depth < MAX_DEPTH), разделите и его.
}

fn void QuadTree.insert(&self, int id, Point p)
{
    self.pts[id] = p;
    // TODO: спуститесь от корня (узел 0) до листа:
    //       node = first_child + quadrant(...), пока first_child != NONE.
    //       Добавьте точку в лист (push_point) и при переполнении
    //       (count > CAP && depth < MAX_DEPTH) вызовите split.
    self.push_point(0, id);
}

fn int QuadTree.query(&self, int node, int min_x, int min_y, int max_x, int max_y, int[] out, int n)
{
    // TODO: self.visited++; если квадрат узла [x, x+size-1] x [y, y+size-1]
    //       не пересекается с запросом — верните n.
    //       Внутренний узел: рекурсивно опросите 4 детей, протаскивая n.
    //       Лист: пройдите список точек (self.tested++ на каждую) и
    //       допишите подходящие id в out[n++]. Верните новое n.
    return n;
}

// ---------------------------------------------------------------------
// Ниже — тесты. Менять не нужно.
// ---------------------------------------------------------------------

struct Rng { uint state; }
fn int Rng.next(&self, int bound)
{
    self.state = self.state * 1664525 + 1013904223;
    return (int)((self.state >> 8) % (uint)bound);
}

fn void QuadTree.stats(&self, int* leaves, int* max_depth, int* total)
{
    foreach (n : self.nodes)
    {
        if (n.first_child != NONE) continue;
        (*leaves)++;
        if (n.depth > *max_depth) *max_depth = n.depth;
        *total += n.count;
        assert(n.count <= CAP || n.depth == MAX_DEPTH, "overfull leaf above MAX_DEPTH");
        int c = 0;
        for (int id = n.head; id != NONE; id = self.next[id])
        {
            Point p = self.pts[id];
            assert(p.x >= n.x && p.x < n.x + n.size && p.y >= n.y && p.y < n.y + n.size,
                   "point stored outside its leaf");
            c++;
        }
        assert(c == n.count, "leaf count does not match its list");
    }
}

fn void check_query(QuadTree* t, String label, int x0, int y0, int x1, int y1)
{
    int[N] got;
    t.visited = 0;
    t.tested = 0;
    int n = t.query(0, x0, y0, x1, y1, &got, 0);
    quicksort(got[:n]);
    int m = 0;
    uint sum = 0;
    for (int id = 0; id < N; id++)
    {
        Point p = t.pts[id];
        if (p.x >= x0 && p.x <= x1 && p.y >= y0 && p.y <= y1)
        {
            assert(m < n && got[m] == id, "%s: result differs from brute force", label);
            m++;
            sum = sum * 31 + (uint)id;
        }
    }
    assert(n == m, "%s: tree found %d, brute force found %d", label, n, m);
    io::printfn("%-7s found=%3d visited=%3d tested=%3d (brute force: %d) checksum=%d",
                label, n, t.visited, t.tested, N, sum);
}

fn void main()
{
    QuadTree t;
    t.init();
    defer t.free();

    // Город: 400 точек в квадрате 64x64; поле: 90 точек по всему миру;
    // и 10 точек в одной и той же координате (проверка MAX_DEPTH).
    Rng rng = { 2024 };
    for (int id = 0; id < N; id++)
    {
        int x = 5;
        int y = 5;
        if (id < 400)
        {
            x = 600 + rng.next(64);
            y = 200 + rng.next(64);
        }
        else if (id < 490)
        {
            x = rng.next(WORLD);
            y = rng.next(WORLD);
        }
        t.insert(id, { x, y });
    }

    int leaves, max_depth, total;
    t.stats(&leaves, &max_depth, &total);
    assert(total == N, "points lost during splits");
    assert(t.nodes[0].first_child != NONE, "root must have been split");
    io::printfn("nodes=%d leaves=%d max_depth=%d", t.nodes.len(), leaves, max_depth);

    check_query(&t, "city", 600, 200, 615, 215);
    check_query(&t, "field", 0, 600, 300, 1000);
    check_query(&t, "stack", 0, 0, 10, 10);
    check_query(&t, "all", 0, 0, WORLD - 1, WORLD - 1);
    io::printn("quadtree ok");
}
