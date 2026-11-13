`foreach (name : CANDIDATES)`: `DylibHandle lib = os::dlopen(name, { .resolve_now = true });`
если `!lib` — `continue`. Затем `void* c = os::dlsym(lib, "cos");` и то же для "sqrt".
Если хоть один null — `lib.close(); continue;`. Иначе сохраните lib и `(UnaryFn)c`, `(UnaryFn)s`
в self и верните true. После цикла — false.
