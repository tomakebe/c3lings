// Driver for exercise a1404. You do NOT need to edit this file — edit fill.s.
import std::io;

extern fn void fill_u32(uint* dst, uint v, long n);

fn void main()
{
    uint[300] buf;
    for (long off = 0; off < 9; off++)
    {
        for (long n = 0; n <= 120; n++)
        {
            foreach (&x : buf) *x = 0xDEAD;
            fill_u32(&buf[off], 0x1234_5678, n);
            foreach (i, x : buf)
            {
                bool inside = (long)i >= off && (long)i < off + n;
                assert(x == (inside ? 0x1234_5678 : 0xDEAD), "off=%d n=%d i=%d", off, n, i);
            }
        }
    }
    fill_u32(&buf[3], 7, 250);
    ulong sum;
    foreach (x : buf) sum += x;
    io::printfn("checksum = %d", sum);
    io::printn("fill ok");
}
