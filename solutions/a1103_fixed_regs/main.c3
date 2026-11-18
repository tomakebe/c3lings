// =====================================================================
//  a1103 · Inline assembly: fixed registers (mul, div, rdtsc)
// =====================================================================
//
//  Some instructions work with specific registers:
//
//      mulq src    — rdx:rax = rax * src  (unsigned 64x64 -> 128 bits)
//      divq src    — rax = rdx:rax / src, rdx = rdx:rax % src
//                    (if the quotient doesn't fit in 64 bits — a #DE
//                     exception, the process gets SIGFPE)
//      rdtsc       — edx:eax = cycle counter
//      cpuid       — eax/ebx/ecx/edx
//
//  In an asm block registers are referred to with $: $rax, $rdx. The
//  compiler knows that mulq clobbers rax and rdx, and will save them /
//  avoid using them for your variables.
//
//      ulong hi;
//      asm
//      {
//          movq $rax, a;
//          mulq b;
//          movq hi, $rdx;
//      }
//
//  This is the standard trick for "multiply and divide without overflow":
//  a * b / c, where a * b doesn't fit in 64 bits but the result does.
//  C3 has the uint128 type for this, but it's still useful to see what it
//  compiles to.
//
//  TASK:
//      mulhi(a, b)        — the high 64 bits of the 128-bit product
//      muldiv(a, b, c)    — (a * b) / c with a 128-bit intermediate result
//      rdtsc_now()        — the cycle counter value: (rdx << 32) | rax
//                           (we won't print it — it differs every time —
//                           we'll only check that it grows)
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

    // 10^12 * 10^12 overflows 64 bits, but after dividing by 10^9 it doesn't.
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
