# c3lings

**AI GENERATED**

A course in the style of [ziglings](https://codeberg.org/ziglings/exercises) and [rustlings](https://rustlings.rust-lang.org/):
hundreds of small broken programs for you to fix. It takes you from "Hello, world" in
[C3](https://c3-lang.org) to the point where you write game engines yourself.

> A Russian version of the course lives in the [`russian`](../../tree/russian) branch.

The three tracks are done in order:

1. **The C3 language** (`exercises/`, 125 exercises): from the basics to generics, macros, reflection,
   allocators, multithreading and expert topics: virtual machines, lock-free code, serialization.
2. **x86-64 assembly** (`asm/`): registers, the ABI, the stack, SIMD/AVX2, system calls, atomics,
   performance, and a JIT compiler as the finale.
3. **Game engine architecture** (`engine/`): the game loop, memory, ECS, rendering, physics,
   job systems, resources, scripting, networking, tools, and a final mini engine.

The full syllabus is in [CURRICULUM.md](CURRICULUM.md).

## Installation

The course targets **c3c 0.8.5**. The language changes quickly and distro repositories often ship
an old version (Arch `extra` has 0.7.x), so the easiest way is to install the compiler into the project:

```sh
./tools/get-c3c.sh        # downloads c3c 0.8.5 into ./.c3c — the runner picks it up automatically
```

You also need a system C compiler (`gcc` or `clang`): C3 uses it for linking, and the assembly
track uses it to build `.s` files.

To use your own c3c, point the runner at it: `C3C=/path/to/c3c ./c3lings`.

## How to work through it

```sh
./c3lings            # check everything in order and show the first unsolved exercise
./c3lings watch      # same, but re-check automatically on every save
./c3lings hint 042   # show a hint
./c3lings run 042    # build and run a single exercise
./c3lings list       # list exercises and their status
```

The workflow:

1. Run `./c3lings watch` in one terminal.
2. Open the file it points to. **The header comment is the textbook**: read all of it.
3. Fix the program so that it compiles and prints what is expected.
4. Save the file: the runner moves on to the next exercise.

In the assembly and engine tracks every chapter starts with theory in `asm/docs/` and `engine/docs/`.
Read the chapter **before** its exercises.

Reference solutions are in `solutions/`. Look only after you have solved it yourself
(or have been stuck for a long time): comparing your version with the reference is useful.

To restart an exercise, keep the course in git: `git checkout -- exercises/042_*`.

## Useful links

* Language reference for your compiler version: `.c3c/c3/MANUAL.md`
* Standard library sources: `.c3c/c3/lib/std/` (the best textbook of idiomatic C3)
* Language website: https://c3-lang.org, the community Discord is linked there

## Layout

```
c3lings              the runner
exercises/           track 1: the language
asm/docs, asm/exercises         track 2: assembly
engine/docs, engine/exercises   track 3: engines
solutions/           reference solutions
checks/              expected output (do not edit)
hints/               hints
tools/get-c3c.sh     compiler installer
AUTHORING.md         for exercise authors
```
