// Тестовый стенд упражнения a0101. НЕ редактируйте этот файл —
// правьте answer.s. Стенд вызывает вашу ассемблерную функцию и проверяет ответ.
import std::io;

extern fn int asm_answer();

fn void main()
{
    int r = asm_answer();
    assert(r == 42, "asm_answer() вернула %d, а должна 42", r);
    io::printfn("asm_answer() = %d", r);
}
