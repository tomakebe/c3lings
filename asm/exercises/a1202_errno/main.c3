// Driver for exercise a1202. You do NOT need to edit this file — edit errno.s.
import std::io;

extern CInt last_errno;
extern fn long checked_write(CInt fd, char* buf, long len);
extern fn long checked_close(CInt fd);

fn void main()
{
    String msg = "ok to stdout\n";
    (void)io::stdout().flush();
    last_errno = 777;
    assert(checked_write(1, msg.ptr, msg.len) == msg.len);
    assert(last_errno == 777, "errno must not change on success");

    assert(checked_write(99, msg.ptr, msg.len) == -1);
    io::printfn("write(99)        -> errno %d", last_errno);
    assert(last_errno == 9);                // EBADF

    assert(checked_write(1, (char*)(uptr)16, 5) == -1);
    io::printfn("write(bad ptr)   -> errno %d", last_errno);
    assert(last_errno == 14);               // EFAULT

    assert(checked_close(-1) == -1);
    io::printfn("close(-1)        -> errno %d", last_errno);
    assert(last_errno == 9);
}
