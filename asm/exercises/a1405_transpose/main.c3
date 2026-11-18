// Driver for exercise a1405. You do NOT need to edit this file — edit transpose.s.
import std::io;

extern fn void transpose4x4(int* dst, long dst_stride, int* src, long src_stride);
extern fn void transpose(int* dst, int* src, long n);

fn void main()
{
    int[16] m;
    int[16] t;
    for (int i = 0; i < 16; i++) m[i] = i;
    transpose4x4(&t, 4, &m, 4);
    for (int r = 0; r < 4; r++)
    {
        for (int c = 0; c < 4; c++) assert(t[r * 4 + c] == m[c * 4 + r], "4x4: t[%d][%d]", r, c);
    }
    io::printfn("t row 0 = %d %d %d %d", t[0], t[1], t[2], t[3]);
    io::printfn("t row 3 = %d %d %d %d", t[12], t[13], t[14], t[15]);

    int* src = mem::new_array(int, 64 * 64);
    int* dst = mem::new_array(int, 64 * 64);
    defer { free(src); free(dst); }
    for (long n = 4; n <= 64; n += 4)
    {
        for (long i = 0; i < n * n; i++) { src[i] = (int)(i * 31 + 7); dst[i] = -1; }
        transpose(dst, src, n);
        for (long r = 0; r < n; r++)
        {
            for (long c = 0; c < n; c++) assert(dst[r * n + c] == src[c * n + r], "n=%d r=%d c=%d", n, r, c);
        }
    }
    io::printn("transpose ok");
}
