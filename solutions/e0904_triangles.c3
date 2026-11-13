// =====================================================================
//  e0904 · Треугольники: edge functions и top-left rule
// =====================================================================
//
//  Сначала прочитайте engine/docs/09_rendering.md (раздел
//  «Растеризация треугольника»).
//
//  Все современные GPU растеризуют треугольники через «функции рёбер»
//  (Pineda, 1988). Для ребра a->b и точки p:
//
//      edge(a, b, p) = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
//
//  Это z-компонента векторного произведения (b - a) x (p - a): знак
//  говорит, по какую сторону от прямой ab лежит p, а модуль равен
//  удвоенной площади треугольника (a, b, p). Точка внутри треугольника
//  abc, если она по «внутреннюю» сторону от всех трёх рёбер:
//
//      w0 = edge(b, c, p)   w1 = edge(c, a, p)   w2 = edge(a, b, p)
//      inside  <=>  w0 >= 0 && w1 >= 0 && w2 >= 0   (для нужной ориентации)
//
//  Алгоритм: ограничивающий прямоугольник (bounding box) треугольника,
//  обрезанный экраном, и для каждого пикселя в нём — тест центра
//  пикселя (x + 0.5, y + 0.5). Никаких «сканлайнов», никаких особых
//  случаев — поэтому этот подход и параллелится на тысячи ядер.
//
//  ФИКСИРОВАННАЯ ТОЧКА. GPU работают с подпиксельной точностью в целых
//  числах (обычно 8 бит дробной части). У нас — 4 бита: координата
//  хранится умноженной на 16, центр пикселя x — это x*16 + 8. Целые
//  числа дают ТОЧНЫЙ и детерминированный результат.
//
//  ОРИЕНТАЦИЯ. Ось y экрана смотрит вниз. Если edge(a, b, c) < 0,
//  треугольник «перевёрнут» — поменяйте b и c местами (здесь мы рисуем
//  обе стороны; отсечение задних граней — в следующих упражнениях).
//  edge(a, b, c) == 0 — вырожденный треугольник, рисовать нечего.
//
//  TOP-LEFT RULE. Если центр пикселя лежит РОВНО на общем ребре двух
//  треугольников (w == 0), его нельзя отдать обоим (двойное смешивание,
//  мерцание) и нельзя не отдать никому (дыра). Правило D3D/OpenGL:
//  пиксель на ребре принадлежит треугольнику, только если ребро
//  «верхнее» или «левое». При нашей ориентации (y вниз, edge(a,b,c) > 0):
//
//      верхнее: dy == 0 && dx > 0    (горизонтальное, внутренность ниже)
//      левое:   dy < 0
//                     где dx = b.x - a.x, dy = b.y - a.y для ребра a->b
//
//  Реализуется смещением: bias = top_left ? 0 : -1, и тест
//  `w + bias >= 0`. Для целых чисел это ровно «w > 0 для не-top-left».
//
//  ЗАДАЧА: реализуйте `edge`, `is_top_left` и `fill_triangle`.
//  main() разрежет прямоугольник и «веер» на треугольники и проверит,
//  что каждый пиксель закрашен ровно один раз — без дыр и без overdraw.
//
import std::io;

const int W = 40;
const int H = 20;
const int SUB = 16;          // 4 бита подпикселя

struct Point { int x; int y; }   // в единицах 1/SUB пикселя

struct Target
{
    char[W * H] color;
    int[W * H] hits;     // сколько треугольников закрасили пиксель
}

fn void Target.clear(&self)
{
    foreach (&c : self.color) *c = '.';
    foreach (&h : self.hits) *h = 0;
}

fn Point px(int x, int y) => { x * SUB, y * SUB };

fn long edge(Point a, Point b, Point p)
{
    // TODO
    return (long)(b.x - a.x) * (long)(p.y - a.y) - (long)(b.y - a.y) * (long)(p.x - a.x);
}

fn bool is_top_left(Point a, Point b)
{
    // TODO
    int dx = b.x - a.x;
    int dy = b.y - a.y;
    return (dy == 0 && dx > 0) || dy < 0;
}

fn int imin3(int a, int b, int c) => a < b ? (a < c ? a : c) : (b < c ? b : c);
fn int imax3(int a, int b, int c) => a > b ? (a > c ? a : c) : (b > c ? b : c);

fn void fill_triangle(Target* t, Point a, Point b, Point c, char color)
{
    // TODO:
    //  1) площадь edge(a, b, c): 0 -> выйти, < 0 -> поменять b и c;
    //  2) bias для трёх рёбер (b->c, c->a, a->b) по top-left rule;
    //  3) bounding box в пикселях, обрезанный экраном;
    //  4) для каждого центра пикселя: если все w + bias >= 0 —
    //     t.color[...] = color; t.hits[...]++.
    long area = edge(a, b, c);
    if (area == 0) return;
    if (area < 0) { Point tmp = b; b = c; c = tmp; }

    long bias0 = is_top_left(b, c) ? 0 : -1;
    long bias1 = is_top_left(c, a) ? 0 : -1;
    long bias2 = is_top_left(a, b) ? 0 : -1;

    int min_x = imin3(a.x, b.x, c.x) / SUB;
    int min_y = imin3(a.y, b.y, c.y) / SUB;
    int max_x = imax3(a.x, b.x, c.x) / SUB;
    int max_y = imax3(a.y, b.y, c.y) / SUB;
    if (min_x < 0) min_x = 0;
    if (min_y < 0) min_y = 0;
    if (max_x > W - 1) max_x = W - 1;
    if (max_y > H - 1) max_y = H - 1;

    for (int y = min_y; y <= max_y; y++)
    {
        for (int x = min_x; x <= max_x; x++)
        {
            Point p = { x * SUB + SUB / 2, y * SUB + SUB / 2 };
            long w0 = edge(b, c, p) + bias0;
            long w1 = edge(c, a, p) + bias1;
            long w2 = edge(a, b, p) + bias2;
            if (w0 >= 0 && w1 >= 0 && w2 >= 0)
            {
                t.color[y * W + x] = color;
                t.hits[y * W + x]++;
            }
        }
    }
}

// ---------------------------------------------------------------------
// Ниже менять ничего не нужно.

fn void Target.print(&self)
{
    for (int y = 0; y < H; y++)
    {
        io::print("  ");
        for (int x = 0; x < W; x++) io::printf("%c", self.color[y * W + x]);
        io::printn();
    }
}

fn uint Target.checksum(&self)
{
    uint h = 2166136261;
    foreach (c : self.color) { h ^= c; h *= 16777619; }
    return h;
}

fn int Target.count(&self, int n)
{
    int k = 0;
    foreach (h : self.hits) if (h == n) k++;
    return k;
}

fn void main()
{
    Target t;

    // Базовые свойства edge function.
    assert(edge(px(0, 0), px(10, 0), px(0, 10)) > 0, "y-down: (0,0)->(10,0)->(0,10) is positive");
    assert(edge(px(0, 0), px(10, 0), px(5, 0)) == 0, "point on the line");
    assert(edge(px(0, 0), px(4, 0), px(0, 4)) == 16 * SUB * SUB, "|edge| = 2 * area");
    assert(is_top_left(px(0, 0), px(5, 0)), "horizontal edge going right is top");
    assert(!is_top_left(px(5, 9), px(0, 9)), "horizontal edge going left is bottom");
    assert(is_top_left(px(0, 9), px(0, 0)), "edge going up is left");
    assert(!is_top_left(px(9, 0), px(9, 9)), "edge going down is right");

    // 1) Прямоугольник 10x6 из двух треугольников с общей диагональю.
    t.clear();
    fill_triangle(&t, px(2, 2), px(12, 2), px(12, 8), 'A');
    fill_triangle(&t, px(2, 2), px(12, 8), px(2, 8), 'B');
    assert(t.count(2) == 0, "quad: diagonal pixels drawn twice");
    assert(t.count(1) == 60, "quad: expected 60 pixels, got %d", t.count(1));
    io::printfn("quad: %d pixels, overdraw %d", t.count(1), t.count(2));

    // 2) Ориентация не важна: тот же треугольник «задом наперёд».
    t.clear();
    fill_triangle(&t, px(2, 2), px(12, 8), px(12, 2), 'A');
    int cw = t.count(1);
    t.clear();
    fill_triangle(&t, px(2, 2), px(12, 2), px(12, 8), 'A');
    assert(cw == t.count(1) && cw > 0, "winding must not matter");

    // 3) Вырожденный треугольник ничего не рисует.
    t.clear();
    fill_triangle(&t, px(1, 1), px(5, 5), px(9, 9), 'X');
    assert(t.count(1) == 0, "degenerate triangle drew pixels");

    // 4) Веер из 8 треугольников вокруг центра + выход за экран.
    t.clear();
    Point center = { 20 * SUB + 3, 10 * SUB + 5 };          // нецелый центр
    Point[8] ring = {
        px(17, -30), px(60, -30), px(60, 7), px(60, 50),
        px(23, 50), px(-20, 50), px(-20, 13), px(-20, -30),
    };
    for (int i = 0; i < 8; i++)
    {
        fill_triangle(&t, center, ring[i], ring[(i + 1) % 8], (char)('a' + i));
    }
    assert(t.count(2) == 0, "fan: overdraw on shared edges");
    assert(t.count(3) == 0);
    io::printfn("fan: %d pixels, overdraw %d, holes %d", t.count(1), t.count(2), t.count(0));
    assert(t.count(0) == 0, "fan covers the whole screen, there must be no holes");
    t.print();
    io::printfn("checksum %08x", t.checksum());
}
