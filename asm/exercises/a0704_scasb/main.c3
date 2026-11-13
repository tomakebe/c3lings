// Тестовый стенд упражнения a0704. НЕ редактируйте этот файл — правьте scasb.s.
import std::io;

extern fn usz asm_strlen_scas(ZString s);
extern fn char* asm_memchr(char* p, int c, usz n);

fn void main()
{
    assert(asm_strlen_scas("") == 0, "asm_strlen_scas(\"\") = %d", asm_strlen_scas(""));
    assert(asm_strlen_scas("x") == 1, "asm_strlen_scas(\"x\") = %d", asm_strlen_scas("x"));
    assert(asm_strlen_scas("assembly") == 8, "asm_strlen_scas(\"assembly\") = %d", asm_strlen_scas("assembly"));
    char[10] buf = "find:me!!";
    char* hit = asm_memchr(&buf, ':', 9);
    assert(hit == &buf[4], "asm_memchr(':') должна вернуть &buf[4]");
    assert(asm_memchr(&buf, '!', 9) == &buf[7], "asm_memchr('!') должна вернуть &buf[7] (первое вхождение)");
    assert(asm_memchr(&buf, 'f', 9) == &buf[0], "asm_memchr('f') должна вернуть &buf[0]");
    assert(asm_memchr(&buf, '?', 9) == null, "asm_memchr('?') должна вернуть null");
    assert(asm_memchr(&buf, '!', 7) == null, "asm_memchr ищет только в первых n байтах");
    assert(asm_memchr(&buf, 'f', 0) == null, "asm_memchr(n = 0) должна вернуть null");
    io::printfn("len=%d %d colon_at=%d", asm_strlen_scas(""), asm_strlen_scas("assembly"), hit - (char*)&buf);
}
