// Драйвер упражнения a1302. Этот файл НЕ нужно править — правьте search.s.
import std::io;

extern fn long count_less(int* a, long n, int pivot);
extern fn long lower_bound(int* a, long n, int key);

fn long ref_lower_bound(int[] a, int key)
{
    long i = 0;
    while (i < a.len && a[i] < key) i++;
    return i;
}

fn void main()
{
    int[] data = { 5, -3, 12, 7, 0, 7, 99, -50, 8, 2, 7, 1 };
    assert(count_less(data.ptr, data.len, 7) == 6);
    assert(count_less(data.ptr, data.len, -100) == 0);
    assert(count_less(data.ptr, 0, 5) == 0);
    io::printfn("count_less(7)  = %d", count_less(data.ptr, data.len, 7));
    io::printfn("count_less(100) = %d", count_less(data.ptr, data.len, 100));

    int[64] sorted;
    for (int i = 0; i < 64; i++) sorted[i] = i * 3 - 20;   // -20, -17, ..., 169
    for (long n = 0; n <= 64; n++)
    {
        for (int key = -25; key <= 175; key++)
        {
            assert(lower_bound(&sorted, n, key) == ref_lower_bound(sorted[:n], key), "n=%d key=%d", n, key);
        }
    }
    io::printfn("lower_bound(1)   = %d", lower_bound(&sorted, 64, 1));
    io::printfn("lower_bound(-99) = %d", lower_bound(&sorted, 64, -99));
    io::printfn("lower_bound(999) = %d", lower_bound(&sorted, 64, 999));
}
