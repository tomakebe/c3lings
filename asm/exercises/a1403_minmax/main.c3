// Драйвер упражнения a1403. Этот файл НЕ нужно править — правьте minmax.s.
import std::io;

extern fn void minmax(int* a, long n, int* out_min, int* out_max);

fn void main()
{
    int[257] a;
    uint s = 2024;
    for (int i = 0; i < 257; i++)
    {
        s = s * 1664525 + 1013904223;
        a[i] = (int)(s >> 8) - (1 << 23);
    }
    for (long n = 1; n <= 257; n++)
    {
        int lo = a[0];
        int hi = a[0];
        for (long i = 1; i < n; i++) { if (a[i] < lo) lo = a[i]; if (a[i] > hi) hi = a[i]; }
        int got_lo;
        int got_hi;
        minmax(&a, n, &got_lo, &got_hi);
        assert(got_lo == lo && got_hi == hi, "n=%d: got (%d, %d), want (%d, %d)", n, got_lo, got_hi, lo, hi);
    }
    int lo;
    int hi;
    minmax(&a, 257, &lo, &hi);
    io::printfn("min = %d, max = %d", lo, hi);
    int[] one = { -5 };
    minmax(one.ptr, 1, &lo, &hi);
    io::printfn("single: min = %d, max = %d", lo, hi);
}
