// Драйвер упражнения a1005. Этот файл НЕ нужно править — правьте shuffle.s.
import std::io;

extern fn void reverse4(int* v);
extern fn void rgba_to_bgra(char* px, long count);

fn void main()
{
    int[4] v = { 1, 2, 3, 4 };
    reverse4(&v);
    assert(v[0] == 4 && v[1] == 3 && v[2] == 2 && v[3] == 1);
    io::printfn("reverse4 = %d %d %d %d", v[0], v[1], v[2], v[3]);

    char[4 * 11] px;
    for (int i = 0; i < 11; i++)
    {
        px[4 * i + 0] = (char)(i * 10 + 1);   // R
        px[4 * i + 1] = (char)(i * 10 + 2);   // G
        px[4 * i + 2] = (char)(i * 10 + 3);   // B
        px[4 * i + 3] = 255;                  // A
    }
    rgba_to_bgra(&px, 11);
    for (int i = 0; i < 11; i++)
    {
        assert(px[4 * i + 0] == i * 10 + 3 && px[4 * i + 1] == i * 10 + 2, "pixel %d", i);
        assert(px[4 * i + 2] == i * 10 + 1 && px[4 * i + 3] == 255, "pixel %d", i);
    }
    io::printfn("pixel 0  = %d %d %d %d", px[0], px[1], px[2], px[3]);
    io::printfn("pixel 10 = %d %d %d %d", px[40], px[41], px[42], px[43]);
}
