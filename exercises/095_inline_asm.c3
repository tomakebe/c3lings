// =====================================================================
//  095 · Inline-ассемблер
// =====================================================================
//
//  Иногда нужна конкретная инструкция процессора, до которой язык не
//  дотягивается: cpuid, rdtsc, особые атомарные операции, «широкое»
//  умножение 32x32 -> 64. Для этого в C3 есть inline-ассемблер.
//  (Целевая машина курса — x86-64 Linux; на ARM этот код не соберётся,
//  поэтому в реальном проекте такие функции прячут за @feat(X86_64)
//  с запасной реализацией на чистом C3.)
//
//  Две формы:
//
//  1) Строка: `asm("nop");` — текст уходит в бэкенд как есть, без
//     каких-либо входов/выходов. Годится для одиночных инструкций без
//     операндов.
//
//  2) Блок — главная форма:
//
//      fn int add_asm(int a, int b)
//      {
//          int r;
//          asm
//          {
//              movl $eax, a;      // eax = a
//              addl $eax, b;      // eax += b
//              movl r, $eax;      // r = eax
//          }
//          return r;
//      }
//
//  Правила синтаксиса блока:
//    * порядок операндов как в Intel: `инструкция ПРИЁМНИК, ИСТОЧНИК`;
//    * мнемоника с суффиксом размера, как в AT&T: movb/movw/movl/movq
//      (8/16/32/64 бит), addl, subq, xaddl...;
//    * регистры пишутся строчными буквами с `$`: $eax, $rdx, $ecx;
//    * переменные C3 пишутся просто по имени (`a`, `r`), компилятор сам
//      решит, где они лежат, и выведет входы/выходы и испорченные
//      регистры (clobbers). В GCC это пришлось бы описывать вручную:
//      asm("..." : "=r"(r) : "r"(a), "r"(b) : "cc");
//    * память: `[ptr]`, `[ptr + i * 4 + 8]`; адрес переменной — `&x`;
//    * каждая инструкция заканчивается `;`.
//
//  Реализация — «work in progress»: поддержано лишь подмножество
//  инструкций. На 0.8.5 (x86-64) работают, например: mov*, movzbl,
//  movslq, add/sub/adc, xor/or/not/neg, inc/dec, bswap, xchg, xadd,
//  cmpxchg, mull, divl, idivl, cpuid, rdtsc, nop. А вот shl, imul,
//  and, cmp, lea, popcnt — «Unknown instruction for the current
//  target». Если чего-то нет — для битовых операций есть std::bits
//  (прошлое упражнение), и он обычно генерирует ту же инструкцию.
//
//  Неявные регистры. Некоторые инструкции работают с фиксированными
//  регистрами, и это надо знать:
//
//      mull src     ; edx:eax = eax * src   (беззнаковое, 64-битный результат)
//      divl src     ; eax = edx:eax / src,  edx = edx:eax % src
//                   ; ВАЖНО: перед делением обнулите edx, иначе
//                   ; делимое — мусор, а если частное не влезет в 32
//                   ; бита — процессор бросит исключение (#DE, SIGFPE)
//      cpuid        ; вход eax = номер «листа», выход eax, ebx, ecx, edx
//      xaddl [p], r ; атомарно (с lock) : tmp = *p; *p += r; r = tmp
//
//  Когда НЕ надо писать asm: почти всегда. Компилятор не может
//  оптимизировать через asm-блок (это «чёрный ящик»), код теряет
//  переносимость, а ошибки в нём не ловят никакие проверки C3.
//  Сначала ищите builtin/стандартную функцию, asm — последнее средство.
//
//  ЗАДАЧА: реализуйте на ассемблере
//    * mul_wide — 64-битное произведение двух uint через mull;
//    * divmod — частное и остаток через divl.
//  Функции add_asm, fetch_add и cpu_vendor уже написаны — изучите их.
//
//  Ожидаемый вывод:
//      add_asm(2, 40) = 42
//      mul_wide = 18446744065119617025
//      mul_wide(100000, 300000) = 30000000000
//      100 / 7 = 14 rem 2
//      fetch_add: old=10 new=15
//      cpuid vendor: 12 printable chars
//
import std::io;

fn int add_asm(int a, int b)
{
    int r;
    asm
    {
        movl $eax, a;
        addl $eax, b;
        movl r, $eax;
    }
    return r;
}

fn ulong mul_wide(uint a, uint b)
{
    uint lo;
    uint hi;
    // TODO: asm-блок: положите a в $eax, выполните mull b,
    //       заберите младшую половину из $eax, старшую — из $edx.
    return (ulong)hi << 32 | lo;
}

fn void divmod(uint a, uint b, uint* quot, uint* rem)
{
    uint q;
    uint r;
    // TODO: asm-блок с divl (не забудьте про $edx!)
    *quot = q;
    *rem = r;
}

// Атомарное «прочитать и прибавить» — так устроен Atomic.add внутри.
fn int fetch_add(int* p, int v)
{
    int old = v;
    asm { xaddl [p], old; }
    return old;
}

fn char[12] cpu_vendor()
{
    uint b;
    uint c;
    uint d;
    asm
    {
        movl $eax, 0;
        cpuid;
        movl b, $ebx;
        movl c, $ecx;
        movl d, $edx;
    }
    uint[3] words = { b, d, c };   // "Genu" "ineI" "ntel" — именно в порядке ebx, edx, ecx
    return bitcast(words, char[12]);
}

fn void main()
{
    asm("nop");
    io::printfn("add_asm(2, 40) = %d", add_asm(2, 40));
    io::printfn("mul_wide = %d", mul_wide(0xFFFF_FFFF, 0xFFFF_FFFF));
    io::printfn("mul_wide(100000, 300000) = %d", mul_wide(100000, 300000));

    uint q;
    uint r;
    divmod(100, 7, &q, &r);
    io::printfn("100 / 7 = %d rem %d", q, r);

    int x = 10;
    int old = fetch_add(&x, 5);
    io::printfn("fetch_add: old=%d new=%d", old, x);

    // Имя производителя зависит от машины, поэтому печатаем только проверку.
    char[12] vendor = cpu_vendor();
    int printable = 0;
    foreach (ch : vendor) if (ch >= 0x20 && ch < 0x7f) printable++;
    io::printfn("cpuid vendor: %d printable chars", printable);
}
