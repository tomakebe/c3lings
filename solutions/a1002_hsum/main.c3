// Driver for exercise a1002. You do NOT need to edit this file — edit hsum.s.
import std::io;

extern fn float hsum4(float* v);
extern fn float sum_f32(float* a, long n);

fn void main()
{
    float[4] v = { 1, 20, 300, 4000 };
    assert(hsum4(&v) == 4321);
    io::printfn("hsum4 = %.1f", hsum4(&v));

    float[37] a;
    for (int i = 0; i < 37; i++) a[i] = (float)(i + 1);   // 1..37, sum = 703
    for (long n = 0; n <= 37; n++)
    {
        float expect = (float)(n * (n + 1) / 2);
        float got = sum_f32(&a, n);
        assert(got == expect, "sum of %d elements: got %f, want %f", n, got, expect);
    }
    io::printfn("sum(1..37) = %.1f", sum_f32(&a, 37));
    io::printfn("sum(1..5)  = %.1f", sum_f32(&a, 5));
    io::printfn("sum(1..3)  = %.1f", sum_f32(&a, 3));
}
