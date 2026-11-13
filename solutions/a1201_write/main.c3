// Драйвер упражнения a1201. Этот файл НЕ нужно править — правьте write.s.
import std::io;

extern fn long sys_write(CInt fd, char* buf, long len);
extern fn long write_cstr(char* s);

fn void main()
{
    io::printn("[c3] before");
    // printn/printfn сбрасывают буфер сами, но io::print — нет. Перед прямым
    // системным вызовом ВСЕГДА сбрасывайте буфер stdout, иначе порядок вывода
    // перемешается.
    (void)io::stdout().flush();
    String msg = "[asm] hello from syscall\n";
    long r = sys_write(1, msg.ptr, msg.len);
    assert(r == msg.len, "write returned %d", r);
    long r2 = write_cstr("[asm] zero-terminated string\n");
    assert(r2 == 29, "write_cstr returned %d", r2);
    io::printfn("[c3] wrote %d + %d bytes", r, r2);
}
