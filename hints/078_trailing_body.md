Блок объявляется после `;` в списке параметров: `macro @repeat(int n; @body(int i))`.
Вставить блок — значит вызвать его: `@body();` или `@body(i, arr[i]);`.
Для `@each_even` нужен цикл `for (usz i = 0; i < arr.len; i += 2)`.
