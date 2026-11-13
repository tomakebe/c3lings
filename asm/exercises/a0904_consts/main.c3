// Драйвер упражнения a0904. Этот файл НЕ нужно править — правьте consts.s.
import std::io;

extern fn double asm_fabs(double x);
extern fn double asm_fneg(double x);
extern fn double vec2_length(double x, double y);
extern fn double horner(double* c, long n, double x);
extern fn double circle_area(double r);

fn void main()
{
    assert(asm_fabs(-3.5) == 3.5);
    assert(asm_fabs(3.5) == 3.5);
    assert(asm_fneg(2.0) == -2.0);
    assert(asm_fneg(-2.0) == 2.0);
    // -0.0 тоже должен стать +0.0: проверяем знаковый бит
    assert(bitcast(asm_fabs(-0.0), ulong) == 0);
    assert(bitcast(asm_fneg(0.0), ulong) == 0x8000_0000_0000_0000UL);
    assert(vec2_length(3.0, 4.0) == 5.0);
    io::printfn("fabs(-3.5)=%.1f fneg(2)=%.1f len(3,4)=%.1f", asm_fabs(-3.5), asm_fneg(2.0), vec2_length(3.0, 4.0));

    double[] c = { 1.0, -2.0, 0.5, 3.0 };    // 1 - 2x + 0.5x^2 + 3x^3
    assert(horner(c.ptr, c.len, 0.0) == 1.0);
    assert(horner(c.ptr, c.len, 2.0) == 23.0);
    assert(horner(c.ptr, 1, 5.0) == 1.0);
    io::printfn("p(2) = %.3f, p(-1.5) = %.4f", horner(c.ptr, c.len, 2.0), horner(c.ptr, c.len, -1.5));
    io::printfn("circle_area(2) = %.6f", circle_area(2.0));
}
