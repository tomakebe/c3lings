// =====================================================================
//  E0406 · Отсечение по пирамиде видимости и точность float
// =====================================================================
//
//  Сначала прочитайте engine/docs/04_math.md (разделы 7–9).
//
//  Плоскость храним как float[<4>]: xyz — нормаль n (смотрит ВНУТРЬ
//  пирамиды), w — d. Расстояние со знаком до точки p: dot(n, p) + d.
//  Для настоящих расстояний плоскость надо нормализовать: разделить
//  все 4 числа на |n|.
//
//  Пирамиду извлекаем из матрицы VP = P * V (Gribb–Hartmann). Для
//  векторов-столбцов и клипа OpenGL (-w <= x,y,z <= w), где row(i) —
//  i-я СТРОКА матрицы (row(i)[j] = cols[j][i]):
//      left   = row3 + row0      right = row3 - row0
//      bottom = row3 + row1      top   = row3 - row1
//      near   = row3 + row2      far   = row3 - row2
//
//  Тесты (консервативные: могут пропустить невидимое, но никогда не
//  отбрасывают видимое):
//    * сфера (c, r) снаружи, если для какой-то плоскости dist(c) < -r;
//    * AABB (центр c, полуразмеры e) снаружи, если для какой-то
//      плоскости dist(c) < -(|n.x| e.x + |n.y| e.y + |n.z| e.z).
//
//  В конце — демонстрация точности: мир размером 100 км. Камера в
//  точке x = 100000.0; объект на 1 см правее. В float разность мировых
//  координат теряет сантиметры, а «рендер относительно камеры»
//  (вычитание в double, потом float) — нет.
//
//  ЗАДАЧА: реализуйте plane_normalize, plane_dist, extract_frustum,
//  sphere_visible, aabb_visible.
//
import std::io, std::math;

alias Vec3 = float[<3>];
alias Vec4 = float[<4>];
alias Plane = float[<4>];

struct Mat4 { Vec4[4] cols; }

fn Vec4 mul_vec(Mat4 m, Vec4 v) => m.cols[0] * v.x + m.cols[1] * v.y + m.cols[2] * v.z + m.cols[3] * v.w;
fn Mat4 mul(Mat4 a, Mat4 b)
{
    Mat4 r;
    for (int j = 0; j < 4; j++) r.cols[j] = mul_vec(a, b.cols[j]);
    return r;
}

// Перспектива в стиле OpenGL (gluPerspective): камера смотрит вдоль -Z.
fn Mat4 perspective(float fovy, float aspect, float near, float far)
{
    float f = 1.0f / math::tan(fovy * 0.5f);
    Mat4 m;
    m.cols[0] = { f / aspect, 0, 0, 0 };
    m.cols[1] = { 0, f, 0, 0 };
    m.cols[2] = { 0, 0, (far + near) / (near - far), -1 };
    m.cols[3] = { 0, 0, 2 * far * near / (near - far), 0 };
    return m;
}

// Вид: камера в точке eye, без поворота (смотрит вдоль -Z).
fn Mat4 view_at(Vec3 eye)
{
    return { { { 1, 0, 0, 0 }, { 0, 1, 0, 0 }, { 0, 0, 1, 0 }, { -eye.x, -eye.y, -eye.z, 1 } } };
}

fn Plane plane_normalize(Plane p)
{
    // TODO: разделить все 4 компоненты на длину нормали
    return p;
}

fn float plane_dist(Plane p, Vec3 point)
{
    // TODO: dot(n, point) + d
    return 0;
}

struct Frustum
{
    Plane[6] planes;   // left, right, bottom, top, near, far
}

fn Vec4 row(Mat4 m, int i) => { m.cols[0][i], m.cols[1][i], m.cols[2][i], m.cols[3][i] };

fn Frustum extract_frustum(Mat4 vp)
{
    Frustum f;
    // TODO: строки матрицы (функция row) и формулы Gribb–Hartmann,
    //       каждую плоскость нормализовать
    return f;
}

fn bool sphere_visible(Frustum* f, Vec3 c, float r)
{
    // TODO
    return true;
}

fn bool aabb_visible(Frustum* f, Vec3 c, Vec3 e)
{
    // TODO: «радиус» бокса вдоль нормали — (|n| * e).sum()
    return true;
}

// Точка внутри клип-объёма — эталон для проверки.
fn bool point_in_clip(Mat4 vp, Vec3 p)
{
    Vec4 c = mul_vec(vp, { p.x, p.y, p.z, 1 });
    return c.w > 0 && math::abs(c.x) <= c.w && math::abs(c.y) <= c.w && math::abs(c.z) <= c.w;
}

fn void main()
{
    const float PI = (float)math::PI;
    Mat4 proj = perspective(PI / 2, 1.0f, 1.0f, 100.0f);   // 90 градусов, квадратный экран
    Mat4 vp = mul(proj, view_at({ 0, 0, 0 }));
    Frustum f = extract_frustum(vp);

    // Плоскости нормализованы.
    foreach (p : f.planes) assert(math::abs((p.xyz * p.xyz).sum() - 1) < 1e-5f, "planes must be normalized");
    // При 90 градусах боковые плоскости — под 45: left = (0.707, 0, -0.707, 0).
    io::printfn("left plane   (%.3f, %.3f, %.3f, %.3f)", f.planes[0].x, f.planes[0].y, f.planes[0].z, f.planes[0].w + 0.0f);
    io::printfn("near plane   (%.3f, %.3f, %.3f, %.3f)", f.planes[4].x + 0.0f, f.planes[4].y + 0.0f, f.planes[4].z, f.planes[4].w);
    assert(math::abs(plane_dist(f.planes[4], { 0, 0, -1 })) < 1e-4f, "near plane at z = -1");
    assert(math::abs(plane_dist(f.planes[5], { 0, 0, -100 })) < 1e-3f, "far plane at z = -100");
    assert(math::abs(plane_dist(f.planes[4], { 0, 0, -11 }) - 10) < 1e-3f, "distance in world units");

    // Простые случаи.
    assert(sphere_visible(&f, { 0, 0, -10 }, 1), "in front");
    assert(!sphere_visible(&f, { 0, 0, 10 }, 1), "behind the camera");
    assert(!sphere_visible(&f, { 0, 0, -200 }, 1), "beyond far plane");
    assert(sphere_visible(&f, { 10.5f, 0, -10 }, 1), "touches the right plane: conservative -> visible");
    assert(!sphere_visible(&f, { 13, 0, -10 }, 1), "outside to the right");
    assert(aabb_visible(&f, { 11.5f, 0, -10 }, { 2, 2, 2 }), "box sticking into the frustum");
    assert(!aabb_visible(&f, { 0, 30, -10 }, { 2, 2, 2 }));

    // Сцена: сетка 21x21x6 объектов. Сравниваем с эталоном по центрам.
    int total = 0;
    int vis_spheres = 0;
    int vis_boxes = 0;
    for (int x = -10; x <= 10; x++)
    {
        for (int y = -10; y <= 10; y++)
        {
            for (int z = 0; z < 6; z++)
            {
                Vec3 c = { (float)x * 4, (float)y * 4, -(float)z * 25 + 10 };
                total++;
                bool s = sphere_visible(&f, c, 1.5f);
                bool b = aabb_visible(&f, c, { 1, 1, 1 });
                if (point_in_clip(vp, c))
                {
                    assert(s && b, "an object whose center is visible must never be culled");
                }
                if (s) vis_spheres++;
                if (b) vis_boxes++;
            }
        }
    }
    io::printfn("scene: %d objects, visible spheres %d, boxes %d", total, vis_spheres, vis_boxes);
    assert(vis_spheres > 0 && vis_spheres < total * 3 / 5 && vis_boxes < total * 3 / 5, "culling must reject a large part of the scene");

    // Точность: 100 км от начала координат.
    double cam = 100_000.0;
    double obj = 100_000.01;
    float world_delta = (float)obj - (float)cam;          // вычитание во float
    float relative = (float)(obj - cam);                  // camera-relative: вычитание в double
    io::printfn("float world delta %.5f m, camera-relative %.5f m", world_delta, relative);
    assert(math::abs(relative - 0.01f) < 1e-6f && math::abs(world_delta - 0.01f) > 1e-3f);
    io::printn("culling OK");
}
