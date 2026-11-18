// Driver for exercise a1402. You do NOT need to edit this file — edit sum.s.
import std::io;

extern fn long sum_i64(long* a, long n);

fn void main()
{
    long[103] a;
    for (int i = 0; i < 103; i++) a[i] = (long)i * i - 1000;
    for (long n = 0; n <= 103; n++)
    {
        long want = 0;
        for (long i = 0; i < n; i++) want += a[i];
        long got = sum_i64(&a, n);
        assert(got == want, "n=%d: got %d, want %d", n, got, want);
    }
    io::printfn("sum(103) = %d", sum_i64(&a, 103));
    io::printfn("sum(7)   = %d", sum_i64(&a, 7));
}
