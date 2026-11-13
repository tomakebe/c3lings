// =====================================================================
//  e1104 · SAT: теорема о разделяющей оси для выпуклых многоугольников
// =====================================================================
//
//  Сначала прочитайте engine/docs/11_physics.md (раздел «SAT»).
//
//  Два выпуклых тела НЕ пересекаются тогда и только тогда, когда
//  существует ось, на которую их проекции не перекрываются. Для
//  многоугольников в 2D достаточно проверить нормали всех рёбер обоих
//  тел (в 3D для многогранников — ещё и попарные векторные произведения
//  рёбер).
//
//            ось n
//         ──────────────────────────►
//         [ проекция A ]   [ проекция B ]      зазор => разделены
//
//  Если ни одна ось не разделяет — тела пересекаются, и ось с
//  НАИМЕНЬШИМ перекрытием даёт нормаль контакта и глубину (minimum
//  translation vector, MTV). Ещё два важных момента:
//
//  * Нормаль надо ориентировать от A к B: если dot(cB - cA, n) < 0,
//    разворачиваем её. Иначе солвер будет толкать тела друг в друга.
//  * Ранний выход: как только найдена разделяющая ось — false. В
//    реальном движке её ещё и КЕШИРУЮТ между кадрами (Box2D, Bullet):
//    в следующем кадре проверяют её первой — обычно она та же.
//
//  Проекция многоугольника на ось — [min, max] из dot(v, axis) по
//  всем вершинам. Опорная точка (support point) — вершина с
//  максимальным dot(v, dir); это кирпичик и для GJK, и для поиска
//  точки контакта: самая глубокая точка B — support(B, -n).
//
//  Вершины многоугольника хранятся против часовой стрелки (CCW), тогда
//  внешняя нормаль ребра e = b - a — это (e.y, -e.x), нормированная.
//
//  ЗАДАЧА: реализуйте `project`, `support` и `sat` (TODO).
//
import std::io, std::math;

alias Vec2 = float[<2>];

const int MAX_VERTS = 8;

struct Polygon
{
    Vec2[MAX_VERTS] v;
    int count;
}

struct Contact
{
    Vec2 normal;   // от A к B
    float depth;
    Vec2 point;    // самая глубокая точка B
}

fn Vec2 Polygon.center(&self)
{
    Vec2 c;
    for (int i = 0; i < self.count; i++) c += self.v[i];
    return c / (float)self.count;
}

fn Vec2 Polygon.edge_normal(&self, int i)
{
    Vec2 e = self.v[(i + 1) % self.count] - self.v[i];
    return ((Vec2){ e.y, -e.x }).normalize();
}

fn Polygon make_box(Vec2 center, Vec2 half, float angle_deg)
{
    float a = angle_deg * (float)math::PI / 180.0f;
    float c = math::cos(a);
    float s = math::sin(a);
    Vec2[4] local = { { -half.x, -half.y }, { half.x, -half.y }, { half.x, half.y }, { -half.x, half.y } };
    Polygon p = { .count = 4 };
    for (int i = 0; i < 4; i++)
    {
        Vec2 l = local[i];
        p.v[i] = center + (Vec2){ l.x * c - l.y * s, l.x * s + l.y * c };
    }
    return p;
}

fn void project(Polygon* p, Vec2 axis, float* out_min, float* out_max)
{
    // TODO: min и max от dot(v, axis) по всем вершинам.
    *out_min = 0;
    *out_max = 0;
}

fn Vec2 support(Polygon* p, Vec2 dir)
{
    // TODO: вершина с максимальным dot(v, dir).
    //       При равенстве оставляйте ПЕРВУЮ (строгое `>`).
    return p.v[0];
}

int axes_tested;   // для статистики: сколько осей проверено

fn bool sat(Polygon* a, Polygon* b, Contact* out)
{
    // TODO: для каждой нормали ребра A, затем B (poly.edge_normal(i)):
    //         axes_tested++;
    //         спроецировать оба тела, overlap = min(amax, bmax) - max(amin, bmin);
    //         overlap < 0  -> return false (ранний выход);
    //         запомнить ось с наименьшим overlap (строгое `<`).
    //       Потом развернуть нормаль от A к B (по центрам) и заполнить
    //       *out = { normal, depth, support(b, -normal) }.
    return false;
}

fn void report(String what, bool hit, Contact c)
{
    if (!hit) { io::printfn("%-18s separated (axes tested: %d)", what, axes_tested); return; }
    io::printfn("%-18s hit n=(%.3f, %.3f) depth=%.3f point=(%.3f, %.3f)",
                what, c.normal.x + 0.0f, c.normal.y + 0.0f, c.depth, c.point.x + 0.0f, c.point.y + 0.0f);  // + 0.0f убирает «-0.000»
}

fn bool near(float a, float b) => math::abs(a - b) < 1e-4f;

fn void main()
{
    Contact c;

    // 1. Два квадрата, перекрытие 0.5 по x.
    Polygon a = make_box({ 0, 0 }, { 1, 1 }, 0);
    Polygon b = make_box({ 1.5f, 0.2f }, { 1, 1 }, 0);
    bool hit = sat(&a, &b, &c);
    assert(hit && near(c.normal.x, 1) && near(c.normal.y, 0) && near(c.depth, 0.5f), "box vs box");
    report("box vs box", hit, c);

    // 2. Тот же случай, но A и B поменяны: нормаль должна развернуться.
    hit = sat(&b, &a, &c);
    assert(hit && near(c.normal.x, -1) && near(c.depth, 0.5f), "normal must point from A to B");
    report("swapped", hit, c);

    // 3. «Ромб» (квадрат под 45°) сверху на квадрате: входит углом.
    Polygon d = make_box({ 0, 2.2f }, { 1, 1 }, 45);
    hit = sat(&a, &d, &c);
    assert(hit && near(c.normal.y, 1) && near(c.depth, 0.2142f) && near(c.point.y, 2.2f - math::sqrt(2.0f)), "diamond on box");
    report("diamond on box", hit, c);

    // 4. Треугольник у угла коробки: AABB'ы пересекаются, а тела — нет.
    Polygon t = { .count = 3 };
    t.v[0] = { 0.6f, 1.5f };
    t.v[1] = { 1.5f, 0.6f };
    t.v[2] = { 2.0f, 2.0f };
    axes_tested = 0;
    hit = sat(&a, &t, &c);
    assert(!hit, "triangle near the corner is separated by its diagonal edge");
    report("triangle corner", hit, c);
    assert(axes_tested == 5, "early-out: separating axis is the triangle's 1st edge (5th axis overall), got %d", axes_tested);

    // 5. Повёрнутые коробки далеко друг от друга.
    Polygon e = make_box({ 5, 5 }, { 1, 0.5f }, 30);
    axes_tested = 0;
    hit = sat(&a, &e, &c);
    assert(!hit);
    report("far rotated", hit, c);
    io::printn("sat ok");
}
