1. The built-in "element not in the collection" error is `NOT_FOUND` (no prefix, it's `@builtin`). Don't forget the `~`.
2. `EMPTY_STRING` is declared in the `string` module, so from outside it's written `string::EMPTY_STRING`.
3. A zero (empty) `fault` means "no error" and behaves like `false` in a condition.
   The condition should be true when there is NO error.
