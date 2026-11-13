// =====================================================================
//  e0906 · Софтверный рендерер: от команд до картинки
// =====================================================================
//
//  Сначала прочитайте engine/docs/09_rendering.md целиком — это
//  упражнение собирает всю главу.
//
//  Мы строим крошечный, но архитектурно честный рендерер:
//
//    ФРОНТЕНД                      БЭКЕНД ("GPU")
//    -------------------------     -------------------------------------
//    обход объектов сцены          для каждой команды по порядку ключей:
//    ключ = материал | глубина       bind материала (если сменился)
//    запись DrawCmd в буфер          вершинная стадия: rotate+translate,
//    radix/insertion sort ключей       перспективная проекция
//                                    сборка треугольников, отсечение
//                                      задних граней (backface culling)
//                                    flat-освещение по Ламберту
//                                    растеризация + z-буфер (из e0905)
//                                    -> RGB-фреймбуфер -> файл .ppm
//
//  Вся математика — ЦЕЛОЧИСЛЕННАЯ (фиксированная точка), чтобы картинка
//  была бит-в-бит одинаковой на любой машине и её можно было проверить
//  контрольной суммой:
//
//    * мировые единицы: 256 = 1.0 метр;
//    * синусы/косинусы: таблица SIN с шагом 15 градусов, 4096 = 1.0;
//    * экранные координаты: 1/16 пикселя (SUB), как в e0904.
//
//  ВЕРШИННАЯ СТАДИЯ. Объект поворачивается (yaw вокруг Y, затем pitch
//  вокруг X), масштабируется и переносится в пространство камеры.
//  Камера в начале координат смотрит вдоль +Z, ось Y — вверх. Затем
//  перспективная проекция — деление на глубину:
//
//      sx = W*SUB/2 + x * FOCAL * SUB / z
//      sy = H*SUB/2 - y * FOCAL * SUB / z      (экранный y смотрит вниз)
//
//  В z-буфер идёт НЕ z, а 1/z (у нас: INV_Z_ONE / z). Дело в том, что
//  после перспективного деления z меняется вдоль треугольника на
//  экране НЕлинейно, а 1/z — линейно, поэтому интерполировать
//  барицентриками можно только его (так же устроен z/w у GPU).
//  Больше 1/z = ближе, поэтому тест глубины — `>`, а очистка — нулём.
//
//  BACKFACE CULLING. У замкнутого меша задние грани всегда закрыты
//  передними, так что их выгодно выбросить ДО растеризации — это ~50%
//  треугольников. Признак — знак площади на экране. Вершины граней
//  записаны против часовой стрелки, если смотреть на грань снаружи
//  (в правой системе координат). Наша камера — левая система (z от
//  камеры), а экранный y смотрит вниз; два «зеркала» дают в итоге:
//  лицевая грань после проекции имеет edge(a, b, c) > 0, задняя — < 0.
//  Нулевая площадь (грань ребром к камере) тоже отбрасывается.
//
//  FLAT-ОСВЕЩЕНИЕ. Нормаль грани = (b - a) x (c - a) в пространстве
//  камеры, нормированная до длины 256. Яркость = AMBIENT + lambert;
//  цвет пикселя = base * яркость / 256 (с зажимом в 255).
//
//  PPM (P6) — самый простой формат картинки: заголовок
//  "P6\n<w> <h>\n255\n" и затем w*h*3 байт RGB построчно. Его открывают
//  GIMP, feh, большинство просмотрщиков. Файл ляжет в рабочий каталог
//  (.build/e0906.ppm) — откройте и посмотрите!
//
//  ЗАДАЧА (места помечены TODO):
//    1) `to_view` и `project` — вершинная стадия;
//    2) в `draw_mesh` — backface culling и flat-освещение;
//    3) `write_ppm` — сохранить фреймбуфер в файл.
//
import std::io, std::io::file;

const int W = 64;
const int H = 40;
const int SUB = 16;
const int FOCAL = 48;               // фокусное расстояние в пикселях
const int AMBIENT = 72;
const int DEPTH_CLEAR = 0;          // 1/z = 0 — бесконечно далеко
const int INV_Z_ONE = 1 << 30;

const int[24] SIN = { 0, 1060, 2048, 2896, 3547, 3956, 4096, 3956, 3547, 2896, 2048, 1060,
                      0, -1060, -2048, -2896, -3547, -3956, -4096, -3956, -3547, -2896, -2048, -1060 };

fn int isin(int step) => SIN[((step % 24) + 24) % 24];
fn int icos(int step) => isin(step + 6);

struct Vec3i { int x; int y; int z; }
struct Color { char r; char g; char b; }

// ------------------------------------------------------------ данные сцены

struct Mesh
{
    Vec3i[] verts;
    int[] tris;          // по 3 индекса на треугольник
}

// Куб со стороной 2 (±256). Порядок вершин граней: против часовой
// стрелки, если смотреть снаружи (правая система: x вправо, y вверх,
// z НА зрителя). Наша камера смотрит вдоль +z, так что «лицом» к ней
// повёрнуты грани с нормалью -z.
const Vec3i[8] CUBE_VERTS = {
    { -256, -256, -256 }, { 256, -256, -256 }, { 256, 256, -256 }, { -256, 256, -256 },
    { -256, -256,  256 }, { 256, -256,  256 }, { 256, 256,  256 }, { -256, 256,  256 },
};
const int[36] CUBE_TRIS = {
    0, 2, 1,  0, 3, 2,      // -z
    4, 5, 6,  4, 6, 7,      // +z
    0, 1, 5,  0, 5, 4,      // -y
    3, 6, 2,  3, 7, 6,      // +y
    0, 4, 7,  0, 7, 3,      // -x
    1, 2, 6,  1, 6, 5,      // +x
};
// Пол: квадрат в плоскости y = 0 нормалью вверх.
const Vec3i[4] FLOOR_VERTS = { { -256, 0, -256 }, { 256, 0, -256 }, { 256, 0, 256 }, { -256, 0, 256 } };
const int[6] FLOOR_TRIS = { 0, 2, 1, 0, 3, 2 };

const Color[4] MATERIALS = { { 90, 90, 100 }, { 230, 70, 60 }, { 80, 200, 90 }, { 70, 110, 240 } };

struct Object
{
    String name;
    Mesh* mesh;
    ushort material;
    int yaw;          // шаги по 15 градусов
    int pitch;
    int scale;        // 256 = 1.0
    Vec3i pos;        // в пространстве камеры
}

// ------------------------------------------------------------ вершинная стадия

<*
 Поворот (сначала yaw вокруг Y, потом pitch вокруг X), масштаб, перенос.
 Результат — в пространстве камеры, единицы 256 = 1.0.
*>
fn Vec3i to_view(Vec3i v, Object* o)
{
    // TODO:
    //   yaw:   x1 =  x*cos + z*sin;  z1 = -x*sin + z*cos;  y1 = y
    //   pitch: y2 =  y1*cos - z1*sin; z2 = y1*sin + z1*cos; x2 = x1
    //   (каждое произведение с SIN/COS делите на 4096 — сдвиг >> 12 — ПОСЛЕ сложения)
    //   затем * scale / 256 и + pos.
    int cy = icos(o.yaw);
    int sy = isin(o.yaw);
    int cp = icos(o.pitch);
    int sp = isin(o.pitch);
    int x1 = (v.x * cy + v.z * sy) >> 12;
    int z1 = (-v.x * sy + v.z * cy) >> 12;
    int y1 = v.y;
    int y2 = (y1 * cp - z1 * sp) >> 12;
    int z2 = (y1 * sp + z1 * cp) >> 12;
    int x2 = x1;
    return {
        x2 * o.scale / 256 + o.pos.x,
        y2 * o.scale / 256 + o.pos.y,
        z2 * o.scale / 256 + o.pos.z,
    };
}

struct ScreenVert
{
    int x;     // в 1/SUB пикселя
    int y;
    int inv_z; // INV_Z_ONE / view-space z — для z-буфера
}

fn ScreenVert project(Vec3i v)
{
    // TODO: перспектива, см. шапку. Считайте в long: x * FOCAL * SUB может быть большим.
    //       Третья компонента — INV_Z_ONE / v.z.
    assert(v.z > 0, "vertex behind the camera: near-plane clipping is not implemented");
    long sx = (long)W * SUB / 2 + (long)v.x * FOCAL * SUB / v.z;
    long sy = (long)H * SUB / 2 - (long)v.y * FOCAL * SUB / v.z;
    return { (int)sx, (int)sy, INV_Z_ONE / v.z };
}

// ------------------------------------------------------------ растеризатор (из e0905)

struct Frame
{
    Color[W * H] color;
    int[W * H] depth;
    int pixels_written;
    int depth_rejected;
    int tris_in;
    int tris_culled;
    int tris_drawn;
    int material_binds;
}

fn void Frame.clear(&self, Color c)
{
    foreach (&p : self.color) *p = c;
    foreach (&d : self.depth) *d = DEPTH_CLEAR;
}

fn long edge(ScreenVert a, ScreenVert b, ScreenVert p)
    => (long)(b.x - a.x) * (long)(p.y - a.y) - (long)(b.y - a.y) * (long)(p.x - a.x);

fn bool is_top_left(ScreenVert a, ScreenVert b) => (b.y == a.y && b.x > a.x) || b.y < a.y;

fn int imin3(int a, int b, int c) => a < b ? (a < c ? a : c) : (b < c ? b : c);
fn int imax3(int a, int b, int c) => a > b ? (a > c ? a : c) : (b > c ? b : c);

fn void Frame.raster(&self, ScreenVert a, ScreenVert b, ScreenVert c, Color col)
{
    long area = edge(a, b, c);
    if (area == 0) return;
    if (area < 0) { ScreenVert t = b; b = c; c = t; area = -area; }
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
            ScreenVert p = { x * SUB + SUB / 2, y * SUB + SUB / 2, 0 };
            long w0 = edge(b, c, p);
            long w1 = edge(c, a, p);
            long w2 = edge(a, b, p);
            if (w0 + bias0 < 0 || w1 + bias1 < 0 || w2 + bias2 < 0) continue;
            int z = (int)((w0 * a.inv_z + w1 * b.inv_z + w2 * c.inv_z) / area);
            int i = y * W + x;
            if (z > self.depth[i])
            {
                self.depth[i] = z;
                self.color[i] = col;
                self.pixels_written++;
            }
            else
            {
                self.depth_rejected++;
            }
        }
    }
}

// ------------------------------------------------------------ освещение

const Vec3i LIGHT = { -96, 160, -184 };   // направление НА свет, |l| ~ 256

fn long isqrt(long n)
{
    if (n <= 0) return 0;
    long x = n;
    long y = (x + 1) / 2;
    while (y < x) { x = y; y = (x + n / x) / 2; }
    return x;
}

fn Vec3i face_normal(Vec3i a, Vec3i b, Vec3i c)
{
    long ux = (long)b.x - a.x;
    long uy = (long)b.y - a.y;
    long uz = (long)b.z - a.z;
    long vx = (long)c.x - a.x;
    long vy = (long)c.y - a.y;
    long vz = (long)c.z - a.z;
    long nx = uy * vz - uz * vy;
    long ny = uz * vx - ux * vz;
    long nz = ux * vy - uy * vx;
    long len = isqrt(nx * nx + ny * ny + nz * nz);
    if (len == 0) return { 0, 0, 0 };
    return { (int)(nx * 256 / len), (int)(ny * 256 / len), (int)(nz * 256 / len) };
}

fn char scale_channel(char base, int brightness)
{
    int v = base * brightness / 256;
    return (char)(v > 255 ? 255 : v);
}

// ------------------------------------------------------------ бэкенд

fn void draw_mesh(Frame* f, Object* o)
{
    Mesh* m = o.mesh;
    Color base = MATERIALS[o.material];
    for (usz t = 0; t + 2 < m.tris.len; t += 3)
    {
        f.tris_in++;
        Vec3i va = to_view(m.verts[m.tris[t]], o);
        Vec3i vb = to_view(m.verts[m.tris[t + 1]], o);
        Vec3i vc = to_view(m.verts[m.tris[t + 2]], o);
        ScreenVert a = project(va);
        ScreenVert b = project(vb);
        ScreenVert c = project(vc);

        // TODO: backface culling — если edge(a, b, c) <= 0, это задняя
        //       (или ребром повёрнутая) грань: tris_culled++ и дальше.
        if (edge(a, b, c) <= 0)
        {
            f.tris_culled++;
            continue;
        }

        // TODO: flat-освещение: нормаль грани в пространстве камеры,
        //       brightness = AMBIENT + max(0, dot(n, LIGHT)) / 256,
        //       цвет = base * brightness / 256 по каждому каналу.
        Vec3i n = face_normal(va, vb, vc);
        int d = n.x * LIGHT.x + n.y * LIGHT.y + n.z * LIGHT.z;
        int brightness = AMBIENT + (d > 0 ? d / 256 : 0);
        Color col = { scale_channel(base.r, brightness), scale_channel(base.g, brightness),
                      scale_channel(base.b, brightness) };

        f.tris_drawn++;
        f.raster(a, b, c, col);
    }
}

// ------------------------------------------------------------ вывод

fn void? write_ppm(Frame* f, String path)
{
    // TODO: заголовок "P6\n%d %d\n255\n", затем r, g, b каждого пикселя
    //       построчно. Соберите всё в DString и сохраните file::save.
    DString s;
    defer s.free();
    s.appendf("P6\n%d %d\n255\n", W, H);
    foreach (c : f.color)
    {
        s.append_char(c.r);
        s.append_char(c.g);
        s.append_char(c.b);
    }
    file::save(path, s.str_view())!;
}

// ---------------------------------------------------------------------
// Ниже менять ничего не нужно.

struct SortItem { ulong key; uint index; }

fn void main()
{
    // --- Модульные проверки вершинной стадии.
    Object probe = { .scale = 256, .pos = { 0, 0, 1024 } };
    Vec3i p = to_view({ 256, 0, 0 }, &probe);
    assert(p.x == 256 && p.y == 0 && p.z == 1024, "identity rotation + translation");
    probe.yaw = 6;                                   // 90 градусов
    p = to_view({ 256, 0, 0 }, &probe);
    assert(p.x == 0 && p.z == 1024 - 256, "yaw 90: +x goes to -z");
    probe.yaw = 0;
    probe.pitch = 6;
    p = to_view({ 0, 256, 0 }, &probe);
    assert(p.y == 0 && p.z == 1024 + 256, "pitch 90: +y goes to +z");
    probe.pitch = 0;
    probe.scale = 512;
    p = to_view({ 256, -256, 0 }, &probe);
    assert(p.x == 512 && p.y == -512, "scale");

    ScreenVert sv = project({ 0, 0, 512 });
    assert(sv.x == W * SUB / 2 && sv.y == H * SUB / 2, "center of view projects to screen center");
    sv = project({ 256, 256, 512 });
    assert(sv.x == W * SUB / 2 + FOCAL * SUB / 2, "x: farther = closer to center");
    assert(sv.y == H * SUB / 2 - FOCAL * SUB / 2, "y: up on screen is smaller y");
    assert(sv.inv_z == INV_Z_ONE / 512, "depth stores 1/z");

    // --- Сцена.
    Mesh cube = { CUBE_VERTS[..], CUBE_TRIS[..] };
    Mesh floor = { FLOOR_VERTS[..], FLOOR_TRIS[..] };
    Object[] scene = {
        { "floor",       &floor, 0, 0, 0,  2048, { 0, -300, 2600 } },
        { "red cube",    &cube,  1, 2, 2,  200,  { -420, -80, 1400 } },
        { "green cube",  &cube,  2, 5, 21, 260,  { 380, 40, 1900 } },
        { "blue cube",   &cube,  3, 1, 3,  150,  { 40, -140, 1000 } },
        { "red cube 2",  &cube,  1, 9, 1,  180,  { 650, -150, 1300 } },
    };

    // --- Фронтенд: команды + ключи (материал, затем глубина front-to-back).
    SortItem[8] items;
    foreach (i, &o : scene)
    {
        ulong key = (ulong)o.material << 40 | (ulong)(o.pos.z & 0xFF_FFFF) << 16 | (ulong)i;
        items[i] = { key, (uint)i };
    }
    for (usz i = 1; i < scene.len; i++)
    {
        SortItem x = items[i];
        usz j = i;
        while (j > 0 && items[j - 1].key > x.key) { items[j] = items[j - 1]; j--; }
        items[j] = x;
    }

    // --- Бэкенд.
    Frame* f = mem::new(Frame);
    defer free(f);
    f.clear({ 20, 24, 40 });
    int bound = -1;
    io::printn("draw order:");
    foreach (it : items[:scene.len])
    {
        Object* o = &scene[it.index];
        if (o.material != bound) { bound = o.material; f.material_binds++; }
        int before = f.tris_culled;
        draw_mesh(f, o);
        io::printfn("  %-11s mat=%d culled=%d", o.name, o.material, f.tris_culled - before);
    }

    io::printfn("triangles: in=%d culled=%d drawn=%d", f.tris_in, f.tris_culled, f.tris_drawn);
    io::printfn("pixels: written=%d depth_rejected=%d, material binds=%d",
                f.pixels_written, f.depth_rejected, f.material_binds);
    assert(f.tris_in == 4 * 12 + 2);
    assert(f.tris_culled + f.tris_drawn == f.tris_in);
    assert(f.tris_culled >= 4 * 6, "a closed convex mesh shows at most half of its triangles");
    assert(f.material_binds == 4);

    // --- ASCII-превью: яркость пикселя -> символ.
    String ramp = " .:-=+*#%@";
    for (int y = 0; y < H; y++)
    {
        io::print("  ");
        for (int x = 0; x < W; x++)
        {
            Color c = f.color[y * W + x];
            int lum = (c.r * 77 + c.g * 150 + c.b * 29) >> 8;
            io::printf("%c", ramp[lum * 10 / 256]);
        }
        io::printn();
    }

    // --- Файл и контрольная сумма.
    String path = "e0906.ppm";
    write_ppm(f, path)!!;
    char[] data = file::load(mem, path)!!;
    defer free(data);
    String header = "P6\n64 40\n255\n";
    assert(data.len == header.len + W * H * 3, "ppm: wrong file size %d", data.len);
    assert((String)data[:header.len] == header, "ppm: wrong header");
    assert(data[header.len] == f.color[0].r && data[header.len + 2] == f.color[0].b, "ppm: wrong pixel layout");
    uint h = 2166136261;
    foreach (c : data) { h ^= c; h *= 16777619; }
    io::printfn("wrote %s: %d bytes, fnv1a %08x", path, data.len, h);
}
