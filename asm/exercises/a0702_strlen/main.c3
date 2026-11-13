// Тестовый стенд упражнения a0702. НЕ редактируйте этот файл — правьте strlen.s.
import std::io;

extern fn usz asm_strlen(ZString s);
extern fn int asm_streq(ZString a, ZString b);

fn void main()
{
    assert(asm_strlen("") == 0, "asm_strlen(\"\") = %d", asm_strlen(""));
    assert(asm_strlen("a") == 1, "asm_strlen(\"a\") = %d", asm_strlen("a"));
    assert(asm_strlen("hello, world") == 12, "asm_strlen(\"hello, world\") = %d", asm_strlen("hello, world"));
    assert(asm_streq("abc", "abc") == 1, "streq(abc, abc)");
    assert(asm_streq("abc", "abd") == 0, "streq(abc, abd)");
    assert(asm_streq("abc", "ab") == 0, "streq(abc, ab)");
    assert(asm_streq("ab", "abc") == 0, "streq(ab, abc)");
    assert(asm_streq("", "") == 1, "streq(\"\", \"\")");
    io::printfn("len=%d %d eq=%d %d %d", asm_strlen(""), asm_strlen("hello, world"),
                asm_streq("abc", "abc"), asm_streq("abc", "ab"), asm_streq("", ""));
}
