1. `h` is a copy of the element. Take the element by reference: `foreach (&h : hp)`,
   and modify `*h` inside the loop.
2. The index is declared before the value, separated by a comma: `foreach (i, name : names)`.
3. To iterate from the end there is `foreach_r`.
