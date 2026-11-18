1. Cast at least one operand to double BEFORE the division: `(double)sum / count`.
   `(double)(sum / count)` won't help — the division will already be an integer one.
2. The result of `distance / 2` is a double. Cast it to float explicitly: `(float)(...)`.
3. 1500 = 1.5 · 10³. In scientific notation that's `1.5e3`.
