// Driver for exercise a1205. You do NOT need to edit this file — edit exit.s.
import std::io;

extern fn void finish(char* msg, long len);

fn void main()
{
    io::printn("[c3] about to leave through the kernel");
    (void)io::stdout().flush();
    String bye = "[asm] bye\n";
    finish(bye.ptr, bye.len);
    // Control must never reach this point.
    io::printn("[c3] UNREACHABLE");
    unreachable("finish() returned");
}
