# Chapter 07. Resources and Assets

> Chapter exercises: `e0701_path_hash` … `e0706_pak_archive`.
> Prerequisites: chapters 02 (allocators) and 03 (handles, slot map).

A game's code is probably a few megabytes. Everything else — textures, meshes, animations,
sounds, shaders, levels, localization — is **data**, and there is two to three orders of
magnitude more of it. A modern AAA game weighs 100+ GB, of which code is a fraction of a percent.
The subsystem responsible for getting the right data into memory (and into video memory) at the
right moment, in the right format and in exactly one copy is called the **resource manager**
(resource manager, asset system, content system — every engine has its own name for it). It is
one of the architecturally "heaviest" parts of an engine: it touches the file system, threads,
memory, tools, the build and the editor.

Terminology. An **asset** is a unit of content as an artist/designer sees it: "the hero texture",
"level 3". A **resource** is the runtime representation of an asset: an in-memory object holding
data. The words are often used interchangeably; we will say "asset" for the source and for the
entity in the pipeline, and "resource" for the loaded object.

## 1. What problems a resource manager solves

1. **Uniqueness.** A hundred trees sharing one texture means one load and one object in memory.
2. **Identity.** How to name a resource so that it is cheap to compare, store and serialize into
   other assets.
3. **Lifetime.** When can a resource be unloaded? Who owns it?
4. **Asynchrony.** A disk read takes milliseconds (on an HDD, tens of milliseconds per seek). A
   frame is 16 ms. Blocking load = freeze. You need background loading, which means "not ready
   yet" states.
5. **Dependencies.** A material references a shader and textures; a level references thousands of
   assets.
6. **Format.** Source files (PSD, FBX, WAV) are not fit for runtime. You need an offline pipeline
   that turns them into a format convenient for a specific platform.
7. **Packaging and distribution.** Archives, compression, patches, DLC, mods.
8. **Iteration.** Hot reload: the artist hits save — the game picks it up.

Items 1–5 are runtime, 6–7 are tools and build, 8 is the bridge between them. A good
architecture separates them cleanly: **the runtime knows nothing about source formats**. It loads
only "cooked" data. This rule is the main difference between a game engine and "a program that
reads PNGs".

```
  Artist             Tools (offline)                       Runtime (game)
 +---------+     +---------------------------+      +-----------------------------+
 | hero.psd| --> | importer -> cooker(PC)    | -->  | pak/bundle -> resource mgr  |
 | hero.fbx|     |          -> cooker(PS5)   |      |   handles, refcount, states |
 | jump.wav|     |  cache keyed by src hash  |      |   streaming, hot reload     |
 +---------+     +---------------------------+      +-----------------------------+
                  DDC (derived data cache)
```

## 2. Resource identity

The most obvious choice is a path string: `"textures/hero.png"`. Convenient for humans, but bad at
runtime:

* comparison is a variable-length `memcmp`, and a hash table key is a pointer plus a length;
* the strings have to be stored somewhere and owned by someone;
* in serialized assets (a material referencing a texture) the string bloats the data.

That is why almost every engine turns the path into a **number** — a hash. Bitsquid/Stingray used
a 64-bit murmur hash of the path plus a separate hash of the resource type: the pair
`(type_hash, name_hash)` identifies a resource. id Tech and many others do the same with
CRC32/FNV. In this course we use 64-bit FNV-1a: it is tiny and table-free, which means it is easy
to compute at compile time too:

```c3
macro ulong @rid(String $path) @const
{
    var $h = 0xcbf29ce484222325;
    $for var $i = 0; $i < $path.len; $i++:
        $h = ($h ^ $path[$i]) * 0x100000001b3;
    $endfor
    return $h;
}
...
switch (event_resource)
{
    case @rid("sounds/jump.wav"): ...   // a constant computed by the compiler
}
```

The alternative is a **GUID**: a random 128-bit identifier assigned to an asset on import and
stored alongside it (Unity: `.meta` files with `guid:`; Unreal references assets by package path
but uses GUIDs internally for many entities; Godot 4: `uid://` on top of paths).

| | Path hash | GUID |
|---|---|---|
| How it is obtained | deterministically from the path | generated on creation |
| Rename/move | id changes, all references must be fixed | id is stable |
| Needs a mapping database | no (the path is its own id) | yes (`.meta`, registry) |
| Computable in code | yes, even at compile time | no |
| Collision risk | exists (theoretical for 64 bits) | practically none |

A practical compromise used by many engines: in the **editor and pipeline**, assets are
addressed by GUIDs (renames don't break references), and during cooking references are turned
into compact runtime ids (a hash, an index into the package table). The runtime no longer cares
what the artist called the asset.

### Canonicalization

You cannot hash a path "as is": `Textures\Hero.PNG`, `./textures//hero.png` and
`textures/old/../hero.png` are the same file (on Windows, where the FS is case-insensitive), but
three different hashes. The result is a triple load and triple memory use, and on hot reload only
one of the copies gets updated. Before hashing, the path is brought to **canonical form**:

* separator `\` → `/`;
* lowercase (or forbid uppercase in asset names at the tools level — simpler and more robust:
  a Linux build on a case-sensitive FS won't break);
* remove empty segments and `.`, resolve `..`;
* path relative to the content root (no `C:\Projects\Game\content\…`).

Canonicalization is done **once**: at the boundary where a path enters from the outside world
(config, console, script). Inside the engine only ids travel around.

### Collisions

The probability of a collision for n random values in a space of size N is estimated by the
"birthday paradox": p ≈ n² / 2N. For a 32-bit hash and 100,000 assets,
p ≈ 10¹⁰ / 8.6·10⁹ > 1 — a collision is practically guaranteed! For 64 bits the same estimate
gives ~3·10⁻¹⁰ — livable. This is exactly why 32-bit path hashes are a bad idea for large
projects (in exercise e0701 you will see collisions with just 1000 paths and a 16-bit hash).

But "unlikely" ≠ "impossible", and you want to learn about a collision **in the tools**, not
through a mysterious bug where "the hero has a tree texture". Solution: during the build (and in
the debug runtime) keep an `id → canonical path` registry and check every insertion. Same id with
a different path — build error, the asset gets renamed. Path strings are not needed in release at
all — they can be moved into a separate debug file for logs and the profiler.

## 3. Handles instead of pointers

What does game code get back when it asks for "the hero texture"? Options:

1. **Raw pointer** `Texture*`. Fast, but: the resource gets unloaded — dangling pointer; hot reload
   replaces the object — everyone keeps the old version; memory defragmentation is impossible.
2. **Reference-counted smart pointer** (`std::shared_ptr`, `TSharedPtr`, `Ref<T>` in Godot).
   Solves lifetime, but costs atomic increments/decrements on every copy and a pointer to a
   control block, and the object still can't be moved.
3. **Handle** `{ index, generation }` — an index into the manager's table plus a generation
   (chapter 03). The resource can be reloaded in place, moved, unloaded; a stale handle is
   detected by comparing generations rather than by a crash.

```
  Handle{index=0, gen=3} ---> slots[0] { gen=3, refcount=2, data=* } ---> Texture
  Handle{index=0, gen=2} ---> slots[0] { gen=3 ... }   gen != 2  => STALE
```

A handle is 8 bytes (often packed into 32 bits: 20-bit index + 12-bit generation), trivially
copied and serialized. Dereferencing is one check and one index operation. This is how resources
work in Bitsquid, in most render backends (buffer/texture handles in bgfx, sokol_gfx), and in Our
Machinery. For hot reload this is essential: the table is the only place that holds the pointer
to the data, and swapping the data in a slot is instantly visible to every handle owner.

Dereference a handle "late and briefly": get a `Texture*` at the start of a function, use it,
forget it. Do not keep the result of `get()` across frames — that is the whole point of a handle.

## 4. Lifetime: reference counting

Who decides that a resource is no longer needed? The classic strategies:

* **Reference counting.** `acquire` +1, `release` −1, at zero it becomes a candidate for
  unloading. Simple and local. Pitfalls: a forgotten `release` = leak; an extra `release` =
  unloading out from under someone (so the manager should catch "over-release" at least in debug
  builds); reference cycles (rare for assets — the dependency graph is usually acyclic — but
  possible in script data).
* **Group ownership** (Bitsquid "resource packages", Unity AssetBundles, Unreal "chunks"). What
  gets loaded and unloaded is not a resource but a **package** — the set of resources for a
  level/zone. Resources inside a package live as long as the package does. Reference counting
  happens at the package level (a resource may belong to several). Deterministic, easy to budget
  memory.
* **Garbage collection/scanning** (Unreal UObject GC, `Resources.UnloadUnusedAssets()` in Unity):
  a periodic reachability-graph traversal. Convenient for gameplay code, but expensive and with
  pauses.

### Don't unload immediately

A typical scenario is a level change: "release everything from level 1, request everything for
level 2". If a resource is unloaded the moment its counter hits zero, assets shared between levels
(UI, the player character, common textures) will be unloaded and immediately loaded again —
**thrashing**. The right way: resources with a zero count stay in memory until an explicit
`collect()` (once per frame, after the new level has loaded, or under memory-budget pressure — an
LRU cache of "unused" ones). An `acquire` of a resource with zero references simply "resurrects"
it. This is exactly what exercise e0702 checks.

```c3
fn Handle? TextureManager.acquire(&self, String path)
{
    ResourceId id = path_id(path);
    if (try index = self.by_id.get(id))      // already loaded (possibly with refcount 0)
    {
        self.slots[index].refcount++;
        return { index, self.slots[index].generation };
    }
    ...
}
```

### Multithreading

In a real engine `acquire` is called from different threads, and loading completes in the
background. Counters are made atomic, the id→slot table is protected by a mutex or sharded locks,
and unloading is moved to a single point in the frame (the main thread), when the GPU is
guaranteed to no longer use the data — with a delay of N frames (N = the number of frames "in
flight" on the GPU). This **deferred unloading** is needed even without threads: you can't free a
texture the GPU is drawing in a frame submitted two frames ago.

## 5. Loading states

Since loading is not instantaneous, a resource has a lifecycle:

```
 UNLOADED --request--> QUEUED --IO free--> LOADING --bytes read-----------+
                                                                           |
                       FAILED <------- file missing / corrupt data --------+
                         ^                                                 |
                         +---- dependency FAILED ----- WAITING_DEPS <------+
                                                            |
                                              all dependencies LOADED
                                                            v
                                                         LOADED
```

Sometimes more stages are added: `PROCESSING` (decompression, building structures on a worker
thread), `UPLOADING` (copying into video memory via an upload queue/staging buffer), `UNLOADING`.
What matters is that the state is **visible from outside**: game code can ask `is_loaded(h)` and,
while the resource is not ready, draw a placeholder (a low-resolution LOD, a gray material) or not
draw at all. The handle is returned **immediately** on request — before the data is loaded.

Why `WAITING_DEPS` is a separate state: a material's bytes may arrive before the bytes of its
textures. A material cannot be declared ready until its dependencies are ready, otherwise the
renderer will see a material referencing an unloaded texture. Dependencies are requested
**before** the asset itself: a depth-first graph traversal (with duplicate protection — shared
dependencies are common), and this naturally queues leaves before roots.

### Errors

A load failure is a normal situation (especially during development): someone forgot to commit
a file, the format is outdated. Two approaches:

* **Propagate** FAILED up through the dependencies — strict mode, good for CI and builds.
* **Substitute a fallback**: a bright pink checkerboard texture, an "ERROR" mesh (Source
  engine — the famous red ERROR and the purple-black checkerboard). The game keeps running, the
  problem is visible to the eye. Almost every engine does this in the editor.

## 6. Asynchronous loading

Synchronous loading on the main thread is acceptable only on a loading screen. Everything else is
asynchronous. A typical architecture:

```
 main thread                 IO thread(s)                worker jobs           render thread
 -----------                 ------------                -----------           -------------
 request(h) --> queue -----> read(file, offset, size)
                              (limit: N in flight)
                                     |  bytes
                                     +--------------> decompress, parse,
                                                      fixup pointers
                                                             |
                                                             +----------> GPU upload
 poll(): completed <-----------------------------------------------------------+
   state = LOADED, callbacks, dependents
```

Key decisions:

* **How many reads at once.** For an HDD — one or two (seeks kill throughput; better to sort
  requests by offset in the archive). For NVMe — dozens (the queue is deep, hence
  DirectStorage/`io_uring`, which hand the device many small requests at once). On
  previous-generation consoles with optical discs — strictly sequential, and level data was laid
  out contiguously on the disc, sometimes **duplicating** assets to avoid moving the read head.
* **Priorities.** What's near the camera matters more than what's a kilometer away. A streaming
  system (open world) constantly recomputes priorities and even cancels requests.
* **Budgets.** A limit on the number of completions processed per frame, otherwise the frame in
  which 200 assets "arrived" will take 100 ms. Finalization (creating GPU objects, registration)
  is limited by time or count.
* **Feedback.** "Loaded" callbacks are dangerous (which thread are they called on? what if the
  subscriber is already gone? — see chapter 06 on listener lifetime). Polling state by handle, or
  events in a queue processed at a known point in the frame, is more robust.

In exercise e0703 threads are replaced with ticks: each asset has a "read cost" in ticks, and the
budget is `max_in_flight`. The state logic is the same as in a real streamer, but the behavior is
deterministic and can be checked against exact output. This is a general technique: **separate
the scheduling logic from the threading mechanics**, and you can test the former without the
latter.

## 7. Hot reload

Iteration time is the main metric of team productivity. If seeing a fixed texture requires
restarting the game and getting back to the right spot (2–5 minutes), an artist will do 20
iterations a day instead of 200. That is why every serious engine has asset hot reload.

**How to find out that a file changed:**

* **Polling mtime** (`stat`): every N frames walk the loaded resources and compare modification
  times. Portable and simple, but the cost grows with the number of files (it is done on a
  separate thread or in slices), and mtime resolution can be 1–2 seconds (FAT — 2 s), so two saves
  within one second are indistinguishable. Sometimes size or a content hash is compared as well.
* **OS notifications**: `inotify` (Linux), `ReadDirectoryChangesW` (Windows), `FSEvents` (macOS).
  Instant and cheap, but three APIs, quirks with network drives, and event-queue overflow.
* **Via the tools**: the editor/asset server knows itself that it rebuilt an asset and sends the
  game a message over a socket (Bitsquid "reload" over the network to a devkit, Unreal Live
  Coding/Live Link). This is the only option for consoles and phones, where the files don't live
  on the developer's machine.

**What to do after detection:**

1. **Reload transactionally.** The file may be partially saved (the editor is writing it right
   now), contain an error, or be in an outdated format. Parse into a temporary object; on success
   atomically swap the data in the slot (the handles stay the same!), on error — log and keep the
   old version. Never crash: hot reload is a development tool, and its errors must not kill the
   session.
2. **Update dependents.** A shader is recompiled → every material using it must recreate its
   pipeline state. You need a reverse graph of "who depends on me". Relinking is done **after**
   reloading all files changed in this poll — otherwise a material processed before its shader
   will link against the old version.
3. **Survive a file disappearing.** `git checkout`, a rename, saving via a temp file and rename —
   the file may be temporarily missing. That is no reason to unload the resource: warn once and
   wait.
4. **Account for state built on top of the resource.** If game code cached a texture's size or
   data from a config, the cache is stale after reload. Solutions: don't cache (always go through
   the handle), a resource version number, a "resource reloaded" event.

An important subtlety: does hot reload work on **sources or cooked data**? In a setup with an
offline pipeline, `hero.psd` changes → the tool rebuilds `hero.tex` → the runtime notices the
change to `hero.tex`. The runtime still can't read PSD.

## 8. The asset pipeline: source → cooked

```
  source             import                 intermediate             cook (per platform)          runtime
  hero.fbx  --->  parse via FBX SDK, --->   engine format      --->   vertex optimization, --->   hero.mesh
  hero.psd        normalize axes,           (mesh/texture not         BCn/ASTC texture            (ready for
                  units, ...                tied to a platform)       compression, GPU layout,    in-place
                                                                      LODs                        loading)
```

* **Import** converts a foreign format into your own "intermediate" one. It is done once when the
  asset is added, and the result is often stored in the repository (an Unreal `.uasset` is an
  imported asset).
* **Cooking** (Unreal terminology; "compile" in Bitsquid/Stingray, "build" in many others) makes
  the data optimal for a specific platform: texture compression format (BC7 on PC, ASTC on
  mobile), vertex order for the vertex-shader cache, endianness (in the PS3/Xbox 360 era —
  big-endian!), alignment, stripping editor-only data.
* **Derived data cache** (Unreal DDC, Unity Library/, Bitsquid data cache): the cooking result
  depends on (source contents, cooker version, parameters, platform). The hash of this quadruple
  is the cache key. A rebuild with no changes is instant; teams use a shared network cache so that
  each asset is cooked once for the whole studio. That is why the cooked format header contains a
  **version**: change the format — bump the version — and the cache and old files are
  automatically invalidated, and the runtime rejects stale data instead of reading garbage.

### The cooked data format

The goal is **loading with almost no work**. The ideal: read a block of bytes into memory and use
it as is ("in-place loading", "load-in-place"): a header, then fixed-format arrays, references as
offsets which after loading are either turned into pointers in a single pass ("pointer fixup") or
used as offsets directly (relative pointers). This is how the Bitsquid formats, many console
engines and flatbuffers-like schemes work.

```
  offset  size  field
  0       4     magic 'MSH1'           - is this our file at all?
  4       2     version                - is it the right format?
  6       2     flags
  8       4     vertex_count
  12      4     index_count
  16      4     payload_size           - is the file truncated?
  20      4     checksum(payload)      - is it corrupted?
  24      ...   float[vertex_count*3], ushort[index_count], pad
```

Rules of a good binary format:

* **Explicit byte order and explicit layout.** Write fields byte by byte, not `fwrite(&header,
  sizeof header)`: struct layout depends on the compiler (padding), and byte order on the
  platform. If you read in place, choose the layout so that it matches the native one on the
  target platforms, and verify it with `$assert`s on sizes and offsets.
* **Alignment.** The header is a multiple of 4/16 — then the arrays after it are aligned and can
  be read as `float[]` without copying (and SIMD loads and DMA outright require 16 bytes).
* **Magic + version + size + checksum.** Cheap runtime checks catch real problems: the wrong file,
  an outdated format, a truncated download, a bad disk.
* **Expensive validation happens offline.** Indices in range, limits, consistency — during
  cooking. The runtime trusts the data (in release), otherwise loading turns back into parsing.
  The exception is data from untrusted sources (mods, user content, the network): it is always
  validated.

Exercise e0705 is a small cooker and loader for a mesh in exactly this format.

## 9. Packed archives

Thousands of separate files on disk in a release build are bad:

* every `open()` is a system call, a permission check, and on consoles a signature check;
  on Windows opening a file is surprisingly expensive (antivirus!);
* the file system wastes space on small files (4 KB clusters);
* you can't control the **layout** on disk (what sits next to what);
* patches and mods are awkward.

So assets go into archives: `.pak` (Quake, Unreal), `.wad` (Doom), `.bundle` (Unity),
`.arc`, `.big`, etc. A typical structure:

```
 +------------------+  0
 | header           |  magic, version, count, toc_offset
 +------------------+
 | blob 0 (aligned) |
 | blob 1 (aligned) |  data; often each blob is compressed separately (LZ4/Oodle/zstd),
 | ...              |  so that any resource can be read independently
 +------------------+  toc_offset
 | TOC              |  { id, offset, size, [compressed_size, flags] } x count,
 +------------------+  sorted by id -> binary search
```

The TOC (table of contents) is often placed **at the end**: during the build the blob sizes are
known only after writing, and space is left at the start for the header, which is written last.
The TOC has no names — only hashes; lookup is a binary search over a sorted array (or perfect
hashing). The archive itself is memory-mapped (`mmap`), or an open descriptor is kept and read at
offsets.

**Mounting and priorities.** The engine mounts several archives into a single virtual namespace:
`base.pak`, `patch_01.pak`, `dlc_forest.pak`, mods. Lookup goes from the last mounted to the
first — a patch "overrides" files from the base. This is how id Software shipped patches and how
mods work in countless games: Quake searches `pak1.pak` before `pak0.pak`, Unreal patches are
`*_P.pak` files with higher priority. During development an "archive" can simply be a directory
on disk — same interface (VFS — virtual file system).

**Layout.** When building an archive you can choose the order of the blobs: one level's resources
contiguously, in the order they are requested during loading (the order can be recorded during a
playthrough — a "file order log"). This turns loading a level into one long sequential read.

Exercise e0706 brings it all together: a tool builds two archives (base and patch) with aligned
blobs and a sorted TOC, the runtime mounts them and finds resources by binary search without
copying, and a manager with handles and reference counts caches the results.

## 10. How real engines do it

* **Bitsquid / Stingray.** Data is compiled offline into platform-specific binary formats. A
  resource is identified by a `(type, name)` pair of 64-bit murmur hashes. Loading is by packages
  (`resource package`); a package is loaded asynchronously and "flushed" at a single point in the
  frame. The data format is designed for in-place loading. Hot reload goes over the network from
  the devkit. The blog bitsquid.blogspot.com is the best public documentation of this kind of
  architecture.
* **Unreal Engine.** Assets are `UObject`s in `.uasset`/`.umap` packages; references are package
  paths (`/Game/Characters/Hero`), "soft" (`TSoftObjectPtr`, loaded on demand) and "hard" (pull
  in the dependency at load time). Per-platform cooking, DDC, `.pak`/IoStore (`.utoc/.ucas`)
  containers, async loading via `FStreamableManager`, lifetime via the UObject garbage collector.
  The Asset Registry is a database of asset metadata available without loading the assets.
* **Unity.** GUIDs in `.meta` files, import into `Library/`, runtime loading via `Resources`,
  AssetBundles and Addressables (address → bundle → asset, reference counting on bundles).
* **Godot.** `ResourceLoader` with a path-keyed cache, `Ref<Resource>` with reference counting,
  `ResourceLoader.load_threaded_request` for background loading, import into `.godot/imported/`,
  `.pck` archives, `uid://` for stable references.
* **id Tech.** `.pk3/.pk4` (zip) and later custom containers, per-type `idResource` managers, the
  well-known bet on megatextures/virtual texturing for streaming.

## 11. Performance and memory

* The resource table is a dense array of slots ("cold" field data kept separately); the
  `id → slot` lookup is an open-addressing hash table on 64-bit keys.
* Hash paths once. Code like `get_texture("ui/button.tex")` in a loop is an antipattern (a hash
  every iteration); compile-time `@rid` solves this for free for literals.
* Memory budgets by category (textures, meshes, audio) — the resource manager is their main
  enforcer: it knows the sizes and can refuse or evict unused data (see chapter 02).
* Fragmentation: large resources with different lifetimes fragment the heap. Solutions —
  per-package/per-level allocators (linear arenas freed as a whole), relocatable resources
  (possible thanks to handles), a pool of fixed-size blocks for streaming (virtual texturing —
  pages of the same size).
* Reads: large sector-aligned blocks, in ascending offset order; decompression on worker threads;
  on the GPU — via upload queues and staging buffers (chapter 09).

## 12. Common mistakes

* Hashing a non-canonical path → duplicate resources, partially working hot reload.
* 32-bit hashes in a large project with no collision checking.
* Synchronous loading "just in case" in gameplay code → micro-stutters that only show up on a
  player's slow disk.
* Keeping a pointer obtained from a handle across frames.
* Immediate unloading at zero references → thrashing on level change.
* Unloading a resource the GPU is still using in frames "in flight".
* Load-completion callbacks invoked from the IO thread that touch game state.
* Hot reload that crashes on a syntax error in a file, or rereads a broken file on every poll,
  flooding the log.
* `fwrite` of a whole struct as a "binary format" — it will break when the compiler, flags or
  platform change.
* No version in the format → after a cooker change the runtime reads old files as garbage.

## Self-check questions

1. Why shouldn't an engine runtime be able to read PNG/FBX? What does it lose and what does it
   gain?
2. Compare path hashes and GUIDs as asset identifiers. How are the two approaches combined?
3. Estimate the probability of at least one collision of a 32-bit hash for 50,000 assets. And of
   a 64-bit one? Where and how should a collision be detected?
4. Why is an `{index, generation}` handle better than a smart pointer for resources that may be
   reloaded? When should a handle be dereferenced?
5. What is thrashing on level change, and how do you avoid it without giving up reference
   counting?
6. Why have a separate `WAITING_DEPS` state? In what order should dependencies be queued, and
   why?
7. Why is the number of concurrent reads limited, and how does the optimal value depend on the
   medium (HDD, NVMe, optical disc)?
8. List three rules of robust hot reload. Why is relinking of dependents done as a separate pass?
9. Which checks of the cooked format are performed at runtime, and which only during cooking? Why?
10. Why is an archive's TOC usually written at the end of the file? How does a patch override
    files?
11. What is in-place loading, and what requirements does it impose on the format (alignment,
    endianness, pointers)?
12. How is the resource manager related to the memory budgets/allocators from chapter 02?

## Further reading

* Jason Gregory, *Game Engine Architecture* (3rd ed.), chapter 7 "Resources and the File System".
* The Bitsquid/Stingray blog (Niklas Frykholm, Tobias Persson): series on the resource system,
  "Data-oriented data compilation", "A Simple Roll-Your-Own Async Loading", and on in-place
  formats — bitsquid.blogspot.com.
* Our Machinery blog (archive): "The Asset System", on GUIDs, the derived data cache and the
  "truth" editor data model.
* Unreal Engine docs: "Asset Management", "Cooking Content", "Pak/IoStore", "Derived Data Cache".
* Unity docs: "Addressables", "AssetBundles", "Asset Database".
* Godot docs: "Resources", "Background loading", the source `core/io/resource_loader.cpp`.
* Fabien Sanglard, *Game Engine Black Book: DOOM* — the WAD format and loading on constrained
  hardware.
* Shawn Hargreaves, "Content pipeline" (XNA blog) — a good explanation of the offline cooking
  idea.
* Rich Geldreich — notes on texture compression and data formats for games.
