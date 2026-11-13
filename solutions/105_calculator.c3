// =====================================================================
//  105 · Мини-проект: калькулятор выражений
// =====================================================================
//
//  Финал части III. Собираем калькулятор целочисленных выражений:
//
//      "2 + 3 * (4 - 1) ^ 2"   ->   29
//
//  Классическая архитектура любого интерпретатора/компилятора:
//
//      текст --[лексер]--> токены --[парсер]--> значение (или AST)
//
//  Лексер (tokenizer)
//  ------------------
//  Превращает строку символов в список токенов: числа, операторы,
//  скобки. Пробелы пропускаются. Неизвестный символ — ошибка.
//  Лексер ничего не знает о приоритетах — только «слова».
//
//      "12*(3+4)"  ->  NUM(12) STAR LPAREN NUM(3) PLUS NUM(4) RPAREN END
//
//  Токен END в конце избавляет парсер от проверок «а не кончились ли
//  токены» — он просто видит END и понимает, что выражение закончилось.
//
//  Парсер: рекурсивный спуск
//  -------------------------
//  Грамматика с приоритетами (сверху — самый слабый оператор):
//
//      expr    := term   (('+' | '-') term)*
//      term    := power  (('*' | '/' | '%') power)*
//      power   := unary  ('^' power)?           <- правоассоциативен
//      unary   := '-' unary | primary
//      primary := NUMBER | '(' expr ')'
//
//  Каждому правилу соответствует функция. Правило вызывает правила
//  уровнем ниже (более сильные операторы), а `primary` замыкает круг,
//  вызывая `expr` для выражения в скобках — отсюда «рекурсивный».
//
//  Левая ассоциативность (`8 - 3 - 2 == 3`, а не 7) получается циклом:
//
//      long left = parse_term()!;
//      while (peek is '+' or '-')
//      {
//          advance();
//          long right = parse_term()!;
//          left = left +/- right;
//      }
//
//  Правая (`2 ^ 3 ^ 2 == 2 ^ 9 == 512`) — рекурсией: после '^'
//  вызываем parse_power снова. Обратите внимание: в нашей грамматике
//  унарный минус связывает СИЛЬНЕЕ '^' (power состоит из unary), так
//  что `-2 ^ 2` — это (-2)^2 = 4. В математике принято наоборот, но это
//  наш язык — главное, чтобы грамматика была однозначной и описанной.
//
//  Ошибки — через Optional: каждая parse-функция возвращает `long?`,
//  а `!` пробрасывает ошибку наверх по всей цепочке рекурсии. Вот где
//  Optional действительно экономит код: в C пришлось бы проверять код
//  возврата после каждого вызова.
//
//  Это та же техника, на которой написаны парсеры GCC, Clang, Go, Zig
//  и самого c3c — рукописный рекурсивный спуск, без генераторов.
//  В части IV из этого вырастет компилятор в байткод и интерпретатор Lisp.
//
//  ЗАДАЧА:
//    1. В tokenize допишите разбор чисел (последовательность цифр).
//    2. Реализуйте parse_term, parse_power, parse_unary, parse_primary
//       по грамматике выше (parse_expr уже написан — это образец).
//       Деление и остаток на ноль -> DIVISION_BY_ZERO; отрицательная
//       степень -> NEGATIVE_EXPONENT; ожидали ')' — EXPECTED_RPAREN;
//       ожидали число или '(' — UNEXPECTED_TOKEN.
//
//  Ожидаемый вывод:
//      1 + 2 = 3
//      2 + 3 * 4 = 14
//      (2 + 3) * 4 = 20
//      8 - 3 - 2 = 3
//      100 / 7 % 4 = 2
//      2 ^ 3 ^ 2 = 512
//      -2 ^ 2 = 4
//      -(3 - 10) * --2 = 14
//      2 * (3 + (4 - 1) * 2) ^ 2 = 162
//        42   = 42
//      1 / (2 - 2) -> calc::DIVISION_BY_ZERO
//      (1 + 2 -> calc::EXPECTED_RPAREN
//      1 + * 2 -> calc::UNEXPECTED_TOKEN
//      2 ^ -1 -> calc::NEGATIVE_EXPONENT
//      3 $ 4 -> calc::UNKNOWN_CHAR
//      1 2 -> calc::TRAILING_INPUT
//
module calc;
import std::io, std::collections::list;

excuse UNKNOWN_CHAR, UNEXPECTED_TOKEN, EXPECTED_RPAREN, TRAILING_INPUT,
       DIVISION_BY_ZERO, NEGATIVE_EXPONENT;

enum TokenKind
{
    NUMBER,
    PLUS,
    MINUS,
    STAR,
    SLASH,
    PERCENT,
    CARET,
    LPAREN,
    RPAREN,
    END,
}

struct Token
{
    TokenKind kind;
    long value;     // только для NUMBER
}

<*
 Разбить строку на токены. Список выделяется во временной памяти (tmem).
*>
fn List{Token}? tokenize(String src)
{
    List{Token} tokens;
    tokens.init(tmem);
    usz i = 0;
    while (i < src.len)
    {
        char c = src[i];
        switch (c)
        {
            case ' ':
            case '\t':
                i++;
            case '+': tokens.push({ PLUS, 0 }); i++;
            case '-': tokens.push({ MINUS, 0 }); i++;
            case '*': tokens.push({ STAR, 0 }); i++;
            case '/': tokens.push({ SLASH, 0 }); i++;
            case '%': tokens.push({ PERCENT, 0 }); i++;
            case '^': tokens.push({ CARET, 0 }); i++;
            case '(': tokens.push({ LPAREN, 0 }); i++;
            case ')': tokens.push({ RPAREN, 0 }); i++;
            case '0'..'9':
                // TODO: прочитайте все подряд идущие цифры, накопите
                //       значение и добавьте токен NUMBER.
                long value = 0;
                while (i < src.len && src[i] >= '0' && src[i] <= '9')
                {
                    value = value * 10 + (long)(src[i] - '0');
                    i++;
                }
                tokens.push({ NUMBER, value });
            default:
                return UNKNOWN_CHAR~;
        }
    }
    tokens.push({ END, 0 });
    return tokens;
}

struct Parser
{
    Token[] tokens;
    usz pos;
}

fn TokenKind Parser.peek(&self) => self.tokens[self.pos].kind;

fn Token Parser.advance(&self)
{
    Token t = self.tokens[self.pos];
    if (t.kind != END) self.pos++;
    return t;
}

// expr := term (('+' | '-') term)*
fn long? Parser.parse_expr(&self)
{
    long left = self.parse_term()!;
    while (self.peek() == PLUS || self.peek() == MINUS)
    {
        TokenKind op = self.advance().kind;
        long right = self.parse_term()!;
        left = op == PLUS ? left + right : left - right;
    }
    return left;
}

// term := power (('*' | '/' | '%') power)*
fn long? Parser.parse_term(&self)
{
    long left = self.parse_power()!;
    while (true)
    {
        TokenKind op = self.peek();
        if (op != STAR && op != SLASH && op != PERCENT) break;
        self.advance();
        long right = self.parse_power()!;
        switch (op)
        {
            case STAR:
                left *= right;
            default:
                if (right == 0) return DIVISION_BY_ZERO~;
                left = op == SLASH ? left / right : left % right;
        }
    }
    return left;
}

// power := unary ('^' power)?
fn long? Parser.parse_power(&self)
{
    long base = self.parse_unary()!;
    if (self.peek() != CARET) return base;
    self.advance();
    long exp = self.parse_power()!;
    if (exp < 0) return NEGATIVE_EXPONENT~;
    long result = 1;
    for (long i = 0; i < exp; i++) result *= base;
    return result;
}

// unary := '-' unary | primary
fn long? Parser.parse_unary(&self)
{
    if (self.peek() == MINUS)
    {
        self.advance();
        return -self.parse_unary()!;
    }
    return self.parse_primary();
}

// primary := NUMBER | '(' expr ')'
fn long? Parser.parse_primary(&self)
{
    Token t = self.advance();
    switch (t.kind)
    {
        case NUMBER:
            return t.value;
        case LPAREN:
            long inner = self.parse_expr()!;
            if (self.advance().kind != RPAREN) return EXPECTED_RPAREN~;
            return inner;
        default:
            return UNEXPECTED_TOKEN~;
    }
}

fn long? evaluate(String src)
{
    List{Token} tokens = tokenize(src)!;
    Parser p = { .tokens = tokens.array_view() };
    long value = p.parse_expr()!;
    if (p.peek() != END) return TRAILING_INPUT~;
    return value;
}

fn void main()
{
    String[] inputs = {
        "1 + 2",
        "2 + 3 * 4",
        "(2 + 3) * 4",
        "8 - 3 - 2",
        "100 / 7 % 4",
        "2 ^ 3 ^ 2",
        "-2 ^ 2",
        "-(3 - 10) * --2",
        "2 * (3 + (4 - 1) * 2) ^ 2",
        "  42  ",
        "1 / (2 - 2)",
        "(1 + 2",
        "1 + * 2",
        "2 ^ -1",
        "3 $ 4",
        "1 2",
    };
    foreach (src : inputs)
    {
        @pool()
        {
            long? v = evaluate(src);
            if (catch err = v)
            {
                io::printfn("%s -> %s", src, err);
            }
            else
            {
                io::printfn("%s = %d", src, v);
            }
        };
    }
}
