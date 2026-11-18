// Driver for exercise a1204. You do NOT need to edit this file — edit print.s.
import std::io;

extern fn long print_u64(ulong x);

fn void main()
{
    io::printn("[c3] numbers printed without libc:");
    (void)io::stdout().flush();
    ulong[] xs = { 0, 7, 10, 1234567890, ulong::max };
    foreach (x : xs)
    {
        long n = print_u64(x);
        assert(n > 0 && n <= 21, "print_u64 must return bytes written, got %d", n);
    }
    assert(print_u64(42) == 3);
    io::printn("[c3] done");
}
