// Драйвер упражнения a1004. Этот файл НЕ нужно править — правьте find.s.
import std::io;

extern fn long find_byte(char* s, long n, char c);
extern fn long count_byte(char* s, long n, char c);

fn long ref_find(char* s, long n, char c)
{
    for (long i = 0; i < n; i++) if (s[i] == c) return i;
    return -1;
}

fn void main()
{
    String text = "The quick brown fox jumps over the lazy dog; pack my box with five dozen liquor jugs!";
    char* s = text.ptr;
    long n = text.len;
    for (long len = 0; len <= n; len++)
    {
        foreach (c : "Tqxz!;o ")
        {
            assert(find_byte(s, len, c) == ref_find(s, len, c), "find '%c' in first %d", c, len);
        }
    }
    io::printfn("find 'x'  -> %d", find_byte(s, n, 'x'));
    io::printfn("find '!'  -> %d", find_byte(s, n, '!'));
    io::printfn("find '#'  -> %d", find_byte(s, n, '#'));
    assert(count_byte(s, n, 'o') == 7);
    assert(count_byte(s, 0, 'o') == 0);
    assert(count_byte(s, 17, ' ') == 3);
    io::printfn("count 'o' -> %d", count_byte(s, n, 'o'));
    io::printfn("count ' ' -> %d", count_byte(s, n, ' '));
}
