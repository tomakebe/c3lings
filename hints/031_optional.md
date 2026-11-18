Four fixes, all about Optionals:
1. A new error is declared at the top level: `excuse NAME;`.
2. A function that can return an error must have the result type `int?`, not `int`.
3. `NOT_A_DIGIT` without a suffix is just a value of type `fault`. You get an empty Optional with `~`.
4. A variable that receives an Optional must also be an Optional: `int? bad = ...`.
