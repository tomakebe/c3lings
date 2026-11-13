// =====================================================================
//  e0903 · Фреймбуфер и линии Брезенхэма
// =====================================================================
//
//  Сначала прочитайте engine/docs/09_rendering.md (раздел
//  «Софтверный растеризатор: фреймбуфер и линии»).
//
//  Начинаем свой маленький растеризатор. Фреймбуфер — это просто
//  плоский массив пикселей w*h, строка за строкой (row-major):
//
//      pixel(x, y) = px[y * w + x]        // y растёт ВНИЗ, как на экране
//
//  Здесь «пиксель» — один символ ASCII, чтобы картинку было видно
//  прямо в терминале.
//
//  Линия Брезенхэма (1962, плоттеры IBM) рисует отрезок между двумя
//  целыми точками только целочисленной арифметикой. Идея: идём по
//  «главной» оси (где |delta| больше) по одному пикселю, а по второй оси
//  копим ошибку и делаем шаг, когда она перевалила за половину пикселя.
//
//  Компактный вариант для всех восьми октантов (Alois Zingl):
//
//      dx =  |x1 - x0|, sx = x0 < x1 ? 1 : -1
//      dy = -|y1 - y0|, sy = y0 < y1 ? 1 : -1
//      err = dx + dy
//      loop:
//          plot(x0, y0)
//          if (x0 == x1 && y0 == y1) break
//          e2 = 2 * err
//          if (e2 >= dy) { err += dy; x0 += sx; }
//          if (e2 <= dx) { err += dx; y0 += sy; }
//
//  Свойства, которые проверит main():
//    * оба конца отрезка закрашены;
//    * пикселей ровно max(|dx|, |dy|) + 1 (ни одного лишнего);
//    * по главной оси на каждую координату — ровно один пиксель;
//    * линия 8-связна (соседние пиксели касаются хотя бы углом).
//
//  Отсечение (clipping): точки за пределами экрана просто не пишутся
//  (`set` проверяет границы). В настоящем растеризаторе отрезок
//  сначала обрезают (Cohen–Sutherland, Liang–Barsky), чтобы не идти
//  по миллиону невидимых пикселей.
//
//  ЗАДАЧА: реализуйте `Canvas.set` (с проверкой границ) и
//  `Canvas.line` для всех октантов.
//
import std::io;

const int W = 48;
const int H = 20;

struct Canvas
{
    char[W * H] px;
    int plotted;          // сколько раз вызывали set() внутри экрана
}

fn void Canvas.clear(&self, char c)
{
    foreach (&p : self.px) *p = c;
    self.plotted = 0;
}

fn char Canvas.get(&self, int x, int y) => self.px[y * W + x];

fn void Canvas.set(&self, int x, int y, char c)
{
    // TODO: пишите только если (x, y) внутри [0, W) x [0, H); считайте plotted.
    self.px[y * W + x] = c;
}

fn void Canvas.line(&self, int x0, int y0, int x1, int y1, char c)
{
    // TODO: Брезенхэм для всех восьми октантов.
    self.set(x0, y0, c);
    self.set(x1, y1, c);
}

// ---------------------------------------------------------------------
// Ниже менять ничего не нужно.

fn void Canvas.print(&self)
{
    io::printn("+------------------------------------------------+");
    for (int y = 0; y < H; y++)
    {
        io::print("|");
        for (int x = 0; x < W; x++) io::printf("%c", self.get(x, y));
        io::printn("|");
    }
    io::printn("+------------------------------------------------+");
}

fn int iabs(int v) => v < 0 ? -v : v;
fn int imax(int a, int b) => a > b ? a : b;

fn void check_line(Canvas* cv, int x0, int y0, int x1, int y1)
{
    cv.clear('.');
    cv.line(x0, y0, x1, y1, '#');
    int dx = iabs(x1 - x0);
    int dy = iabs(y1 - y0);
    assert(cv.get(x0, y0) == '#', "start point missing");
    assert(cv.get(x1, y1) == '#', "end point missing");
    assert(cv.plotted == imax(dx, dy) + 1, "line (%d,%d)-(%d,%d): %d pixels, expected %d",
           x0, y0, x1, y1, cv.plotted, imax(dx, dy) + 1);
    // Один пиксель на каждую координату главной оси.
    if (dx >= dy)
    {
        for (int x = x0 < x1 ? x0 : x1; x <= (x0 < x1 ? x1 : x0); x++)
        {
            int n = 0;
            for (int y = 0; y < H; y++) if (cv.get(x, y) == '#') n++;
            assert(n == 1, "column %d has %d pixels", x, n);
        }
    }
    else
    {
        for (int y = y0 < y1 ? y0 : y1; y <= (y0 < y1 ? y1 : y0); y++)
        {
            int n = 0;
            for (int x = 0; x < W; x++) if (cv.get(x, y) == '#') n++;
            assert(n == 1, "row %d has %d pixels", y, n);
        }
    }
    // 8-связность: у каждого пикселя, кроме концов, хотя бы 2 соседа.
    for (int y = 0; y < H; y++)
    {
        for (int x = 0; x < W; x++)
        {
            if (cv.get(x, y) != '#') continue;
            if ((x == x0 && y == y0) || (x == x1 && y == y1)) continue;
            int nb = 0;
            for (int oy = -1; oy <= 1; oy++)
            {
                for (int ox = -1; ox <= 1; ox++)
                {
                    if (ox == 0 && oy == 0) continue;
                    int nx = x + ox;
                    int ny = y + oy;
                    if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
                    if (cv.get(nx, ny) == '#') nb++;
                }
            }
            assert(nb >= 2, "line has a gap near (%d,%d)", x, y);
        }
    }
}

fn void main()
{
    Canvas cv;

    // Границы.
    cv.clear('.');
    cv.set(-1, 0, '#');
    cv.set(0, -1, '#');
    cv.set(W, 0, '#');
    cv.set(0, H, '#');
    assert(cv.plotted == 0, "out-of-bounds writes must be ignored");
    cv.set(W - 1, H - 1, '#');
    assert(cv.plotted == 1 && cv.get(W - 1, H - 1) == '#');

    // Все восемь октантов, вырожденные и осевые случаи.
    int cx = 24;
    int cy = 10;
    int[2][] ends = {
        { 40, 13 }, { 27, 19 }, { 21, 19 }, { 8, 13 },
        { 8, 7 },   { 21, 1 },  { 27, 1 },  { 40, 7 },
        { 40, 10 }, { 8, 10 },  { 24, 0 },  { 24, 19 },
        { 33, 19 }, { 15, 1 },  { 24, 10 },
    };
    foreach (e : ends) check_line(&cv, cx, cy, e[0], e[1]);
    io::printfn("%d lines checked: endpoints, pixel count, one per major step, no gaps", ends.len);

    // Линия, уходящая за экран, не должна падать.
    cv.clear('.');
    cv.line(-10, -5, 60, 30, '#');
    io::printfn("clipped line wrote %d pixels", cv.plotted);
    assert(cv.plotted == 39);

    // Картинка: звезда из линий и рамка.
    cv.clear(' ');
    cv.line(0, 0, W - 1, 0, '-');
    cv.line(0, H - 1, W - 1, H - 1, '-');
    cv.line(0, 0, 0, H - 1, '|');
    cv.line(W - 1, 0, W - 1, H - 1, '|');
    foreach (i, e : ends[:8])
    {
        cv.line(cx, cy, e[0], e[1], (char)('a' + i));
    }
    cv.set(cx, cy, '@');
    cv.print();
}
