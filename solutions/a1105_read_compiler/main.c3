// =====================================================================
//  a1105 · Читаем вывод компилятора
// =====================================================================
//
//  В файле mystery.s — четыре функции, которые c3c сгенерировал с -O3
//  (`c3c compile -O3 --emit-asm`) из коротких функций на C3. Исходники
//  потеряны :) Вывод переведён из AT&T-синтаксиса в Intel и очищен от
//  отладочных директив, но сами инструкции — ровно как у компилятора.
//
//  Ваша задача — восстановить исходники: напишите функции guess_a ..
//  guess_d так, чтобы они давали те же результаты, что mystery_a ..
//  mystery_d, на всех проверяемых входах. Каждая — одно выражение.
//
//  Что полезно знать (подробнее — в asm/docs/11_inline_and_compiler.md):
//
//    * Деление на константу компилятор заменяет умножением на «магическое»
//      число и сдвигом: x / d == (x * M) >> s, где M ≈ 2^s / d.
//      0xCCCCCCCD = ceil(2^35 / 10). Остаток — x - (x / d) * d.
//    * lea умеет считать a + b*k + c для k = 1, 2, 4, 8 — им умножают на
//      3, 5, 9 и складывают с другим регистром.
//    * Знаковое деление на 2^k нельзя заменить одним sar: он округляет
//      к минус бесконечности, а C3 — к нулю. Поэтому для x < 0 сначала
//      прибавляют 2^k - 1.
//    * neg + cmovs — классика одной очень известной функции.
//
//  Править нужно только этот файл (main.c3), mystery.s трогать нельзя.
//
//  ЗАДАЧА: восстановите guess_a .. guess_d.
//
import std::io;

extern fn uint mystery_a(uint x);
extern fn int mystery_b(int x, int y);
extern fn int mystery_c(int x);
extern fn int mystery_d(int x);

fn uint guess_a(uint x)
{
    return x / 10 + x % 10;
}

fn int guess_b(int x, int y)
{
    return x * 9 + y * 4 - 7;
}

fn int guess_c(int x)
{
    return x / 4;
}

fn int guess_d(int x)
{
    return x < 0 ? -x : x;
}

fn void main()
{
    int[] samples = { 0, 1, 2, 3, 4, 5, 7, 9, 10, 11, 99, 100, 12345, -1, -2, -3, -4, -5, -7, -100, -12345, 1 << 20, -(1 << 20) };
    foreach (x : samples)
    {
        assert(guess_a((uint)x) == mystery_a((uint)x), "guess_a(%d)", (uint)x);
        assert(guess_c(x) == mystery_c(x), "guess_c(%d)", x);
        assert(guess_d(x) == mystery_d(x), "guess_d(%d)", x);
        foreach (y : samples) assert(guess_b(x, y) == mystery_b(x, y), "guess_b(%d, %d)", x, y);
    }
    io::printfn("a(12345) = %d", guess_a(12345));
    io::printfn("b(3, 5)  = %d", guess_b(3, 5));
    io::printfn("c(-7)    = %d", guess_c(-7));
    io::printfn("d(-42)   = %d", guess_d(-42));
    io::printn("all mysteries solved");
}
