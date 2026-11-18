`foreach (name : CANDIDATES)`: `DylibHandle lib = os::dlopen(name, { .resolve_now = true });`
if `!lib` - `continue`. Then `void* c = os::dlsym(lib, "cos");` and the same for "sqrt".
If either is null - `lib.close(); continue;`. Otherwise store lib and `(UnaryFn)c`, `(UnaryFn)s`
in self and return true. After the loop - false.
