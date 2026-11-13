// Тестовый стенд упражнения a0404. НЕ редактируйте этот файл — правьте histogram.s.
import std::io;

extern fn void asm_histogram(char* data, usz n, uint* counts);

fn void main()
{
    char[1000] data;
    for (usz i = 0; i < data.len; i++) data[i] = (char)((i * 7) % 3 == 0 ? 'a' : (i % 5 == 0 ? 200 : i % 4));
    uint[256] counts;
    uint[256] expect;
    foreach (c : data) expect[c]++;
    counts[255] = 0xDEAD;          // проверим, что вы не затираете счётчики заново
    expect[255] = 0xDEAD;
    asm_histogram(&data, data.len, &counts);
    for (usz i = 0; i < 256; i++)
    {
        assert(counts[i] == expect[i], "counts[%d] = %d, ожидалось %d", i, counts[i], expect[i]);
    }
    io::printfn("a=%d 200=%d 0=%d 1=%d 2=%d 3=%d 255=%x",
                counts['a'], counts[200], counts[0], counts[1], counts[2], counts[3], counts[255]);
}
