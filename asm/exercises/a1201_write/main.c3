// Driver for exercise a1201. You do NOT need to edit this file — edit write.s.
import std::io;

extern fn long sys_write(CInt fd, char* buf, long len);
extern fn long write_cstr(char* s);

fn void main()
{
    io::printn("[c3] before");
    // printn/printfn flush the buffer themselves, but io::print does not. Before
    // a direct system call ALWAYS flush the stdout buffer, otherwise the output
    // order gets mixed up.
    (void)io::stdout().flush();
    String msg = "[asm] hello from syscall\n";
    long r = sys_write(1, msg.ptr, msg.len);
    assert(r == msg.len, "write returned %d", r);
    long r2 = write_cstr("[asm] zero-terminated string\n");
    assert(r2 == 29, "write_cstr returned %d", r2);
    io::printfn("[c3] wrote %d + %d bytes", r, r2);
}
