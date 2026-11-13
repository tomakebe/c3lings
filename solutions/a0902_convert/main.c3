// Драйвер упражнения a0902. Этот файл НЕ нужно править — правьте convert.s.
import std::io;

extern fn double long_to_double(long x);
extern fn long trunc_to_long(double x);
extern fn long round_to_long(double x);
extern fn double average(int* a, long n);

fn void main()
{
    assert(long_to_double(-42) == -42.0);
    assert(long_to_double(1L << 53) == 9007199254740992.0);
    assert(trunc_to_long(2.9) == 2);
    assert(trunc_to_long(-2.9) == -2);
    assert(trunc_to_long(1e300) == long::min);   // «integer indefinite»
    assert(round_to_long(2.4) == 2);
    assert(round_to_long(2.6) == 3);
    assert(round_to_long(2.5) == 2);    // банковское округление!
    assert(round_to_long(3.5) == 4);
    assert(round_to_long(-2.5) == -2);
    double[] xs = { 2.5, 3.5, -1.5, 0.49999, 7.0 };
    foreach (x : xs) io::printfn("x=%8.5f trunc=%2d round=%2d", x, trunc_to_long(x), round_to_long(x));
    io::printfn("trunc(1e300) = %d", trunc_to_long(1e300));

    int[] a = { 1, 2, 3, 4 };
    assert(average(a.ptr, a.len) == 2.5);
    int[] b = { -7, 100, 3 };
    io::printfn("average = %.4f", average(b.ptr, b.len));
    io::printfn("average = %.4f", average(a.ptr, a.len));
}
