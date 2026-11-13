// Драйвер упражнения a1401. Этот файл НЕ нужно править — правьте tsc.s.
import std::io;

extern fn ulong read_tsc();
extern fn ulong read_tscp(uint* aux);

fn void main()
{
    ulong prev = read_tsc();
    assert(prev != 0);
    ulong grew = 0;
    for (int i = 0; i < 1000; i++)
    {
        ulong t = read_tsc();
        assert(t >= prev, "TSC must not go backwards on one core");
        if (t > prev) grew++;
        prev = t;
    }
    assert(grew > 900, "TSC barely moves: are the high 32 bits combined correctly?");
    uint aux = 0xFFFF_FFFF;
    ulong t2 = read_tscp(&aux);
    assert(t2 >= prev && t2 - prev < 1UL << 40);
    assert(aux != 0xFFFF_FFFF, "rdtscp must store IA32_TSC_AUX (ecx)");
    // Время зависит от машины, поэтому печатаем только факты.
    io::printn("tsc is monotonic: true");
    io::printn("rdtscp aux written: true");
}
