// =====================================================================
//  117 · Конечные автоматы, `nextcase`, jump-таблицы `@jump`
// =====================================================================
//
//  Конечный автомат (FSM) — набор состояний и переходов по событиям.
//  Это самый недооценённый инструмент архитектуры: ИИ врагов, анимации
//  (animation state machine в любом движке), UI-экраны, сетевые
//  протоколы (TCP — это FSM), лексеры и парсеры форматов, регулярки.
//  Вместо россыпи флагов `is_jumping && !is_attacking && was_hit` — одно
//  явное состояние, и все допустимые переходы видны в одном месте.
//
//  СПОСОБЫ РЕАЛИЗАЦИИ
//  ------------------
//  1. Табличный (table-driven): `next = table[state][class(input)]`.
//     Данные вместо кода: таблицу можно сгенерировать (lex, re2c,
//     Ragel), загрузить из файла, нарисовать в редакторе. Цикл обработки
//     — три строки без ветвлений, предсказуемая скорость. Нужна функция
//     классификации входа, чтобы таблица не была 256 столбцов шириной.
//  2. switch внутри цикла: `while (...) switch (state) { ... state = X; }`.
//     Гибко: в каждом состоянии произвольный код и действия.
//     Минус — один общий косвенный переход на всё: предсказателю
//     ветвлений тяжело.
//  3. «Прямые переходы» (direct threading): из конца одного
//     обработчика сразу прыгаем в следующий. В C — computed goto
//     (расширение GCC), так написаны CPython, LuaJIT-интерпретатор, re2c.
//     В C3 это штатная конструкция: `switch (...) @jump` + `nextcase X;`.
//  4. State pattern (объект на состояние, виртуальные on_enter/
//     on_update/on_exit) — для игровой логики, где состояния
//     «толстые»; иерархические автоматы (HFSM) и statecharts —
//     когда состояний становится слишком много.
//
//  NEXTCASE В C3
//  -------------
//      switch (State.START) @jump
//      {
//          case START:
//              ...
//              nextcase IN_WORD;       // прыжок прямо в другую ветку
//          case IN_WORD:
//              ...
//              nextcase;               // без аргумента — в следующую по тексту
//      }
//  ВНИМАНИЕ: внутри ВЛОЖЕННОГО switch (например, по символу) голый
//  `nextcase X` относится к внутреннему switch! Пометьте внешний меткой
//  и прыгайте явно:  `switch FSM: (State.START) @jump { ... nextcase FSM: IN_WORD; }`.
//  `nextcase` может принимать и значение, вычисленное во время
//  исполнения. С `@jump` switch гарантированно компилируется в таблицу
//  переходов, и каждый nextcase — отдельный косвенный переход (как
//  computed goto). Цикла вообще нет: «цикл» — это прыжки между ветками.
//  `break` выходит из всего switch — это и есть конец автомата.
//
//  ПОДВОДНЫЕ КАМНИ
//  ---------------
//  * Не забыть обработать конец входа в КАЖДОМ состоянии (что значит
//    EOF посреди кавычек? — ошибка, а посреди обычного поля — конец
//    поля).
//  * Действия на переходе (Mealy) против действий в состоянии (Moore):
//    будьте последовательны, иначе символ обработается дважды или
//    потеряется.
//  * Состояние ERROR как «поглощающее» (из него нет выхода) упрощает
//    табличные автоматы: не нужны проверки внутри цикла. Если сделать
//    его нулевым элементом enum, zero-init таблица уже заполнена им.
//
//  ЗАДАЧА:
//    1. Заполните таблицу переходов DFA для чисел в формате JSON:
//         -?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?
//       в функции build_number_table().
//    2. Реализуйте parse_csv — автомат на `switch @jump` + `nextcase`
//       (RFC 4180: поля через запятую, строки через \n, поле в кавычках
//       может содержать запятые и переводы строк, `""` внутри кавычек —
//       это одна кавычка).
//
import std::io;

// ================================================================ 1. табличный DFA

enum NumState : char
{
    ERROR,       // поглощающее; нулевое => zero-init таблица уже «всё ошибка»
    START,       // ничего не прочитано
    SIGN,        // прочитан '-'
    ZERO,        // целая часть "0"  (принимающее)
    INT,         // целая часть [1-9][0-9]*  (принимающее)
    DOT,         // после '.'
    FRAC,        // дробные цифры (принимающее)
    EXP,         // после e/E
    EXP_SIGN,    // после e+ / e-
    EXP_INT,     // цифры порядка (принимающее)
}

enum CharClass : char { OTHER, ZERO, DIGIT19, MINUS, PLUS, DOT, EXP }

fn CharClass classify(char c)
{
    switch (c)
    {
        case '0': return ZERO;
        case '1'..'9': return DIGIT19;
        case '-': return MINUS;
        case '+': return PLUS;
        case '.': return DOT;
        case 'e':
        case 'E': return EXP;
        default: return OTHER;
    }
}

NumState[CharClass::len][NumState::len] number_table;

macro void @on(NumState $from, CharClass $cls, NumState $to)
{
    number_table[$from.ordinal][$cls.ordinal] = $to;
}

fn void build_number_table()
{
    // TODO: опишите все переходы через @on(ИЗ, КЛАСС, В).
    //       Всё неописанное остаётся ERROR. Пример: @on(START, MINUS, SIGN);
}

fn bool is_json_number(String s)
{
    NumState st = START;
    foreach (c : s) st = number_table[st.ordinal][classify(c).ordinal];
    switch (st)
    {
        case ZERO:
        case INT:
        case FRAC:
        case EXP_INT: return true;
        default: return false;
    }
}

// ================================================================ 2. CSV на nextcase

excuse UNTERMINATED_QUOTE, STRAY_QUOTE;

enum CsvState : char { FIELD_START, UNQUOTED, QUOTED, QUOTE_IN_QUOTED }

// Результат в наглядном виде: каждое поле "[...]", конец строки — '\n'.
// Пустой вход — ноль строк. Завершающий '\n' в конце не создаёт пустую строку.
// Пример: "a,\"b,c\"\n\"x\"\"y\"," -> "[a][b,c]\n[x\"y][]\n"
fn String? parse_csv(String src)
{
    DString out = dstring::temp();
    sz i = 0;
    bool after_comma = false;  // последним разобранным символом была запятая-разделитель?
    // TODO: switch CSV: (CsvState.FIELD_START) @jump { case ...: ... nextcase CSV: QUOTED; }
    //  FIELD_START: конец входа -> если перед ним была запятая, это ещё одно
    //               пустое поле: "[]\n"; затем break.
    //               '"' -> QUOTED; ',' -> пустое поле; '\n' -> пустое поле + конец строки;
    //               иначе — символ -> UNQUOTED.
    //  Каждая запятая-разделитель ставит after_comma = true, каждый '\n' — false.
    //  UNQUOTED:    копить символы до ',', '\n' или конца; '"' здесь — STRAY_QUOTE~.
    //  QUOTED:      конец входа — UNTERMINATED_QUOTE~; '"' -> QUOTE_IN_QUOTED; иначе копить.
    //  QUOTE_IN_QUOTED: '"' -> добавить кавычку, назад в QUOTED; ',' / '\n' / конец —
    //               поле закончено; любой другой символ — STRAY_QUOTE~.
    //  Удобно: out.append('[') при входе в поле и out.append(']') при выходе.
    return out.str_view();
}

// ================================================================ проверка

fn void main()
{
    build_number_table();
    String[*] good = { "0", "-0", "7", "12", "3.14", "-2.5e10", "1E+3", "0.0e-0", "10e01" };
    String[*] bad = { "", "-", "01", "1.", ".5", "1e", "1e+", "+1", "1.2.3", "--1", "1a", "0x10", "1e2.5" };
    foreach (s : good) assert(is_json_number(s), "'%s' must be a valid number", s);
    foreach (s : bad) assert(!is_json_number(s), "'%s' must be rejected", s);
    io::printfn("json numbers: %d accepted, %d rejected", good.len, bad.len);

    @pool()
    {
        String[*] inputs = {
            "a,b,c\n1,2,3\n",
            "a,\"b,c\"\n\"x\"\"y\",",
            "name,quote\nbob,\"multi\nline\"\n,\n",
            "",
            "single",
            "\"\"",
        };
        String[*] expected = {
            "[a][b][c]\n[1][2][3]\n",
            "[a][b,c]\n[x\"y][]\n",
            "[name][quote]\n[bob][multi\nline]\n[][]\n",
            "",
            "[single]\n",
            "[]\n",
        };
        foreach (k, s : inputs)
        {
            String got = parse_csv(s)!!;
            assert(got == expected[k], "csv #%d:\n got: %s\nwant: %s", k, got, expected[k]);
        }
        io::printf("csv sample:\n%s", parse_csv(inputs[2])!!);
        assert(@catch(parse_csv("a,\"open")) == UNTERMINATED_QUOTE);
        assert(@catch(parse_csv("ab\"c")) == STRAY_QUOTE);
        assert(@catch(parse_csv("\"ab\"c")) == STRAY_QUOTE);
    };
    io::printn("state machines OK");
}
