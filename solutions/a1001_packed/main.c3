// Драйвер упражнения a1001. Этот файл НЕ нужно править — правьте packed.s.
import std::io;

extern fn void add4(float* dst, float* a, float* b);
extern fn void scale4(float* v, float k);
extern fn void add_arrays(float* dst, float* a, float* b, long n);

fn void main()
{
    float[4] a = { 1, 2, 3, 4 };
    float[4] b = { 10, 20, 30, 40 };
    float[4] d;
    add4(&d, &a, &b);
    assert(d[0] == 11 && d[1] == 22 && d[2] == 33 && d[3] == 44);
    io::printfn("add4   = %.1f %.1f %.1f %.1f", d[0], d[1], d[2], d[3]);
    scale4(&d, 0.5f);
    assert(d[0] == 5.5f && d[3] == 22);
    io::printfn("scale4 = %.1f %.1f %.1f %.1f", d[0], d[1], d[2], d[3]);

    float[19] x;   // нечётная длина — проверим и невыровненные адреса
    float[19] y;
    float[19] z;
    for (int i = 0; i < 19; i++) { x[i] = i; y[i] = (float)(100 * i); z[i] = -1; }
    add_arrays(&z[1], &x[1], &y[2], 16);    // 16 элементов, адреса не кратны 16
    for (int i = 1; i <= 16; i++) assert(z[i] == (float)(i + 100 * (i + 1)), "z[%d] = %f", i, z[i]);
    assert(z[0] == -1 && z[17] == -1 && z[18] == -1, "write out of bounds");
    io::printfn("z[1..4] = %.0f %.0f %.0f %.0f, z[16] = %.0f", z[1], z[2], z[3], z[4], z[16]);
}
