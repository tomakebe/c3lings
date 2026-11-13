// ---------------------------------------------------------------------
//  mini::render — ASCII-«растеризатор» в кадровый буфер (глава 09).
//
//  Кадровый буфер — W*H символов, по одному на «пиксель». Растеризация
//  та же, что для настоящих пикселей: Брезенхем для линий, алгоритм
//  средней точки для окружностей, отсечение по границам. Контрольная
//  сумма буфера — лучший автотест рендера (golden image).
// ---------------------------------------------------------------------
module mini::render;
import mini::core, mini::ecs, std::io;

const int W = 64;
const int H = 24;

struct Framebuffer
{
    char[W * H] px;
}

fn void Framebuffer.clear(&self, char c = ' ')
{
    self.px[..] = c;
}

fn void Framebuffer.put(&self, int x, int y, char c)
{
    if (x < 0 || y < 0 || x >= W || y >= H) return;   // отсечение
    self.px[y * W + x] = c;
}

fn char Framebuffer.at(&self, int x, int y) => self.px[y * W + x];

<* Линия Брезенхема от (x0,y0) до (x1,y1) включительно, во всех октантах. *>
fn void Framebuffer.line(&self, int x0, int y0, int x1, int y1, char c)
{
    int dx = x1 > x0 ? x1 - x0 : x0 - x1;
    int dy = y1 > y0 ? y0 - y1 : y1 - y0;     // -|dy|
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    int err = dx + dy;
    while (true)
    {
        self.put(x0, y0, c);
        if (x0 == x1 && y0 == y1) break;
        int e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}

<* Окружность радиуса r (алгоритм средней точки, 8-кратная симметрия). *>
fn void Framebuffer.circle(&self, int cx, int cy, int r, char c)
{
    int x = r;
    int y = 0;
    int err = 1 - r;
    while (x >= y)
    {
        self.put(cx + x, cy + y, c);
        self.put(cx + y, cy + x, c);
        self.put(cx - y, cy + x, c);
        self.put(cx - x, cy + y, c);
        self.put(cx - x, cy - y, c);
        self.put(cx - y, cy - x, c);
        self.put(cx + y, cy - x, c);
        self.put(cx + x, cy - y, c);
        y++;
        if (err < 0)
        {
            err += 2 * y + 1;
        }
        else
        {
            x--;
            err += 2 * (y - x) + 1;
        }
    }
}

fn uint Framebuffer.checksum(&self) => core::fnv_bytes(core::FNV_BASIS, &self.px);

fn void Framebuffer.print(&self)
{
    io::printf("+");
    for (int x = 0; x < W; x++) io::printf("-");
    io::printn("+");
    for (int y = 0; y < H; y++)
    {
        io::printf("|%s|\n", (String)self.px[y * W:W]);
    }
    io::printf("+");
    for (int x = 0; x < W; x++) io::printf("-");
    io::printn("+");
}

// Единичные векторы для 32 направлений, *256 (cos, sin).
const int[2][32] DIRS = {
    {256, 0}, {251, 50}, {237, 98}, {213, 142}, {181, 181}, {142, 213}, {98, 237}, {50, 251},
    {0, 256}, {-50, 251}, {-98, 237}, {-142, 213}, {-181, 181}, {-213, 142}, {-237, 98}, {-251, 50},
    {-256, 0}, {-251, -50}, {-237, -98}, {-213, -142}, {-181, -181}, {-142, -213}, {-98, -237}, {-50, -251},
    {0, -256}, {50, -251}, {98, -237}, {142, -213}, {181, -181}, {213, -142}, {237, -98}, {251, -50},
};

<* Нарисовать все сущности со Sprite. Возвращает число нарисованных. *>
fn int draw_world(Framebuffer* fb, World* w)
{
    int drawn = 0;
    for (uint i = 0; i < w.sprites.len; i++)
    {
        uint e = w.sprites.dense[i];
        Transform* t = w.transforms.get(e);
        if (!t) continue;
        Sprite s = w.sprites.data[i];
        int x = t.x / core::FX;
        int y = t.y / core::FX;
        if (s.size > 0)
        {
            fb.circle(x, y, s.size, s.glyph);
        }
        else if (s.glyph == 'A')
        {
            // корабль: линия-«нос» по направлению
            int[2] d = DIRS[t.angle & 31];
            fb.line(x, y, x + d[0] * 3 / 256, y + d[1] * 3 / 256, '*');
            fb.put(x, y, 'A');
        }
        else
        {
            fb.put(x, y, s.glyph);
        }
        drawn++;
    }
    return drawn;
}
