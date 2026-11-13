// Драйвер упражнения a1205. Этот файл НЕ нужно править — правьте exit.s.
import std::io;

extern fn void finish(char* msg, long len);

fn void main()
{
    io::printn("[c3] about to leave through the kernel");
    (void)io::stdout().flush();
    String bye = "[asm] bye\n";
    finish(bye.ptr, bye.len);
    // Сюда управление попасть не должно.
    io::printn("[c3] UNREACHABLE");
    unreachable("finish() returned");
}
