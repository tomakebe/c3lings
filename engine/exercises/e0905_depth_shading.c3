// =====================================================================
//  e0905 · Z-буфер, барицентрики и освещение по Ламберту
// =====================================================================
//
//  Сначала прочитайте engine/docs/09_rendering.md (разделы «Z-буфер»
//  и «Интерполяция атрибутов и освещение»).
//
//  В e0904 треугольник красился одним цветом. Теперь у вершин есть
//  атрибуты — глубина z и яркость — и их нужно плавно интерполировать
//  по треугольнику. Бонус edge functions: веса w0, w1, w2, которые мы
//  уже посчитали для теста «внутри/снаружи», — это и есть
//  (ненормированные) БАРИЦЕНТРИЧЕСКИЕ КООРДИНАТЫ точки:
//
//      w0 + w1 + w2 == area           (area = edge(a, b, c))
//      attr(p) = (w0 * attr_a + w1 * attr_b + w2 * attr_c) / area
//
//  (w0 — вес вершины a, потому что w0 = edge(b, c, p) — площадь
//  треугольника НАПРОТИВ a. Когда p == a, w0 == area, а w1 == w2 == 0.)
//
//  Z-БУФЕР (Catmull, 1974). Для каждого пикселя храним глубину
//  ближайшего уже нарисованного фрагмента. Новый фрагмент пишется,
//  только если он ближе:
//
//      if (z < depth[i]) { depth[i] = z; color[i] = ...; }
//      else              { rejected++; }
//
//  Перед кадром буфер заполняется «бесконечностью» (DEPTH_CLEAR).
//  Z-буфер делает порядок отрисовки непрозрачной геометрии неважным
//  для РЕЗУЛЬТАТА (важным он остаётся для СКОРОСТИ — отсюда
//  front-to-back в ключах e0901) и корректно рисует даже
//  взаимопроникающие треугольники, с которыми не справится никакая
//  сортировка объектов.
//
//  (Честная перспектива требует интерполировать не z, а 1/w и делить
//  атрибуты на w — perspective-correct interpolation. Здесь у нас
//  экранные вершины без перспективы, так что линейная интерполяция
//  точна.)
//
//  ОСВЕЩЕНИЕ ПО ЛАМБЕРТУ: диффузная яркость пропорциональна косинусу
//  угла между нормалью n и направлением НА свет l:
//
//      I = max(0, dot(n, l))
//
//  Нормали и l здесь — целые вектора длины ~256 (фиксированная точка
//  8.8), так что dot(n, l) / 256 сразу даёт яркость 0..256; зажмите её
//  в 0..255.
//
//    * flat-шейдинг: одна нормаль на треугольник -> одна яркость;
//    * Гуро (Gouraud): яркость считается в вершинах и интерполируется
//      по пикселям — то, что мы и делаем атрибутом `light`;
//    * Фонг (Phong) — интерполируют НОРМАЛЬ и освещают каждый пиксель
//      (так работают все современные пиксельные шейдеры).
//
//  ЗАДАЧА: реализуйте `lambert` и в `draw_triangle` — интерполяцию z и
//  яркости плюс тест/запись глубины (места помечены TODO).
//
import std::io;

const int W = 48;
const int H = 24;
const int SUB = 16;
const int DEPTH_CLEAR = 0x7FFF_FFFF;

struct Vec3i { int x; int y; int z; }

struct Vertex
{
    int x;      // экранные координаты в 1/SUB пикселя
    int y;
    int z;      // глубина: меньше = ближе
    int light;  // яркость 0..255
}

struct Target
{
    int[W * H] depth;
    char[W * H] shade;     // яркость 0..255
    char[W * H] id;        // какой треугольник победил
    int written;
    int rejected;
}

fn void Target.clear(&self)
{
    foreach (&d : self.depth) *d = DEPTH_CLEAR;
    foreach (&s : self.shade) *s = 0;
    foreach (&c : self.id) *c = '.';
    self.written = 0;
    self.rejected = 0;
}

fn int lambert(Vec3i n, Vec3i l)
{
    // TODO: max(0, dot(n, l)) / 256, не больше 255.
    return 0;
}

fn long edge(int ax, int ay, int bx, int by, int px, int py)
    => (long)(bx - ax) * (long)(py - ay) - (long)(by - ay) * (long)(px - ax);

fn bool is_top_left(Vertex a, Vertex b)
    => (b.y == a.y && b.x > a.x) || b.y < a.y;

fn int imin3(int a, int b, int c) => a < b ? (a < c ? a : c) : (b < c ? b : c);
fn int imax3(int a, int b, int c) => a > b ? (a > c ? a : c) : (b > c ? b : c);

fn void draw_triangle(Target* t, Vertex a, Vertex b, Vertex c, char id)
{
    long area = edge(a.x, a.y, b.x, b.y, c.x, c.y);
    if (area == 0) return;
    if (area < 0) { Vertex tmp = b; b = c; c = tmp; area = -area; }

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
            int px = x * SUB + SUB / 2;
            int py = y * SUB + SUB / 2;
            long w0 = edge(b.x, b.y, c.x, c.y, px, py);
            long w1 = edge(c.x, c.y, a.x, a.y, px, py);
            long w2 = edge(a.x, a.y, b.x, b.y, px, py);
            if (w0 + bias0 < 0 || w1 + bias1 < 0 || w2 + bias2 < 0) continue;

            int i = y * W + x;
            // TODO: интерполируйте z и light барицентриками (в long!),
            //       сделайте тест глубины и запишите depth/shade/id,
            //       считая written и rejected.
            t.shade[i] = (char)a.light;
            t.id[i] = id;
            t.written++;
        }
    }
}

// ---------------------------------------------------------------------
// Ниже менять ничего не нужно.

fn uint fnv(char[] data, uint h = 2166136261)
{
    foreach (c : data) { h ^= c; h *= 16777619; }
    return h;
}

fn uint Target.checksum(&self)
{
    uint h = fnv(self.shade[..]);
    h = fnv(self.id[..], h);
    foreach (d : self.depth) h = fnv({ (char)d, (char)(d >> 8), (char)(d >> 16), (char)(d >> 24) }, h);
    return h;
}

fn void Target.print_shade(&self)
{
    String ramp = " .:-=+*#%@";
    for (int y = 0; y < H; y++)
    {
        io::print("  ");
        for (int x = 0; x < W; x++)
        {
            int s = self.shade[y * W + x];
            io::printf("%c", ramp[s * 10 / 256]);
        }
        io::printn();
    }
}

fn Vertex v(int x, int y, int z, int light) => { x * SUB, y * SUB, z, light };

const Vec3i LIGHT = { 0, -110, -231 };      // свет сверху-спереди, |l| ~ 256

fn void draw_scene(Target* t, bool reversed)
{
    // Пол: дальний и тёмный (нормаль почти отвернулась от света).
    int floor = lambert({ 0, 220, -131 }, LIGHT);
    Vertex[3] f1 = { v(0, 0, 9000, floor), v(48, 0, 9000, floor), v(48, 24, 9000, floor) };
    Vertex[3] f2 = { v(0, 0, 9000, floor), v(48, 24, 9000, floor), v(0, 24, 9000, floor) };
    // Два взаимопроникающих треугольника с Гуро-освещением.
    Vertex[3] ta = {
        v(4, 2, 1000, lambert({ 0, -181, -181 }, LIGHT)),
        v(40, 6, 5000, lambert({ 181, 0, -181 }, LIGHT)),
        v(10, 22, 3000, lambert({ -181, 0, -181 }, LIGHT)),
    };
    Vertex[3] tb = {
        v(44, 3, 1500, lambert({ 0, 0, -256 }, LIGHT)),
        v(30, 23, 1500, lambert({ 0, 181, -181 }, LIGHT)),
        v(6, 10, 6000, lambert({ -256, 0, 0 }, LIGHT)),
    };
    if (!reversed)
    {
        draw_triangle(t, f1[0], f1[1], f1[2], 'f');
        draw_triangle(t, f2[0], f2[1], f2[2], 'f');
        draw_triangle(t, ta[0], ta[1], ta[2], 'A');
        draw_triangle(t, tb[0], tb[1], tb[2], 'B');
    }
    else
    {
        draw_triangle(t, tb[0], tb[1], tb[2], 'B');
        draw_triangle(t, ta[0], ta[1], ta[2], 'A');
        draw_triangle(t, f2[0], f2[1], f2[2], 'f');
        draw_triangle(t, f1[0], f1[1], f1[2], 'f');
    }
}

fn void main()
{
    // Ламберт.
    assert(lambert({ 0, 0, -256 }, { 0, 0, -256 }) == 255, "facing the light: full brightness (clamped)");
    assert(lambert({ 0, 0, 256 }, { 0, 0, -256 }) == 0, "facing away: 0, not negative");
    assert(lambert({ 256, 0, 0 }, { 0, 0, -256 }) == 0, "perpendicular: 0");
    assert(lambert({ 181, 0, -181 }, { 0, 0, -256 }) == 181, "45 degrees: ~cos 45");

    Target t;

    // Интерполяция: в вершине атрибут равен вершинному.
    t.clear();
    draw_triangle(&t, v(0, 0, 100, 0), v(32, 0, 100, 0), v(0, 16, 100, 250), 'X');
    assert(t.shade[0] < 20, "near vertex a the light must be close to a.light");
    assert(t.shade[15 * W + 0] > 220, "near vertex c the light must be close to c.light");
    assert(t.depth[5 * W + 5] == 100, "constant z must stay constant");

    // Z-тест: ближний треугольник закрывает дальний в любом порядке.
    t.clear();
    draw_triangle(&t, v(0, 0, 500, 10), v(20, 0, 500, 10), v(0, 20, 500, 10), 'N');
    draw_triangle(&t, v(0, 0, 900, 99), v(20, 0, 900, 99), v(0, 20, 900, 99), 'F');
    assert(t.id[2 * W + 2] == 'N' && t.rejected > 0, "far triangle must be rejected");
    assert(t.written == t.rejected, "everything of F lies behind N");

    // Сцена: результат не зависит от порядка отрисовки.
    t.clear();
    draw_scene(&t, false);
    uint forward = t.checksum();
    int written_fwd = t.written;
    int rejected_fwd = t.rejected;
    t.clear();
    draw_scene(&t, true);
    uint backward = t.checksum();
    io::printfn("scene front-to-back order: written %d, rejected %d", t.written, t.rejected);
    io::printfn("scene back-to-front order: written %d, rejected %d", written_fwd, rejected_fwd);
    assert(forward == backward, "z-buffer result must not depend on draw order");
    assert(t.written < written_fwd, "near-first order writes fewer pixels");

    int a = 0;
    int b = 0;
    foreach (c : t.id) { if (c == 'A') a++; if (c == 'B') b++; }
    io::printfn("visible pixels: A=%d B=%d", a, b);
    t.print_shade();
    io::printfn("checksum %08x", forward);
}
