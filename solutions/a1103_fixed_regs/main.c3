// =====================================================================
//  a1103 · Inline-ассемблер: фиксированные регистры (mul, div, rdtsc)
// =====================================================================
//
//  Некоторые инструкции работают с конкретными регистрами:
//
//      mulq src    — rdx:rax = rax * src  (беззнаковое 64x64 -> 128 бит)
//      divq src    — rax = rdx:rax / src, rdx = rdx:rax % src
//                    (если частное не влезает в 64 бита — исключение #DE,
//                     процесс получит SIGFPE)
//      rdtsc       — edx:eax = счётчик тактов
//      cpuid       — eax/ebx/ecx/edx
//
//  В блоке asm к регистрам обращаются через $: $rax, $rdx. Компилятор
//  знает, что mulq портит rax и rdx, и сохранит/не будет использовать
//  их для ваших переменных.
//
//      ulong hi;
//      asm
//      {
//          movq $rax, a;
//          mulq b;
//          movq hi, $rdx;
//      }
//
//  Это стандартный трюк для «умножить и поделить без переполнения»:
//  a * b / c, где a * b не помещается в 64 бита, но результат помещается.
//  В C3 для этого есть тип uint128, но посмотреть, во что он
//  компилируется, всё равно полезно.
//
//  ЗАДАЧА:
//      mulhi(a, b)        — старшие 64 бита 128-битного произведения
//      muldiv(a, b, c)    — (a * b) / c с 128-битным промежуточным результатом
//      rdtsc_now()        — значение счётчика тактов: (rdx << 32) | rax
//                           (печатать его мы не будем — оно каждый раз
//                           разное, — только проверим, что он растёт)
//
import std::io;

fn ulong mulhi(ulong a, ulong b)
{
    ulong hi;
    asm
    {
        movq $rax, a;
        mulq b;
        movq hi, $rdx;
    }
    return hi;
}

fn ulong muldiv(ulong a, ulong b, ulong c)
{
    ulong q;
    asm
    {
        movq $rax, a;
        mulq b;
        divq c;
        movq q, $rax;
    }
    return q;
}

fn ulong rdtsc_now()
{
    uint lo;
    uint hi;
    asm
    {
        rdtsc;
        movl lo, $eax;
        movl hi, $edx;
    }
    return (ulong)hi << 32 | lo;
}

fn void main()
{
    assert(mulhi(1UL << 63, 4) == 2);
    assert(mulhi(ulong::max, ulong::max) == ulong::max - 1);
    assert(mulhi(123, 456) == 0);
    io::printfn("mulhi(2^63, 6)       = %d", mulhi(1UL << 63, 6));
    io::printfn("mulhi(max, max)      = 0x%X", mulhi(ulong::max, ulong::max));

    // 10^12 * 10^12 переполняет 64 бита, но после деления на 10^9 — нет.
    ulong t = 1_000_000_000_000;
    assert(muldiv(t, t, 1_000_000_000) == 1_000_000_000_000_000);
    assert(muldiv(ulong::max, 3, 5) == (ulong)((uint128)ulong::max * 3 / 5));
    io::printfn("muldiv(1e12, 1e12, 1e9) = %d", muldiv(t, t, 1_000_000_000));
    io::printfn("muldiv(max, 3, 5)       = %d", muldiv(ulong::max, 3, 5));

    ulong t0 = rdtsc_now();
    ulong s = 0;
    for (int i = 0; i < 100000; i++) s += (ulong)i * (ulong)i;
    ulong t1 = rdtsc_now();
    assert(t0 != 0 && t1 > t0, "rdtsc must grow");
    io::printfn("rdtsc grows: %s (checksum %d)", t1 > t0, s);
}
