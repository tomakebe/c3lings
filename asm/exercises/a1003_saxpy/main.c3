// Драйвер упражнения a1003. Этот файл НЕ нужно править — правьте saxpy.s.
import std::io;

extern fn void saxpy(long n, float a, float* x, float* y);

fn void main()
{
    float[100] x;
    float[100] y;
    for (long n = 0; n <= 70; n++)
    {
        for (int i = 0; i < 100; i++) { x[i] = i; y[i] = (float)(1000 + i); }
        saxpy(n, 2.0f, &x[1], &y[3]);
        for (int i = 0; i < 100; i++)
        {
            float want = (float)(1000 + i);
            if (i >= 3 && i < 3 + n) want += 2.0f * (float)(i - 2);
            assert(y[i] == want, "n=%d: y[%d] = %f, want %f", n, i, y[i], want);
        }
    }
    for (int i = 0; i < 100; i++) { x[i] = i; y[i] = 0.5f; }
    saxpy(37, -3.0f, &x, &y);
    io::printfn("y[0..3] = %.1f %.1f %.1f %.1f", y[0], y[1], y[2], y[3]);
    io::printfn("y[36]   = %.1f, y[37] = %.1f", y[36], y[37]);
    io::printn("saxpy ok");
}
