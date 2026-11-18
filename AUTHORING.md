# Guide for c3lings exercise authors

This file is for people writing exercises. Learners don't need it.

## Target version

The course targets **c3c 0.8.5** (`./.c3c/c3/c3c`, installed with `tools/get-c3c.sh`).
Language reference: `./.c3c/c3/MANUAL.md` (17k lines, grep for headings),
standard library sources: `./.c3c/c3/lib/std/`, change history: `./.c3c/c3/releasenotes.md`.

C3 changes quickly, and much of what you remember about it may be out of date.
**Never use a construct without checking it with the compiler first.** Experiment in a separate
temporary directory, not in the course directory.

## Layout

```
exercises/NNN_name.c3            language exercise (or a directory NNN_name/ with several .c3 files)
engine/exercises/eCCNN_name.c3   engine exercise (CC = chapter number, NN = number within the chapter)
engine/docs/CC_topic.md          engine theory chapter
asm/exercises/aCCNN_name/        assembly exercise: a directory with a .c3 driver and .s files
asm/docs/CC_topic.md             assembly theory chapter
solutions/<name>.c3              reference solution (or a directory)
checks/<name>.out                exact expected stdout (required unless mode=test)
checks/<name>.flags              (optional) extra compiler flags on one line, e.g. `-D DEBUG_DRAW`
checks/<name>.mode               (optional) `test` — the exercise runs via `c3c compile-test`,
                                 success = all @test functions pass; no .out needed then
checks/<name>.in                 (optional) stdin for the program
hints/<name>.md                  hint, shown by `./c3lings hint N`
```

`<name>` is the file name without `.c3`, e.g. `001_hello` or `e0301_vec_math`.

## How the runner checks

1. `*.s`/`*.S` files in the exercise directory are assembled with `cc -c -g` into `.build/`, then
   `c3c compile -q <flags> -o .build/<name> <all .c3 files> <object files>`.
2. The program runs with a 10 s timeout, stdin = `/dev/null` (or `.in`), working directory `.build/`.
3. The exit code must be 0 and stdout must match `.out` (trailing whitespace on lines is ignored).

`./c3lings verify <prefix>` checks for each exercise that the solution PASSES and the
exercise as shipped does NOT pass. Every exercise you write must report `ok`.

## Exercise requirements

* All teaching content is in **English**. Code identifiers and program output are ASCII.
* The header comment is the textbook. Explain the concept properly: syntax, semantics, differences from C, pitfalls, why it matters. Friendly tone, like ziglings/rustlings. End the header with a `TASK:` block that says what to do (and, if useful, what the program should print).
* Header format — as in `exercises/001_hello.c3`:
  ```
  // =====================================================================
  //  NNN · Title
  // =====================================================================
  //
  //  ...explanation...
  //
  //  TASK: ...
  //
  ```
* The exercise must break exactly where the concept being taught is tested. Mark the places to fix, e.g. with `???` (a syntax hole), `// TODO` or `// <- something is wrong`. The learner should not have to fix unrelated things.
* Early exercises are small (1–3 fixes). Towards the end, "implement this function body", "write a macro", "finish the system" is fine. Difficulty rises monotonically.
* The solution is a copy of the exercise with the fixes applied (comments can stay as they are).
* Output is **deterministic**: no addresses, time, randomness without a fixed seed, hash map iteration order (sort before printing), or races between threads.
* Prefer programs that check themselves with `assert(...)` and print a clear result. A wrong answer => either a failed assert or an output mismatch.
* Don't write files outside the current working directory (that is `.build/`). No network. No external libraries except the standard library (and libc).
* Use only stdout for expected output (stderr is not checked).
* Hint in `hints/<name>.md`: 2–8 lines that point the way without giving away the whole solution at once (you can end with "If you are really stuck: …").
* File names: `NNN_snake_case.c3`, English, short.

## Verified on 0.8.5 (important differences from older C3 versions)

* Errors: `excuse MY_ERROR;` (formerly `faultdef`), return with `return MY_ERROR~;`, result type `int?`. Printing a fault with `%s` gives `module::MY_ERROR`.
* `sz` is the signed size type (formerly `isz`), `usz` the unsigned one. `.len` of arrays and slices is also `sz` (signed).
* Type properties use `::` — `Foo::size`, `Foo::alignment`, `Foo::members`, `Enum::values`, `Enum::names`, `Enum::len`, `Enum::from_ordinal(i)`. The old `int.sizeof` is gone. `$sizeof/$nameof/...` are gone (use `$reflect(x).size` etc.).
* `$Typeof(x)`, `$Typefrom(...)` (capitalized).
* `alias` is a synonym (replacing the old `def`); `typedef Meters = int;` is a new distinct type (implicit `int -> Meters` is not allowed: `(Meters)5`). `typedef Foo = int @inline`/`inline` — see the manual.
* `constset Color : int { RED = 1, GREEN = 2 }` — a set of constants.
* Generics: `struct Stack <Type> { ... }`, a function `fn Type my_max(Type a, Type b) <Type> => ...;` (parameters AFTER the argument list), called only with explicit parameters: `my_max{int}(3, 7)`. Type: `Stack{int}`, `alias IntStack = Stack{int};`. Module: `module foo <Type>;`.
* Lambdas: `alias IntFn = fn int(int); IntFn f = fn int(int x) => x * 2;` or `apply(x, fn (i) => i * i)` with the type inferred from context. They don't capture variables.
* Macros: `macro @twice(#e) { #e; #e; }`; variadic: `$vaarg.len`, `$vaarg[$i]`, `...$vaarg`. Compile time: `$for var $i = 0; $i < N; $i++: ... $endfor`, `$foreach $f : Foo::members: ... $endforeach`, `$if ...: ... $else ... $endif`.
* Struct names cannot be all uppercase (`struct P` is an error).
* Methods: `fn double Sq.area(&self)`, `fn int Foo.get(self)`. Interfaces: `interface Shape { fn double area(); }`, `struct Sq (Shape) {...}`, implementation marked `@dynamic`.
* Containers: `import std::collections::list, std::collections::map;` `List{int} l; l.push(1); defer l.free();` `HashMap{String,int} m; m.init(mem); m.set("a",1); m.get("a")` returns an Optional.
* Memory: `mem::new(Foo, {..})`, `mem::new_array(int, n)`, `free(p)`; the heap allocator is `mem`, the temporary one `tmem`; `@pool() { ... };` is a temporary arena; `string::tformat("%d", x)`.
* Threads: `import std::thread;` `Thread t; t.create(fn int(void* arg) {...}, null)!!; t.join()!!;` `Atomic{int} a; a.add(3); a.load();` (import std::atomic).
* Vectors: `int[<4>] v = {1,2,3,4}; v.sum(); v.xy * 2;` print as `[<2, 4>]`.
* `io::printn(double)` prints `4.000000`; use `io::printfn("%.2f", x)` to control the format.
* `io::printfn("%s", struct)` for structs without `to_format` prints an address — don't use it in expected output.
* Explicitly discarding an Optional result: `(void)foo();`.

* `$assert cond : "msg";` — the separator is a colon (the comma form from MANUAL.md doesn't compile). `$assert(cond);` also works.
* `@const` is only allowed on macros. A compile-time hash: `macro uint @h(String $s) @const { var $h = 2166136261u; $for var $i = 0; $i < $s.len; $i++: $h = ($h ^ $s[$i]) * 16777619u; $endfor return $h; }` — usable in `const` and `case` labels. The built-in `@str_hash` uses a different hash.
* Elements of a `const String[*]` can be indexed inside `$for` (`NAMES[$i]`).
* `List.len()` returns `sz` (signed); `&list[i]` dangles after `push`. An index expression `list[a + b]` needs `(sz)`.
* An int expression doesn't implicitly convert to a `float` parameter (`f(10 + k)` is an error, `f(k)` is fine).
* If an `if` has an `else`, both branches must use braces.
* `%s` prints the name of an enum value.
* `String.tsplit("\n", skip_empty: true)` inside `@pool()`; parsing a number: `s.to_int() ?? 0`.

* `@assert_leak() { ... };` — built-in leak checking (in safe mode it prints a report and exits with code 132).
* After leaving `@pool`, memory is filled with `0xAA` bytes in safe mode — use-after-pool deterministically prints garbage.
* `DString.append(42)` appends the character `'*'`, not digits — use `appendf("%d", x)`.
* `DString`/`List`/`HashMap` without `init` use `tmem` on the first write.
* `HashMap` copies `String` keys; `get`, `[]`, `pop()` return Optionals; sort keys (`tkeys()`) before printing.
* `io::fprintfn` flushes after every line, `fprintf`/`File.write` don't.
* `String.tokenize(" \n")` splits on the whole substring, not on a set of characters.
* `string::bformat` panics when the buffer is too small (`BUFFER_EXCEEDED`).
* `typeid` at run time: has `.size`, `.kind`; `.name` only at compile time. `String` has kind `TYPEDEF`. `(int)anyval` is an error, use `*(int*)anyval`.
* In a type switch a subtype matches its parent's `case` — put the most specific type first.
* `io::printn(struct)` prints `{ x: 1, y: 2 }`, while `printfn("%s", struct)` prints an address. `to_format` on a type declared `(Printable)` must be `@dynamic`.
* `==` on a struct without an overload is a compile error. With `==` and `<` overloaded, all comparisons and `quicksort` without a comparator are available.
* Calling a missing `@optional` interface method panics — check with `if (&s.method)`.
* A sort comparator returns an integer (not `bool`); a `List` is passed as `quicksort(&list)`; `quicksort` is unstable, `mergesort` is stable; `binarysearch` returns the insertion index.
* `double d = a / b;` with ints is an error, write `(double)a / b`.
* `math::sign` only takes integers; `math::sqr(5)` is a double; `math::round(-2.5)` = -3.
* `var` outside macros is an error (except declarations with `@safeinfer`).
* `alloc::new_array(allocator, T, n)` / `alloc::free(allocator, p)` are the explicit-allocator forms. `map.@each(; String k, int v) { ... };` works.

* An Optional argument makes the whole call Optional: `(void)io::printfn("%d", opt);` (prints nothing when empty). `@ok(x)` doesn't narrow the type; `@catch(x) == 0` is an error.
* An empty fault prints as `(empty-fault)`. Without a `module` line, the module name is the file name (`033_rethrow::WRONG_KEY`).
* Built-in faults: `NOT_FOUND`, `NO_MORE_ELEMENT`, `TYPE_MISMATCH`, `CAPACITY_EXCEEDED`, `NOT_IMPLEMENTED`, `TIMEOUT`. `to_int()`: `string::EMPTY_STRING`/`MALFORMED_INTEGER`/`INTEGER_OVERFLOW`.
* `defer catch` in a non-optional function compiles and never runs.
* `@local` is scoped to the module section, not the file.
* A `typedef` allows arithmetic with literals, but comparing with a literal is an error (needs a cast or `inline`).
* A function pointer type can't be written inline in a field/parameter — only through `alias`. A function as a value — only `&f`.
* `//` comments are not allowed inside `<* *>`. Violating `@require` with a constant argument is a compile error.
* Vectors: `<`/`>` are errors (`.comp_gt(v)`), `==` yields a single `bool`.
* `foreach (v : arr) v.x = 0;` silently modifies a copy. `int[W][H]` is H rows of W.
* `enum Foo { A = 200 }` gives a confusing error; use `constset`.
* `@init(N)`: lower N runs earlier. `int...` takes an array only via `...arr`; `any...` needs pointers.
* `printf` arguments are checked at compile time; `%x` of `-1` prints `-1`; `%b` is binary; a `char` via `%s`/`%d` prints a number, use `%c`.

* A generic type parameter can't be named `T` or `A` (all caps = constant parameter) — use `Type`, `Elem`.
* Generics in a module are grouped by parameter names: `Box{String}` also instantiates `my_max{String}` if both use `<Type>`.
* Methods on generic types are written without `<Type>`; a method for one instantiation — `fn int Stack{int}.sum(&self)`.
* Violating a generic `@require` is always a hard error; `$assignable` is gone (use `$defined(Type x = 1)`).
* The macro `macro @show(#e) => io::printfn(...)` returns `sz?` — write `macro void @show(#e) { ...; }`.
* Type properties only via `::`: `$Typeof(x)::name`, `Dir::from_ordinal(i)`; typeid — `int::typeid`. `Dir::len` in arithmetic needs a cast.
* `return` inside a `@body` block returns from the enclosing function; `break` there is an error.
* A misaligned field of a `@packed` struct passed to printf panics in safe mode — copy it into a local first.
* `$echo` prints to the compiler output with a `c3c:` prefix. Compile-time arrays: `$t = $t +++ elem;`.

* `-D` takes names only (`-D NAME=3` is an error). At the top level: `@feat(A | !B)`, `alias T = $feat(X) ? double : float;`.
* `$$` builtins in user code produce a warning — use std::bits methods (`x.popcount()`, `clz()`, `rotl(n)`).
* `@test` takes no arguments; tests run under a tracking allocator (a leak = a failure). `compile-test` creates `out/` and `build/` inside `.build/`.
* Safe mode (the default) panics with code 132 on: out of bounds, null, division by zero, shift ≥ width, `@require`, `!!` on an error. Integer overflow wraps without a panic.
* C3 inline assembly: list the instructions with `c3c compile --list-asm file.c3`. Mnemonics take AT&T suffixes, operands are in Intel order. popcnt/lzcnt/tzcnt/BMI/crc32/syscall/cmov* exist; and, shl/shr/sar, imul, cmp, test, lea, setcc, jumps, `lock` and fences don't (so `xaddl` in an asm block is not atomic).
* `io::print`/`printf` don't flush stdout — call `(void)io::stdout().flush();` before a raw `write` syscall.
* Dereferencing a misaligned `ulong*` panics in safe mode — use `mem::load(ptr, 1)`. A function's address: `(char*)(void*)&fn`.
* ICE: `*(uint*)&char_array[0] = x;` — use `bitcast`.
* A C3 `String` passed to `%s` of a C variadic: for a substring use `s.zstr_tcopy()`.
* Atomics: `compare_exchange(&expected, desired, $succ, $fail)` → bool; orderings `RELAXED`/`ACQUIRE`/`RELEASE`; `tlocal` is thread-local.
* Channels: `channel::create_buffered{int}(mem, n)` (import std::thread::channel). ThreadPool: `init(mem, n)`, `add_task(fn void(void*), arg)`, `destroy()` waits for the tasks.
* Allocator: `acquire(sz, AllocInitType, sz)`, `resize(void*, sz, sz)`, `release(void*, bool)`, all `@dynamic`. `TrackingAllocator.print_report()` writes to stdout — use `fprint_report(io::stderr())!!`.
* `if (try a = f() && try b = g())` — two tries joined with `&&`; `x ?? ERR~!` replaces the error and rethrows.

* Calling a C3 function from assembly: `@export("name")` gives a plain C name (bare `@export` gives `module__fn`; without it the symbol is `module.fn`, and an unused function is dropped).
* `uint128` across the ABI is a register pair (rdi:rsi, result rdx:rax). A `String` argument arrives as ptr in rdi and len in rsi.
* Exit codes: assert — 132, segfault — 139 (with a backtrace down to the `.s` line), `div` fault — 136.
* `c3c --emit-asm` only produces AT&T; for Intel use `objdump -d -M intel`. Use `compile-only --emit-asm`.
* `.intel_syntax noprefix` must come before any instruction; in gdb — `set disassembly-flavor intel`.

* An untyped index in `foreach (i, x : arr)` is `sz`; for `usz` arithmetic write `foreach (usz i, ...)`. Allocation functions (`alloc::new_array`, `mem::realloc`, `mem::copy`) take `sz`.
* Mixed signed/unsigned comparisons and narrowing are errors; widening a mixed expression (`long x = a - b;` with ints) needs `(long)a - b`.
* A type name made of capitals and digits (`alias R4 = ...`) is treated as a constant — write `Ring4`.
* A global array with a literal initializer must be `const` (`const ZString[*] X = {...}`).
* Enum values are not inferred inside an array index: `arr[AssetType.TEXTURE]`.
* Constants, globals and macros from another module need a prefix (`core::@zone(...)`), types don't.
* `float[<4>]` inside a struct is 4-aligned; `typedef X = float[<4>] @simd` is 16-aligned. Tiny negative numbers print as `-0.000` — add `+ 0.0f` or round.
* `continue` inside a macro's trailing block is not allowed. In stubs, put `assert(p != null)` before dereferencing, otherwise you get a segfault (139) instead of a clear failure.
* `excuse { A, B }` is the block form. `c3c dynamic-lib -o libgame a.c3` produces `libgame.so`; `dlsym` needs `@export("name")`. `os::dlopen`/`os::dlsym`/`DylibHandle.close()` work.
* `mem::new` rejects types with `@align` above 16 — use `mem::new_aligned(T)` / `free_aligned(p)`.

If you discover something else non-obvious, add it here.
