1. `int a, b = 4;` is forbidden — declare `apples` and `pears` on two separate lines.
2. `var` without `@safeinfer` only works in macros. Just write the type `int`.
3. The line `int score = ...` inside the block declares a NEW variable (that's shadowing,
   and it's forbidden). Remove the type so it becomes an assignment to the outer `score`.
