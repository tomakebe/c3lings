// =====================================================================
//  E0402 · Матрица 4x4: столбцы, порядок умножения, точки и направления
// =====================================================================
//
//  Сначала прочитайте engine/docs/04_math.md (разделы 2–3).
//
//  Наши соглашения (как в GLM/OpenGL):
//    * вектор-СТОЛБЕЦ: p' = M * p; композиция M = T * R * S применяется
//      справа налево (сначала масштаб, потом поворот, потом перенос);
//    * хранение по СТОЛБЦАМ: Mat4 — четыре столбца Vec4; трансляция
//      лежит в cols[3].xyz, т.е. в элементах 12, 13, 14 массива float[16].
//
//  Умножение матрицы на вектор — линейная комбинация столбцов:
//      M * v = cols[0]*v.x + cols[1]*v.y + cols[2]*v.z + cols[3]*v.w
//  Произведение матриц: j-й столбец (A * B) = A * (j-й столбец B).
//
//  Точка имеет w = 1 (на неё действует перенос), направление — w = 0.
//
//  Поворот вокруг Z на угол a (правая система, против часовой стрелки):
//      cols[0] = ( cos a, sin a, 0, 0)
//      cols[1] = (-sin a, cos a, 0, 0)
//
//  ЗАДАЧА: реализуйте mul_vec, mul, transpose, translation, scaling,
//  rotation_z, transform_point, transform_dir.
//
import std::io, std::math;

alias Vec3 = float[<3>];
alias Vec4 = float[<4>];

struct Mat4
{
    Vec4[4] cols;
}

fn Mat4 identity() => { { { 1, 0, 0, 0 }, { 0, 1, 0, 0 }, { 0, 0, 1, 0 }, { 0, 0, 0, 1 } } };

fn Vec4 mul_vec(Mat4 m, Vec4 v)
{
    return m.cols[0] * v.x + m.cols[1] * v.y + m.cols[2] * v.z + m.cols[3] * v.w;
}

fn Mat4 mul(Mat4 a, Mat4 b)
{
    Mat4 r;
    for (int j = 0; j < 4; j++) r.cols[j] = mul_vec(a, b.cols[j]);
    return r;
}

fn Mat4 transpose(Mat4 m)
{
    Mat4 r;
    for (int i = 0; i < 4; i++)
    {
        for (int j = 0; j < 4; j++) r.cols[i][j] = m.cols[j][i];
    }
    return r;
}

fn Mat4 translation(Vec3 t)
{
    Mat4 m = identity();
    m.cols[3] = { t.x, t.y, t.z, 1 };
    return m;
}

fn Mat4 scaling(Vec3 s)
{
    Mat4 m = identity();
    m.cols[0].x = s.x;
    m.cols[1].y = s.y;
    m.cols[2].z = s.z;
    return m;
}

fn Mat4 rotation_z(float a)
{
    float c = math::cos(a);
    float s = math::sin(a);
    Mat4 m = identity();
    m.cols[0] = { c, s, 0, 0 };
    m.cols[1] = { -s, c, 0, 0 };
    return m;
}

fn Vec3 transform_point(Mat4 m, Vec3 p)
{
    return mul_vec(m, { p.x, p.y, p.z, 1 }).xyz;
}

fn Vec3 transform_dir(Mat4 m, Vec3 d)
{
    return mul_vec(m, { d.x, d.y, d.z, 0 }).xyz;
}

// ---------------------------------------------------------------------

fn bool near3(Vec3 a, Vec3 b) => math::abs(a - b).max() < 1e-5f;

fn bool near_m(Mat4 a, Mat4 b)
{
    for (int i = 0; i < 4; i++)
    {
        if (math::abs(a.cols[i] - b.cols[i]).max() > 1e-5f) return false;
    }
    return true;
}

fn void show(String name, Vec3 v)
{
    // Крошечные отрицательные числа (-4e-8) печатались бы как "-0.000".
    for (int i = 0; i < 3; i++) if (math::abs(v[i]) < 5e-4f) v[i] = 0;
    io::printfn("%-16s (%.3f, %.3f, %.3f)", name, v.x, v.y, v.z);
}

fn void main()
{
    const float PI = (float)math::PI;
    Mat4 t = translation({ 10, 0, 0 });
    Mat4 r = rotation_z(PI / 2);
    Mat4 s = scaling({ 2, 2, 2 });

    // Раскладка в памяти: трансляция — элементы 12, 13, 14.
    Mat4 t2 = translation({ 7, 8, 9 });
    float* raw = (float*)&t2;
    io::printf("translation raw:");
    for (int i = 0; i < 16; i++) io::printf(" %d", (int)raw[i]);
    io::printn();
    assert(raw[12] == 7 && raw[13] == 8 && raw[14] == 9, "column-major: translation in elements 12..14");

    assert(near_m(mul(identity(), r), r) && near_m(mul(r, identity()), r), "identity");
    Vec3 p = { 1, 0, 0 };
    show("rotate (1,0,0)", transform_point(r, p));
    assert(near3(transform_point(r, p), { 0, 1, 0 }), "90 degrees around Z: X -> Y");

    Mat4 trs = mul(t, mul(r, s));        // сначала S, потом R, потом T
    Mat4 srt = mul(s, mul(r, t));        // наоборот
    show("T*R*S * (1,0,0)", transform_point(trs, p));
    show("S*R*T * (1,0,0)", transform_point(srt, p));
    assert(near3(transform_point(trs, p), { 10, 2, 0 }), "TRS: scale, rotate, then translate");
    assert(near3(transform_point(srt, p), { 0, 22, 0 }), "order matters");

    // Направление не переносится, а точка — да.
    show("dir (1,0,0)", transform_dir(trs, p));
    assert(near3(transform_dir(trs, p), { 0, 2, 0 }));

    // Ассоциативность и транспонирование.
    assert(near_m(mul(mul(t, r), s), mul(t, mul(r, s))), "matrix product is associative");
    assert(near_m(transpose(transpose(trs)), trs));
    assert(near_m(transpose(mul(t, r)), mul(transpose(r), transpose(t))), "(AB)^T = B^T A^T");
    // Обратный поворот — транспонированный поворот.
    assert(near_m(mul(transpose(r), r), identity()), "rotation matrices are orthonormal");

    // Транспонированная матрица переноса: перенос «уехал» в нижнюю строку.
    Mat4 tt = transpose(t2);
    io::printfn("transposed: row 3 = (%d, %d, %d, %d)", (int)tt.cols[0].w, (int)tt.cols[1].w, (int)tt.cols[2].w, (int)tt.cols[3].w);

    // 36 поворотов по 10 градусов возвращают точку на место.
    Mat4 step = rotation_z(PI / 18);
    Mat4 acc = identity();
    for (int i = 0; i < 36; i++) acc = mul(step, acc);
    Vec3 back = transform_point(acc, { 3, 4, 0 });
    show("36 x 10 degrees", back);
    assert(math::abs(back - (Vec3){ 3, 4, 0 }).max() < 1e-4f);
    io::printn("mat4 OK");
}
