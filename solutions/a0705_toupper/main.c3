// Тестовый стенд упражнения a0705. НЕ редактируйте этот файл — правьте toupper.s.
import std::io;

extern fn usz asm_toupper(char* s);
extern fn usz asm_count_words(ZString s);

fn void main()
{
    char[32] buf = "Hello, asm World! z{a`@[";
    usz changed = asm_toupper(&buf);
    ZString up = (ZString)&buf;
    io::printfn("%s changed=%d", up, changed);
    assert(changed == 13, "asm_toupper вернула %d", changed);
    char[1] empty = { 0 };
    assert(asm_toupper(&empty) == 0, "asm_toupper(\"\")");
    assert(asm_count_words("") == 0, "count_words(\"\")");
    assert(asm_count_words("   ") == 0, "count_words(\"   \")");
    assert(asm_count_words("one") == 1, "count_words(\"one\")");
    assert(asm_count_words("  two  words ") == 2, "count_words(\"  two  words \")");
    io::printfn("words=%d", asm_count_words("the quick  brown fox "));
}
