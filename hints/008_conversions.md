1. You need to widen BEFORE the addition, otherwise the int will overflow: `(long)a + b`.
   Try `(long)(a + b)` — the assert will show you why that's wrong.
2. A change of signedness is written explicitly: `(uint)n`.
3. Dropping the fractional part is explicit too: `(int)price`.
