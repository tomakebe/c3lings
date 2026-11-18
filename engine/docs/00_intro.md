# 00 · Introduction to Game Engine Architecture

The first track taught you a language. This track teaches something else: **how to design and write
a game engine** — not "how to use Unity", but how the layer of code that Unity, Unreal, Godot,
id Tech, Frostbite, Source and hundreds of in-house studio engines stand on is actually built.

The goal of the track is ambitious: by the last chapter you should be able to make
architectural decisions at the level of a senior/lead engine programmer on your own — to understand *why* engines
are built the way they are, what alternatives and costs every decision carries, and to be able to write
each subsystem from scratch in C3.

This chapter is a map of the terrain. It has no exercises, but it is worth reading in full:
later chapters will constantly refer back to the terms and diagrams introduced here.

---

## 1. What is a game engine

The most honest definition: **the engine is everything in a game's code that is not the specific
game.** If you strip the levels, characters, rules, dialogue and balancing out of the sources,
what remains is the engine: the frame loop, memory, math, rendering, physics, audio, input,
resource loading, serialization, networking, tools.

Jason Gregory, in "Game Engine Architecture", proposes a *data-driven* criterion: an engine is
a program whose behavior is determined mainly by data (assets, configs,
scripts) rather than by code. Pac-Man (1980) is not an engine: the ghosts, the maze and the rules are hardwired
into the code. Quake (1996) is an engine: a new game is made by replacing maps, models and QuakeC scripts,
which is why Half-Life, mods and an entire licensing industry grew out of it.

The boundary is always blurry. There is a spectrum:

```
  not reusable                                                      reusable
  <------------------------------------------------------------------------->
  Pac-Man   "single-game     in-house studio     genre engine      general-purpose
  (1980)     engine"         engine (id Tech,    (RPG Maker,       engine (Unity,
             (Celeste)       Decima, Northlight) GameMaker)        Unreal, Godot)
```

The further right, the more general the engine has to be, and the more expensive every decision becomes: Unreal cannot
assume that a game has 50 objects or that it is 2D. An in-house studio engine
can (and should!) exploit knowledge of its game. One of the central ideas of this track:
**generality is not free**. A good engine solves a *specific* problem,
and knowledge of that problem is the main source of performance (Mike Acton: "the purpose of all
programs is to transform data"; an engine that does not know what its data is cannot
transform it efficiently).

## 2. Runtime and tools

An engine is two large products that are often confused:

* **Runtime** — what runs on the player's machine: the frame loop, rendering, physics, audio, gameplay.
  Requirements: speed, predictability, a small memory footprint, running on consoles and phones.
* **Tools** — what developers use: the level editor, asset import,
  shader compilation, packaging, the profiler, debug consoles. Requirements: convenience,
  flexibility, robustness, iteration speed. Here you can spend gigabytes of memory and
  use "heavy" libraries.

Between them sits the **asset pipeline** (asset conditioning): source
files (`.psd`, `.fbx`, `.wav`, `.blend`) are turned into *runtime formats* optimized
for a specific platform: textures are compressed to BCn/ASTC, meshes are reordered for the
vertex cache, and everything is packed into archives that can be read with a single `read` and used
with almost no parsing (load-in-place).

```
  Artist/designer            TOOLS (developer PC)                    RUNTIME (player)
  ┌───────────────┐   ┌────────────────────────────────────┐   ┌────────────────────┐
  │ .fbx .png .wav│──>│ import -> processing -> packaging   │──>│ package loading    │
  │ levels, config│   │ (compression, LOD, shaders, valid.) │   │ without parsing,   │
  └───────────────┘   │ editor = same runtime + UI          │   │ fast formats       │
                      └────────────────────────────────────┘   └────────────────────┘
```

Note the line "editor = same runtime + UI". In Unreal and Unity the editor
*contains* the runtime: you press Play and the game launches inside the editor. In Bitsquid/
Stingray and in Our Machinery the editor was a separate process talking to the runtime over the network
— this keeps the runtime thinner and enables "live" editing on a console. Both approaches
are legitimate; we will return to this in chapter 19.

Old wisdom: **tools matter more than the runtime**. Games are made by people, and the speed at which
a designer can change a number and see the result (iteration time) ultimately determines
the quality of the game more than an extra 0.3 ms in the renderer. That is why the track has chapters on
hot reload, serialization, the editor and undo/redo — these are not "secondary", they are the core
of the profession.

## 3. Engine layers

An engine is customarily drawn as a stack of layers, where each layer depends only on the ones below it.
This is a simplified diagram based on Gregory (fig. 1.16 in the 3rd edition):

```
 ┌──────────────────────────────────────────────────────────────────────────┐
 │                    GAME (gameplay code, scripts, data)                   │  ch. 14, 20
 ├──────────────────────────────────────────────────────────────────────────┤
 │ Gameplay foundation: world, entities/ECS, events, scripting, triggers    │  ch. 05, 06, 14
 ├─────────────┬─────────────┬──────────────┬──────────────┬────────────────┤
 │ Rendering   │ Physics,    │ Animation    │ Audio        │ Networking     │  ch. 09, 11,
 │             │ collisions  │              │              │                │      16, 18
 ├─────────────┴─────────────┴──────────────┴──────────────┴────────────────┤
 │ Scene and spatial structures, input, resources and assets                │  ch. 07, 08, 10
 ├──────────────────────────────────────────────────────────────────────────┤
 │ Core: frame loop, memory, containers, math, strings, reflection,         │  ch. 01–04,
 │       serialization, job system, profiling, logging, configs             │      12, 13, 15
 ├──────────────────────────────────────────────────────────────────────────┤
 │ Platform layer (PAL): window, files, threads, time, graphics API, input  │
 ├──────────────────────────────────────────────────────────────────────────┤
 │ OS, drivers, hardware (CPU, GPU, memory, disks, controllers)             │
 └──────────────────────────────────────────────────────────────────────────┘
```

A few important points about this picture.

**Platform layer.** All platform-dependent code (Win32, POSIX, console SDKs, Vulkan/
D3D12/Metal) is hidden behind a thin layer. Casey Muratori's Handmade Hero is built precisely around
this idea: the game is a function `game_update_and_render(memory, input, output)`, and
the platform merely calls it, supplying memory, input and a buffer for the image. Such an interface
immediately gives you testability (you can feed in recorded input), hot reload (the game can be
reloaded as a DLL) and portability.

**Core** is the foundation everything else uses. This is where the track begins: if
allocators, containers and math are done poorly, nothing above can save you. In Unreal this is
the `Core` module (TArray, FString, FMemory, FMath), in Godot it is `core/` (Vector, HashMap,
Variant, Object), in Bitsquid it is `foundation` (the famous minimalist library with
`Array<T>`, `Hash<T>` and `Allocator`).

**Dependencies point only downward.** If physics starts calling the renderer directly, and the renderer calls
gameplay, the engine turns into a tangle where nothing can be tested in isolation
or parallelized. Communication "upward" and "sideways" goes through events (ch. 06), callbacks,
data in shared structures, or explicit "glue" at the game level. Our Machinery took
this idea to the extreme: every subsystem is a plugin with a C interface (a function table),
and none of them knows about another directly (ch. 17).

**Layers are not modules.** A layer may contain many modules, and the boundary runs not
along folders but along the direction of dependencies. In C3 this is naturally expressed with modules
(`module engine::core::mem;`) and visibility (`@private`, `@local`).

## 4. Subsystem map

Here are the subsystems you will meet in this track, one line each.

| Subsystem | What it does | Key ideas |
|---|---|---|
| Game loop (01) | Frame rhythm, time | fixed timestep, interpolation, determinism |
| Memory (02) | Where bytes come from | arenas, pools, frame allocators, budgets |
| Containers (03) | How objects are stored | handles, slot map, sparse set |
| Math (04) | Vectors and transforms | SIMD, quaternions, TRS, culling |
| ECS (05) | Game world model | entities as ids, components as data, systems |
| Events (06) | Subsystem communication | queues, double buffering |
| Resources (07) | Assets in memory | manager, refcount, hot reload |
| Scene (08) | Hierarchy and space | dirty flags, BVH, grid |
| Rendering (09) | The image | command buffer, sort keys, rasterization |
| Input (10) | Devices → actions | action mapping, buffering |
| Physics (11) | Motion and collisions | integrators, broadphase, contacts |
| Multithreading (12) | All CPU cores | job system, frame graph |
| Serialization (13) | Saving and loading | versioning, reflection |
| Scripting (14) | Logic without recompiling | VM, bindings |
| Profiling (15) | Why it's slow | instrumentation, debug draw |
| Audio (16) | Sound | mixer, voices |
| Hot reload (17) | Code without restarting | dynamic libraries |
| Networking (18) | Multiplayer | lockstep, snapshots, prediction |
| Tools (19) | Editor | undo/redo, properties |

## 5. Data flow of a single frame

A game is a loop that, 30–240 times per second, turns "world state + input" into
"new world state + image + sound". A typical frame of a single-threaded engine:

```
  ┌─────────┐   ┌──────────┐   ┌──────────────────────────┐   ┌─────────┐   ┌──────────┐
  │ OS:     │   │ Input:   │   │ Simulation (0..N times   │   │ Frame   │   │ Render:  │
  │ window  │──>│ devices  │──>│ with a fixed step):      │──>│ prep:   │──>│ GPU      │
  │ events  │   │ -> actions│   │ gameplay, AI, physics,   │   │ culling,│   │ commands,│
  └─────────┘   └──────────┘   │ animation, events        │   │ sorting │   │ present  │
                               └──────────────────────────┘   │         │   └──────────┘
                                         │                     └─────────┘
                                         v
                                  audio, networking, resource streaming (often on their own threads)
```

In modern engines frames **overlap**: while the GPU draws frame N, the CPU render
thread prepares commands for frame N+1, and the game thread is already simulating frame N+2.
This is how Unreal (Game Thread → Render Thread → RHI Thread), Destiny (Bungie) and
Naughty Dog (the famous talk "Parallelizing the Naughty Dog Engine Using Fibers") work.

```
 time ────────────────────────────────────────────────────────────>
 Game thread:   [ sim N   ][ sim N+1 ][ sim N+2 ][ sim N+3 ]
 Render thread:            [ rend N  ][ rend N+1][ rend N+2]
 GPU:                                 [ gpu N   ][ gpu N+1 ]
```

This leads to many architectural requirements we will keep coming back to:
data read by the renderer must be **copied or double-buffered**
(ch. 02, 06); frame memory must live for as many frames as the pipeline is deep;
input latency grows with pipeline depth.

## 6. The principles this track stands on

**Data-oriented design.** The performance of a modern CPU is dominated by memory:
a cache miss costs 100–300 cycles, while a single instruction costs a fraction of a cycle. So we think about
*data*: how it is laid out in memory, who reads it, in what order, how much of it there is.
Arrays of structs of homogeneous data processed in batches are almost always faster than a graph
of objects with virtual methods. This is not dogma — it is the physics of the hardware.
(Mike Acton, "Data-Oriented Design and C++", CppCon 2014; Richard Fabian, "Data-Oriented Design".)

**Simple solutions, explicit owners.** Every byte of memory belongs to a specific subsystem
and a specific allocator; every object has a clear lifetime (frame, level, game).
Instead of a web of `shared_ptr`s — handles and arenas.

**Explicit is better than implicit.** The order in which systems update, synchronization points, frame
boundaries — all of this must be visible in the code, not happen "somewhere in a destructor".

**Measure.** Every performance claim is verified with a profiler
(ch. 15). Intuition about what is slow is wrong roughly half the time.

**Determinism and reproducibility.** If a bug can be reproduced from recorded input,
it is almost fixed. We will aim to keep the simulation deterministic
wherever that is cheap (ch. 01, 18).

## 7. How this track is organized

Each chapter consists of:

1. **Theory** in `engine/docs/CC_topic.md`. Read it *before* the exercises. It is not an API
   reference but an analysis of the problem: what solutions exist, what they cost, how real
   engines do it, and which pitfalls people fall into.
2. **Exercises** `engine/exercises/eCCNN_name.c3`. In them you implement real engine
   code: allocators, a slot map, quaternions, an ECS, a system scheduler… The places to
   work on are marked `TODO`. Each program checks itself with `assert` and
   prints a final report that the runner compares against a reference.
3. The last exercise of each chapter is an **integration** exercise: it brings the chapter's ideas together into one
   small but complete subsystem.

Exercises in this track are larger than in the first one. Usually you need to implement several
functions of 5–30 lines each. If you get stuck — `./c3lings hint e0203`. If an assert fails —
read the message: it tells you *which* property was violated.

Tips:

* First read the whole exercise, including `main` — the tests are the
  specification.
* Solve one `TODO` at a time, running `./c3lings run eCCNN` after each.
* After solving, ask yourself: what happens with 10⁶ objects? With multiple threads?
  When memory runs out? The self-check questions at the end of each chapter are about exactly this.
* The code from the exercises is yours. By chapter 20 it will add up to your own mini-engine.

## 8. What you won't find here

We will not write wrappers over Vulkan or DirectX — that is a separate, huge topic that fits poorly
with the "one program prints text" format. Rendering in chapter 09 is
renderer architecture (command buffers, sort keys, frame graph) and a software rasterizer
that writes the image to a file. The same approach applies to audio (a WAV file) and networking (simulating
lossy channels within a single process). The architectural ideas do not change because of this, and everything
stays deterministic and verifiable.

## 9. Startup, shutdown and subsystem order

One more thing that is only visible from inside an engine is the **subsystem lifecycle**.
Subsystems depend on each other: the renderer needs the resource manager, resources need the file
system and allocators, everyone needs logging and the profiler. So they must be initialized
bottom-up through the layers and shut down in reverse order:

```
 startup:   memory -> log -> filesystem -> jobs -> resources -> render -> audio -> world
 shutdown:  world -> audio -> render -> resources -> jobs -> filesystem -> log -> memory
```

Gregory (section 5.1) points out a C++ trap: global singleton objects
are constructed in an unspecified order, so serious engines do not rely on
static object constructors but call explicit `startup()`/`shutdown()` in `main`
in the right order. The same applies in C3: `@init` functions are handy for registration, but
the subsystem startup order is better written out explicitly — it is architecture documentation that
is visible in one place.

A good practice is **symmetry and verification at shutdown**: each subsystem, on
`shutdown`, checks that all its resources have been released (the allocator is empty, no handles are
outstanding, threads are stopped). A leak found on level exit in a debug
build costs a minute; the same leak found after 6 hours of play on a console costs days.

Finally, **"hot" and "cold" paths** live by different rules. While loading a level
you can afford string hash tables, parsing and allocations; within a frame — only pre-
prepared data, indices instead of strings, frame allocators. A large part of
engine architecture is moving work out of the frame into loading, and out of loading into
the asset pipeline ("do the work as early as possible"). You will meet this rule
in every chapter: string hashes are computed in the tools (chapter 07), data layout
is prepared during packaging (chapter 13), sort keys are computed once per object (chapter 09).

## 10. Glossary

* **Frame** — one iteration of the main loop, usually ending with presenting an image.
* **Tick / simulation step** — one update of the world by a fixed time `dt`.
  A frame may contain 0, 1 or several ticks.
* **Frame budget** — 16.6 ms at 60 Hz, 33.3 ms at 30 Hz, 8.3 ms at 120 Hz. It is split
  among subsystems ("2 ms for physics, 1.5 ms for AI"). The same goes for memory.
* **Hot path** — code that runs thousands of times per frame; every instruction matters here.
* **Cold path** — level loading, initialization: simplicity matters here.
* **Handle** — an opaque object identifier (index + generation) used instead of a pointer.
* **AoS / SoA** — array of structures / structure of arrays: two ways of laying out data.
* **Load-in-place** — data on disk has the same layout as in memory.

## Self-check questions

1. Why does the "data-driven" criterion separate the engine from the game so well? Give an example
   of a game where the boundary between them is especially blurry.
2. How do the requirements for runtime code and tools code differ? Give two examples of decisions
   that are appropriate in one and unacceptable in the other.
3. Why must dependencies between layers point only downward? What breaks if physics
   starts calling rendering functions directly?
4. Draw the data flow of a single frame of your favorite game. Where is input, where is
   simulation, where is rendering, and what can run in parallel?
5. The "game thread → render thread → GPU" pipeline increases throughput.
   What does it make worse, and what requirements does it impose on data?
6. Why is a general-purpose engine almost always slower than a specialized one at the same task?

## Further reading

* **Jason Gregory, "Game Engine Architecture"** (3rd ed., 2018) — the main book for this track.
  Chapters 1 (overview and layers), 2 (tools), 16 (runtime architecture).
* **Robert Nystrom, "Game Programming Patterns"** — free at gameprogrammingpatterns.com;
  especially "Game Loop", "Update Method", "Component", "Data Locality".
* **Casey Muratori, Handmade Hero** (handmadehero.org) — an engine from scratch, streamed live;
  the first ~30 episodes are the gold standard for a platform layer.
* **Bitsquid / Stingray development blog** (bitsquid.blogspot.com) — short, precise articles
  on data, memory, handles, resources.
* **Our Machinery blog** (archives) — plugin architecture, "the truth", data model.
* **Mike Acton, "Data-Oriented Design and C++"** (CppCon 2014) and **Richard Fabian, "Data-Oriented Design"**.
* **Fabien Sanglard, "Game Engine Black Book: Wolfenstein 3D / DOOM"** and his walkthroughs
  of the Quake/Doom 3 source code on fabiensanglard.net.
* Source code: **id Software** (Quake, Doom 3 BFG on GitHub), **Godot**, **Bevy**,
  **sokol** (Andre Weissflog) — reading other people's engines is as important as writing your own.

Next up is chapter 01, the game loop: the very heart of the engine.
