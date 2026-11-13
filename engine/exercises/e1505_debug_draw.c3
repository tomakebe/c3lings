// =====================================================================
//  e1505 · Debug draw: immediate-mode API с временем жизни
// =====================================================================
//
//  Сначала прочитайте engine/docs/15_profiling_debugging.md
//  (раздел «Debug draw»).
//
//  Debug draw — самый полезный инструмент отладки геймплея и физики:
//  «нарисуй мне луч, по которому ИИ стреляет», «покажи AABB всех тел».
//  Хороший API отвечает нескольким требованиям:
//
//    * immediate mode: вызвать можно ОТКУДА УГОДНО (из физики, ИИ,
//      скрипта), без создания объектов и хендлов:
//          dd.line(x0, y0, x1, y1, '*', PHYSICS);
//    * команды только КОПИРУЮТСЯ в буфер; рисует их рендерер позже,
//      одним проходом (`flush`). Код игры не знает о графическом API;
//    * время жизни: `frames = 1` — только этот кадр, `frames = 60` —
//      повисеть секунду (удобно для одиночных событий: «здесь был удар»);
//    * категории с маской: выключенная категория отбрасывается сразу при
//      вызове, не занимая буфер;
//    * буфер фиксированного размера; переполнение — не падение, а
//      счётчик `dropped` (показывается в оверлее);
//    * ТЕКСТ КОПИРУЕТСЯ внутрь команды. Команда может прожить много
//      кадров, а String, переданный в text(), часто указывает на
//      временный буфер (tformat, стек). Хранить срез — висячий указатель.
//
//  flush(canvas): рисует ВСЕ живые команды в порядке подачи (поздние
//  поверх ранних), затем уменьшает frames_left у каждой и удаляет
//  истёкшие, СОХРАНЯЯ порядок оставшихся (стабильное уплотнение).
//
//  Холст здесь — ASCII-сетка, в настоящем движке — вершинный буфер
//  линий, который рисуется последним проходом поверх сцены.
//
//  ЗАДАЧА: реализуйте `DebugDraw.push`, `DebugDraw.text`,
//  `DebugDraw.render_cmd` (ветки BOX и TEXT) и `DebugDraw.flush` (TODO).
//
import std::io;

const int W = 24;
const int H = 8;

struct Canvas { char[W][H] px; }

fn void Canvas.clear(&self)
{
    foreach (&row : self.px) foreach (&c : *row) *c = '.';
}

fn void Canvas.plot(&self, int x, int y, char c)
{
    if (x < 0 || y < 0 || x >= W || y >= H) return;   // клиппинг
    self.px[y][x] = c;
}

fn void Canvas.line(&self, int x0, int y0, int x1, int y1, char c)
{
    int dx = x1 > x0 ? x1 - x0 : x0 - x1;
    int dy = y1 > y0 ? y0 - y1 : y1 - y0;
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    int err = dx + dy;
    while (true)
    {
        self.plot(x0, y0, c);
        if (x0 == x1 && y0 == y1) break;
        int e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}

fn void Canvas.print(&self)
{
    foreach (&row : self.px) io::printn((String)(*row)[..]);
}

// ------------------------------------------------------------ debug draw
enum DebugCategory : char { GENERAL, PHYSICS, AI, NAV }
enum ShapeKind : char { POINT, LINE, BOX, TEXT }

const int MAX_CMDS = 16;
const int MAX_TEXT = 12;

struct DebugCmd
{
    ShapeKind kind;
    DebugCategory cat;
    int x0, y0, x1, y1;
    char glyph;
    int frames_left;
    char[MAX_TEXT] text;   // копия текста, НЕ срез
    int text_len;
}

struct DebugDraw
{
    DebugCmd[MAX_CMDS] cmds;
    int count;
    int dropped;
    uint enabled_mask;     // бит i = категория с ordinal i включена
}

<*
 Положить команду в буфер. Если категория выключена — просто вернуться
 (не считается dropped). Если буфер полон — dropped++.
*>
fn void DebugDraw.push(&self, DebugCmd cmd)
{
    // TODO
}

fn void DebugDraw.point(&self, int x, int y, char glyph, DebugCategory cat = GENERAL, int frames = 1)
    => self.push({ .kind = POINT, .cat = cat, .x0 = x, .y0 = y, .glyph = glyph, .frames_left = frames });

fn void DebugDraw.line(&self, int x0, int y0, int x1, int y1, char glyph, DebugCategory cat = GENERAL, int frames = 1)
    => self.push({ .kind = LINE, .cat = cat, .x0 = x0, .y0 = y0, .x1 = x1, .y1 = y1, .glyph = glyph, .frames_left = frames });

fn void DebugDraw.box(&self, int x0, int y0, int x1, int y1, char glyph, DebugCategory cat = GENERAL, int frames = 1)
    => self.push({ .kind = BOX, .cat = cat, .x0 = x0, .y0 = y0, .x1 = x1, .y1 = y1, .glyph = glyph, .frames_left = frames });

<* Текст: скопировать не более MAX_TEXT символов внутрь команды. *>
fn void DebugDraw.text(&self, int x, int y, String s, DebugCategory cat = GENERAL, int frames = 1)
{
    // TODO: собрать DebugCmd с копией текста и вызвать push
}

fn void DebugDraw.render_cmd(&self, Canvas* c, DebugCmd* cmd)
{
    switch (cmd.kind)
    {
        case POINT:
            c.plot(cmd.x0, cmd.y0, cmd.glyph);
        case LINE:
            c.line(cmd.x0, cmd.y0, cmd.x1, cmd.y1, cmd.glyph);
        case BOX:
            // контур прямоугольника с углами (x0,y0) и (x1,y1)
            // TODO
            break;
        case TEXT:
            // символы слева направо начиная с (x0,y0), с клиппингом
            // TODO
            break;
    }
}

<*
 Нарисовать все команды по порядку, затем frames_left-- и удалить
 истёкшие (frames_left == 0), сохранив порядок остальных.
*>
fn void DebugDraw.flush(&self, Canvas* c)
{
    // TODO
}

// ------------------------------------------------------------ "game"
fn void main()
{
    DebugDraw dd = { .enabled_mask = 0b1011 };   // всё, кроме AI
    Canvas canvas;

    char[16] scratch;
    for (int frame = 0; frame < 4; frame++)
    {
        if (frame == 0)
        {
            dd.box(1, 1, 8, 5, '#', PHYSICS, frames: 3);      // AABB висит 3 кадра
            dd.line(0, 7, 23, 0, 'a', AI);                     // AI выключен
            scratch[:3] = "HIT"[..];
            dd.text(9, 3, (String)scratch[:3], frames: 2);
            scratch[:3] = "???"[..];                             // буфер переписан!
            dd.text(20, 6, "clipped-text");                    // вылезет за край
        }
        dd.line(12, 6, 12 + frame * 3, 1, '*');                // каждый кадр заново
        dd.point(frame, 0, '@', NAV);

        canvas.clear();
        dd.flush(&canvas);
        io::printfn("frame %d (alive after flush: %d)", frame, dd.count);
        canvas.print();
        if (frame == 0) assert(dd.count == 2, "box + HIT survive frame 0");
        if (frame == 1) assert((String)canvas.px[3][9:3] == "HIT", "text must be copied into the command");
        if (frame == 2) assert(dd.count == 0);
    }
    assert(canvas.px[1][1] == '.', "box expired after 3 frames");
    assert(dd.dropped == 0);

    // переполнение
    for (int i = 0; i < 20; i++) dd.point(i, 0, 'x');
    for (int i = 0; i < 5; i++) dd.point(i, 1, 'y', AI);
    assert(dd.count == MAX_CMDS && dd.dropped == 4, "4 dropped, AI ignored");
    io::printfn("overflow: count=%d dropped=%d", dd.count, dd.dropped);
    io::printn("debug draw ok");
}
