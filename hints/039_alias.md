1. A function pointer type is a function declaration without a name: `fn RETURN(PARAMETERS)`.
2. A function synonym is declared just like a type synonym: `alias name = module::function;`
   (the name starts with a lowercase letter).
3. To pass a function as a value, take its address with the `&` operator.
