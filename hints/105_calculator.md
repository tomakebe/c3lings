Числа: `long value = 0; while (i < src.len && src[i] >= '0' && src[i] <= '9') { value = value * 10 + (long)(src[i] - '0'); i++; }` и `tokens.push({ NUMBER, value });`.
parse_term устроен как parse_expr: цикл, пока peek() — STAR/SLASH/PERCENT; перед / и % проверьте правый операнд на ноль.
parse_power: `base = parse_unary()!`; если следующий токен CARET — advance и `exp = parse_power()!` (рекурсия = правая ассоциативность), потом степень циклом.
parse_unary: если MINUS — advance и `return -self.parse_unary()!;`, иначе `return self.parse_primary();`.
parse_primary: advance(); NUMBER -> t.value; LPAREN -> parse_expr()!, затем обязательно RPAREN (иначе EXPECTED_RPAREN); всё остальное — UNEXPECTED_TOKEN.
