Таблица: идите по регулярке слева направо. START: `-`→SIGN, `0`→ZERO, `1-9`→INT; SIGN — то же без минуса;
INT: цифры→INT; ZERO и INT: `.`→DOT, `e`→EXP; DOT: цифра→FRAC; FRAC: цифра→FRAC, `e`→EXP;
EXP: `+`/`-`→EXP_SIGN, цифра→EXP_INT; EXP_SIGN и EXP_INT: цифра→EXP_INT. Из ZERO по цифре — никуда (ERROR).
CSV: пометьте внешний switch меткой — `switch CSV: (CsvState.FIELD_START) @jump` — иначе `nextcase`
внутри вложенного `switch (c)` прыгнет по ВНУТРЕННЕМУ switch. Переходы: `nextcase CSV: QUOTED;`.
В каждом состоянии первым делом проверяйте `i >= src.len`. Выход из автомата — `break` на уровне внешнего case.
