// Тестовый стенд упражнения a0701. НЕ редактируйте этот файл — правьте struct.s.
import std::io;

struct Rec
{
    char tag;       // 1 байт
    long value;     // 8 байт, выравнивание 8
    short count;    // 2 байта, выравнивание 2
}

extern fn void asm_rec_init(Rec* r, char tag, long value, short count);
extern fn long asm_rec_total(Rec* r);
extern fn long asm_sum_values(Rec* arr, usz n);

fn void main()
{
    io::printfn("Rec: size=%d value@%d count@%d", Rec::size, Rec::members[1].offset, Rec::members[2].offset);
    Rec r;
    asm_rec_init(&r, 'A', 1_000_000_000_000, -5);
    assert(r.tag == 'A' && r.value == 1_000_000_000_000 && r.count == -5,
           "asm_rec_init: tag=%d value=%d count=%d", r.tag, r.value, r.count);
    assert(asm_rec_total(&r) == 65 + 1_000_000_000_000 - 5, "asm_rec_total = %d", asm_rec_total(&r));
    Rec[4] arr = { { 1, 10, 0 }, { 2, 20, 0 }, { 3, -300, 0 }, { 4, 4000, 0 } };
    assert(asm_sum_values(&arr, 4) == 3730, "asm_sum_values = %d", asm_sum_values(&arr, 4));
    assert(asm_sum_values(&arr, 0) == 0, "asm_sum_values(n=0) = %d", asm_sum_values(&arr, 0));
    io::printfn("total=%d sum_values=%d", asm_rec_total(&r), asm_sum_values(&arr, 4));
}
