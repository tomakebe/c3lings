// Драйвер упражнения a1501. Этот файл НЕ нужно править — правьте bytes.s.
import std::io;

extern fn CInt answer();
extern fn long add_args(long a, long b);
extern fn long neg_arg(long x);
extern fn long add_r8_r9(long a, long b, long c, long d, long e, long f);

fn void main()
{
    assert(answer() == 42, "answer() = %d", answer());
    assert(add_args(40, 2) == 42 && add_args(-5, 5) == 0);
    assert(neg_arg(42) == -42 && neg_arg(-7) == 7);
    assert(add_r8_r9(0, 0, 0, 0, 30, 12) == 42);
    io::printfn("answer()          = %d", answer());
    io::printfn("add_args(40, 2)   = %d", add_args(40, 2));
    io::printfn("neg_arg(42)       = %d", neg_arg(42));
    io::printfn("add_r8_r9(..30,12) = %d", add_r8_r9(0, 0, 0, 0, 30, 12));
}
