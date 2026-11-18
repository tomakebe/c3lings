# Syllabus

The course has three tracks, done in order with a single command: `./c3lings`.

---

## Track 1. The C3 language (`exercises/`)

### Part I. Basics (001–030)
| # | Topic |
|---|---|
| 001 | Hello world, `main`, `import std::io` |
| 002 | Comments, `io::print`/`printn`/`printfn`, format specifiers |
| 003 | Variables, declarations, zero initialization by default, `var` |
| 004 | Fixed-size integer types (`ichar`…`int128`, `sz`/`usz`), literals, suffixes, `_` in numbers, hex/bin/oct |
| 005 | Floating-point numbers, literals, formatted printing |
| 006 | `bool`, `char`, character literals, escape sequences |
| 007 | `const` constants, compile-time evaluation |
| 008 | Implicit and explicit conversions, no signed↔unsigned mixing, narrowing |
| 009 | Operators and precedence (bitwise operators differ from C), shifts, `%`, overflow |
| 010 | `if`/`else`, the ternary operator, `?:` (elvis) |
| 011 | `while`, `do { } while`, a `do` block without `while` |
| 012 | `for` |
| 013 | `switch`: implicit `break`, multiple labels, empty cases |
| 014 | `switch`: `nextcase`, ranges `case 1..5`, `switch` without an expression |
| 015 | Labels, `break LABEL`, `continue LABEL` |
| 016 | Functions, parameters, return values, the short `=>` form |
| 017 | Default and named arguments |
| 018 | Recursion, no overloading, declaration order does not matter |
| 019 | Fixed-size arrays, value semantics (copying) |
| 020 | Slices `arr[1..3]`, `arr[1:2]`, `arr[^1]`, slices from pointers |
| 021 | `foreach`, index, by reference `&`, `foreach_r` |
| 022 | Strings: `String`, `ZString`, raw strings, comparison |
| 023 | Working with strings in the stdlib: searching, splitting, parsing numbers |
| 024 | Structs, positional and designated initialization, nesting |
| 025 | Methods, `self`, `&self`, dot calls |
| 026 | `enum`: ordinal, `values`, `names`, `from_ordinal`, `switch` on an enum |
| 027 | Enums with associated values, `lookup_field` |
| 028 | `union`, anonymous nested structs/unions |
| 029 | Pointers, `&`, `*`, `null`, field access with `.`, pointer arithmetic |
| 030 | `defer`, execution order |

### Part II. Intermediate (031–070)
| # | Topic |
|---|---|
| 031 | Optional `T?`, `excuse`, returning an error with `ERR~` |
| 032 | Unwrapping: `if (catch err = x)`, `if (try v = x)`, flow typing |
| 033 | Rethrow `!`, force unwrap `!!` |
| 034 | `??` (default value), calls with Optional arguments are skipped |
| 035 | `defer catch`, `defer try`, `defer (catch err)` |
| 036 | Built-in faults, `switch` on faults, fault descriptions |
| 037 | Modules and imports (a multi-file exercise) |
| 038 | Visibility: `@private`, `@local`, module sections |
| 039 | `alias`: aliases for types, functions and function pointers |
| 040 | `typedef`: distinct types, `inline` typedefs |
| 041 | Function pointers and lambdas |
| 042 | Contracts `@require`/`@ensure`, doc comments `<* *>` |
| 043 | `bitstruct` |
| 044 | SIMD vectors `int[<4>]`, swizzling, reductions |
| 045 | Compound literals, temporary addresses, copying structs |
| 046 | Multidimensional arrays |
| 047 | `constset` |
| 048 | Static initializers `@init`/`@finalizer`, `static` local variables |
| 049 | Variadic functions: typed `int...` and `any...` |
| 050 | Formatted output in detail |
| 051 | The heap: `malloc`/`free`, `mem::new`, `mem::new_array`, `defer free` |
| 052 | The temp allocator: `@pool`, `tmem`, `tformat` |
| 053 | The `Allocator` parameter, naming conventions (`new_*`, `t*`), memory ownership |
| 054 | `List{T}` |
| 055 | `HashMap{K, V}` |
| 056 | `DString` — building strings |
| 057 | Formatting into a string, `string::format`, `tformat` |
| 058 | `any`, `typeid`, `switch` on a type |
| 059 | Interfaces and `@dynamic` |
| 060 | Struct inheritance through an `inline` member (subtyping) |
| 061 | Overloading arithmetic operators |
| 062 | Overloading `[]`, `&[]`, `[]=`, `len` → `foreach` support |
| 063 | Overloading `==` and `<` |
| 064 | Custom printing: `to_format` |
| 065 | Files: writing, reading, handling I/O errors |
| 066 | `std::math` |
| 067 | Sorting, comparators |
| 068 | Iterating over your own types |
| 069 | `assert`, `unreachable`, panics, safe mode |
| 070 | Mini project: a word frequency counter |

### Part III. Advanced (071–105)
| # | Topic |
|---|---|
| 071 | Generic functions |
| 072 | Generic structs, `alias` for instantiations |
| 073 | Generic modules, how generics are grouped |
| 074 | Contracts on generic parameters |
| 075 | Methods on generic types |
| 076 | Macros: the basics |
| 077 | Lazy arguments `#expr`, `@` macros |
| 078 | Macros with a trailing `@body` block |
| 079 | Type parameters `$Type`, compile-time parameters |
| 080 | Variadic macros `$vaarg` |
| 081 | `$if`, `$switch` |
| 082 | `$for`, `$foreach` |
| 083 | `$defined`, `$assert`, `$error`, `$echo` |
| 084 | `$stringify`, `$eval`, `$Typeof`, `$Typefrom` |
| 085 | Compile-time computation |
| 086 | Reflection: fields, sizes, offsets |
| 087 | Reflecting on enums and methods |
| 088 | Reflection in practice: a generic struct dumper |
| 089 | Attributes: `@align`, `@packed`, `@nodiscard`, `@noinline`… |
| 090 | User-defined attributes and tags |
| 091 | Conditional compilation `@feat`/`$feat`, the `-D` flag |
| 092 | C interop: `extern fn`, `@cname`, callbacks |
| 093 | C interop: struct layout, `CInt`, C variadics |
| 094 | Builtins `$$…`, bit operations |
| 095 | Inline assembly |
| 096 | Threads |
| 097 | Mutexes and condition variables |
| 098 | Atomics, `compare_exchange` |
| 099 | Channels and thread pools |
| 100 | Unit tests `@test`, `c3c compile-test` |
| 101 | Safe and unchecked modes, bounds checks |
| 102 | Tracking memory leaks |
| 103 | A custom allocator implementing `Allocator` |
| 104 | Optionals in complex scenarios |
| 105 | Mini project: an expression calculator (lexer + recursive descent) |

### Part IV. Expert+ (106–125)
| # | Topic |
|---|---|
| 106 | Data-oriented design: AoS → SoA |
| 107 | SIMD in practice |
| 108 | A generic open-addressing hash map from scratch |
| 109 | Intrusive lists and macros |
| 110 | A generic slot map with generations (handles) |
| 111 | A generic ring buffer + `foreach` |
| 112 | A lock-free SPSC queue on atomics |
| 113 | String interning |
| 114 | A tree in an arena with indices instead of pointers |
| 115 | A bytecode virtual machine |
| 116 | An AST → bytecode compiler |
| 117 | State machines, `nextcase`, `@jump` jump tables |
| 118 | Bit tricks: bitsets, Morton codes |
| 119 | Formatting generic containers |
| 120 | A reflection-based binary serializer |
| 121 | Plugins: function tables and interfaces |
| 122 | Error-handling architecture in a layered system |
| 123 | API design: opaque handles, builders, modules |
| 124 | Memory layout: alignment, padding, cache lines |
| 125 | Final boss: a mini-Lisp interpreter |

---

## Track 2. x86-64 assembly (`asm/`)

Done after the language and before the engines. Platform: x86-64 Linux, System V ABI,
GNU as in Intel syntax (`.intel_syntax noprefix`). Each exercise is a directory with a `.c3` driver
that calls your functions from a `.s` file (the runner assembles them with `cc -c`).
Each chapter's theory is in `asm/docs/CC_*.md`, its exercises in `asm/exercises/aCCNN_*/`.

| Chapter | Topic |
|---|---|
| 00 | Introduction: how a CPU works, registers, memory, tools (`as`, `objdump`, `gdb`, `c3c --emit-asm`) |
| 01 | Registers and `mov`, your first function, returning a value per the System V ABI |
| 02 | Arithmetic: `add`/`sub`/`imul`/`div`, flags, signed and unsigned |
| 03 | Control flow: `cmp`/`test`, conditional jumps, loops |
| 04 | Memory addressing: arrays, `[base + index*scale + disp]`, `lea` |
| 05 | The System V calling convention: arguments, callee-saved registers, stack alignment, calling C3/libc from assembly |
| 06 | Stack frames, local variables, recursion |
| 07 | Structs, pointers, strings, string instructions (`rep movsb`, `scasb`) |
| 08 | Bit operations: shifts, rotations, `bt`, `popcnt`, `lzcnt`/`tzcnt`, BMI |
| 09 | Floating point: scalar SSE instructions |
| 10 | SIMD: SSE/AVX2, vectorizing loops |
| 11 | C3 inline assembly and reading compiler-generated code |
| 12 | Linux system calls directly, without libc |
| 13 | Branchless code (`cmov`, `setcc`), atomic operations (`lock`, `cmpxchg`), memory barriers |
| 14 | Performance: the pipeline, dependencies, loop unrolling, caches, how to measure |
| 15 | Finale: a JIT compiler — generating machine code into executable memory at run time |

---

## Track 3. Game engine architecture (`engine/`)

Each chapter is theory in `engine/docs/CC_*.md` (read it **before** the chapter's exercises) plus
exercises `engine/exercises/eCCNN_*.c3`.

| Chapter | Topic |
|---|---|
| 00 | Introduction: what an engine is made of, layers, runtime vs tools, how to read this part |
| 01 | The game loop: fixed timestep, the accumulator, interpolation, determinism |
| 02 | Memory: linear/stack/pool/frame allocators, memory budgets |
| 03 | Engine containers: handles, slot maps, sparse sets, reference stability |
| 04 | Math: vectors, matrices, quaternions, transforms, SIMD |
| 05 | ECS: archetypes vs sparse sets, queries, systems, scheduling |
| 06 | Events and messaging: queues, double buffering, observers |
| 07 | Resources and assets: the resource manager, reference counting, hot reload, the pipeline |
| 08 | The scene: transform hierarchies, dirty flags, spatial structures |
| 09 | Rendering: renderer architecture, command buffers, sort keys, a software rasterizer |
| 10 | Input: device abstraction, action mapping, buffering |
| 11 | Physics: integrators, collisions, broadphase, contact resolution |
| 12 | Multithreading: the job system, dependencies, parallel_for, the frame graph |
| 13 | Serialization and reflection: binary formats, versioning |
| 14 | Scripting: an embedded VM, bindings, hot-reloading logic |
| 15 | Profiling and debugging: instrumentation, debug draw, the console |
| 16 | Audio: mixing, the voice manager, generating WAV |
| 17 | Hot code reloading and plugins: dynamic libraries |
| 18 | Networking: lockstep, snapshot interpolation, delta compression, prediction |
| 19 | Tools and the editor: undo/redo, the command pattern, property systems |
| 20 | Final project: your own mini engine and game |
| 99 | What next: books, engine source code, how to keep growing |
