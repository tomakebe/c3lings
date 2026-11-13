// =====================================================================
//  e0801 · Иерархия трансформаций: local -> world
// =====================================================================
//
//  Сначала прочитайте engine/docs/08_scene.md (разделы 1–3).
//
//  Каждый объект сцены хранит ЛОКАЛЬНУЮ трансформацию — положение,
//  поворот и масштаб относительно родителя. Рендеру, физике и звуку
//  нужна МИРОВАЯ трансформация. Связь одна:
//
//      world(node) = world(parent) * local(node)
//      world(root) = local(root)
//
//  В 2D трансформацию удобно хранить как аффинную матрицу 2x3
//  (столбцы (a,b), (c,d) — повёрнутые и масштабированные оси X и Y,
//  (tx,ty) — перенос):
//
//      | a  c  tx |   | x |     x' = a*x + c*y + tx
//      | b  d  ty | * | y |     y' = b*x + d*y + ty
//      | 0  0  1  |   | 1 |
//
//  Композиция P * C означает «сначала C, потом P». Порядок важен:
//  умножение матриц НЕ коммутативно. Ошибка «local * parent» вместо
//  «parent * local» — классика: всё выглядит почти правильно, пока
//  у родителя нет поворота или масштаба.
//
//  Произведение P * C (выведите его сами на бумаге — это полезно):
//
//      a  = P.a*C.a + P.c*C.b        c  = P.a*C.c + P.c*C.d
//      b  = P.b*C.a + P.d*C.b        d  = P.b*C.c + P.d*C.d
//      tx = P.a*C.tx + P.c*C.ty + P.tx
//      ty = P.b*C.tx + P.d*C.ty + P.ty
//
//  Узлы лежат в плоском массиве, ссылка на родителя — индекс
//  (NO_PARENT у корня). Указатели в сцене — источник висячих ссылок
//  (см. главу 03), индексы — нет.
//
//  ЗАДАЧА: реализуйте
//    * Affine2.mul       — композицию self * c;
//    * Affine2.apply     — применение к точке;
//    * world_matrix      — мировую матрицу узла: пройдите вверх по
//                          родителям и перемножьте в правильном порядке.
//  Самотесты в main проверят солнечную систему и танк с башней.
//
import std::io;
import std::math;

const int NO_PARENT = -1;

struct Vec2 { float x, y; }

struct Affine2
{
    float a, b, c, d, tx, ty;
}

fn Affine2 identity() => { 1, 0, 0, 1, 0, 0 };

// Поворот (в градусах), равномерный масштаб, перенос.
fn Affine2 from_trs(float x, float y, float deg, float scale)
{
    float r = (float)(deg * math::PI / 180.0);
    float cs = math::cos(r) * scale;
    float sn = math::sin(r) * scale;
    return { cs, sn, -sn, cs, x, y };
}

// self * c : сначала c, потом self.
fn Affine2 Affine2.mul(self, Affine2 c)
{
    return {
        self.a * c.a + self.c * c.b,
        self.b * c.a + self.d * c.b,
        self.a * c.c + self.c * c.d,
        self.b * c.c + self.d * c.d,
        self.a * c.tx + self.c * c.ty + self.tx,
        self.b * c.tx + self.d * c.ty + self.ty,
    };
}

fn Vec2 Affine2.apply(self, Vec2 p)
{
    return { self.a * p.x + self.c * p.y + self.tx, self.b * p.x + self.d * p.y + self.ty };
}

struct Node
{
    String name;
    int parent;
    Affine2 local;
}

fn Affine2 world_matrix(Node[] nodes, int i)
{
    Affine2 m = nodes[i].local;
    for (int p = nodes[i].parent; p != NO_PARENT; p = nodes[p].parent)
    {
        m = nodes[p].local.mul(m);
    }
    return m;
}

// ---------------------------------------------------------------------
// Ниже — тесты. Менять не нужно.
// ---------------------------------------------------------------------

fn bool near(float a, float b) => math::abs(a - b) < 0.001f;

fn float clean(float v) => math::abs(v) < 0.0005f ? 0.0f : v;

fn Vec2 world_pos(Node[] nodes, int i) => world_matrix(nodes, i).apply({ 0, 0 });

fn void print_node(Node[] nodes, int i)
{
    Vec2 p = world_pos(nodes, i);
    io::printfn("%-7s world=(%.2f, %.2f)", nodes[i].name, clean(p.x), clean(p.y));
}

fn void main()
{
    // --- базовая алгебра ---
    Affine2 t = from_trs(5, 0, 0, 1);
    Affine2 r = from_trs(0, 0, 90, 1);
    Vec2 p = r.mul(t).apply({ 1, 0 });   // сначала сдвиг, потом поворот
    assert(near(p.x, 0) && near(p.y, 6), "R*T: expected (0,6)");
    p = t.mul(r).apply({ 1, 0 });        // сначала поворот, потом сдвиг
    assert(near(p.x, 5) && near(p.y, 1), "T*R: expected (5,1)");
    Affine2 i = identity().mul(r);
    assert(near(i.a, r.a) && near(i.c, r.c), "I*R must be R");

    // --- солнечная система ---
    Node[] sys = {
        { "sun",    NO_PARENT, from_trs(100, 100, 0, 1) },
        { "planet", 0,         from_trs(10, 0, 0, 1) },
        { "moon",   1,         from_trs(2, 0, 0, 1) },
    };
    assert(near(world_pos(sys, 2).x, 112), "moon must be at x=112");

    sys[0].local = from_trs(100, 100, 90, 1);   // солнце повернулось на 90
    Vec2 moon = world_pos(sys, 2);
    assert(near(moon.x, 100) && near(moon.y, 112), "rotating the sun must carry the moon");

    sys[1].local = from_trs(10, 0, 90, 2);      // планета: поворот и масштаб x2
    moon = world_pos(sys, 2);
    assert(near(moon.x, 96) && near(moon.y, 110), "planet scale/rotation must affect moon offset");
    io::printn("solar system:");
    for (int k = 0; k < sys.len; k++) print_node(sys, k);

    // --- танк с башней и стволом ---
    Node[] tank = {
        { "hull",   NO_PARENT, from_trs(0, 0, 45, 1) },
        { "turret", 0,         from_trs(0, 1, -45, 1) },
        { "barrel", 1,         from_trs(3, 0, 0, 1) },
    };
    Vec2 tip = world_matrix(tank, 2).apply({ 1, 0 });
    assert(near(tip.x, 4 - 0.7071f) && near(tip.y, 0.7071f), "barrel tip");
    io::printn("tank:");
    for (int k = 0; k < tank.len; k++) print_node(tank, k);
    io::printfn("barrel tip=(%.2f, %.2f)", clean(tip.x), clean(tip.y));
    io::printn("hierarchy ok");
}
