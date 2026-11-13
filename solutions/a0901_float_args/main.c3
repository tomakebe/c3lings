// Драйвер упражнения a0901. Этот файл НЕ нужно править — правьте float.s.
import std::io;

extern fn double fadd3(double a, double b, double c);
extern fn double fsub(double a, double b);
extern fn float lerp(float a, float b, float t);
extern fn double mix_args(long k, double x, long m, float y);

fn void main()
{
    assert(fadd3(1.5, 2.25, 4.0) == 7.75);
    assert(fsub(10.0, 2.5) == 7.5);
    assert(fsub(2.5, 10.0) == -7.5);
    assert(lerp(0.0f, 10.0f, 0.25f) == 2.5f);
    assert(lerp(4.0f, 8.0f, 0.5f) == 6.0f);
    assert(lerp(-2.0f, 2.0f, 1.0f) == 2.0f);
    assert(mix_args(7, 1.5, 9, 0.25f) == 1.75);
    io::printfn("fadd3(1.5, 2.25, 4)   = %.3f", fadd3(1.5, 2.25, 4.0));
    io::printfn("fsub(10, 2.5)         = %.3f", fsub(10.0, 2.5));
    io::printfn("lerp(0, 10, 0.25)     = %.3f", lerp(0.0f, 10.0f, 0.25f));
    io::printfn("mix_args(7, 1.5, 9, 0.25) = %.3f", mix_args(7, 1.5, 9, 0.25f));
}
