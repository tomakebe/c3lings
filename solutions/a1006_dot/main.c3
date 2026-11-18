// Driver for exercise a1006. You do NOT need to edit this file — edit dot.s.
import std::io;

extern fn float dot_f32(float* a, float* b, long n);

fn void main()
{
    float[200] a;
    float[200] b;
    for (int i = 0; i < 200; i++) { a[i] = (float)((i % 7) - 3); b[i] = (float)((i % 5) + 1); }
    for (long n = 0; n <= 150; n++)
    {
        float want = 0;
        for (long i = 0; i < n; i++) want += a[i + 2] * b[i + 1];
        float got = dot_f32(&a[2], &b[1], n);
        assert(got == want, "n=%d: got %f, want %f", n, got, want);
    }
    io::printfn("dot(200) = %.1f", dot_f32(&a, &b, 200));
    io::printfn("dot(13)  = %.1f", dot_f32(&a, &b, 13));
    float[3] u = { 1, 2, 3 };
    float[3] v = { 4, 5, 6 };
    io::printfn("dot(u,v) = %.1f", dot_f32(&u, &v, 3));
}
