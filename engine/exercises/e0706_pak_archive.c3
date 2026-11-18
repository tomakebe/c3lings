// =====================================================================
//  e0706 · Pak archive, mounting and a resource manager on top of it
// =====================================================================
//
//  Read engine/docs/07_resources.md first (section "Packed
//  archives"). This is the chapter's capstone exercise: path hashes (e0701),
//  handles and reference counts (e0702) and "cooked" binary data (e0705)
//  come together into one system.
//
//  Thousands of small files on disk are slow (every open() is a trip to the
//  OS, plus signature checks on consoles/phones) and inconvenient (patches,
//  mods). So shipped games put assets into large archives (.pak in
//  id Tech and Unreal, .bundle in Unity, .wad in Doom):
//
//      +------------------+  offset 0
//      | header (16 B)    |  magic "PAK1", version, count, toc_offset
//      +------------------+  16
//      | blob 0           |  each blob is aligned to 16 bytes
//      | ...pad...        |  (so the data can be used in-place,
//      | blob 1           |   with SIMD loads or DMA)
//      | ...              |
//      +------------------+  toc_offset
//      | TOC: count x 16B |  { ulong path_id; uint offset; uint size; }
//      +------------------+  sorted by path_id -> binary search
//
//  The archive has no file names at all — only 64-bit ids. The runtime
//  hashes the path and finds it with a binary search in O(log n).
//
//  Mounting several archives: base.pak, then patch.pak (or a mod).
//  The search goes from the LAST mounted archive to the first — that way a patch
//  "overrides" the base game's files without rewriting gigabytes.
//
//  TASK (TODO below):
//    1. build_pak — the tools part: write a placeholder header,
//       the blobs aligned to 16, the sorted TOC, then fill in
//       count and toc_offset in the header. The same id for two files ->
//       DUPLICATE_PATH~.
//    2. Pak.find — binary search over the TOC; returns a slice INSIDE the archive
//       (no copying) or NOT_FOUND~. Count the steps in self.probes.
//    3. Manager.acquire — a cache by id (a repeated acquire only
//       increments refcount and does not touch the archives), otherwise search the
//       mounted archives from last to first and take a slot.
//
import std::io, std::sort;
import std::collections::list, std::collections::map;

excuse NOT_FOUND, DUPLICATE_PATH, BAD_PAK, STALE_HANDLE, OUT_OF_SLOTS;

typedef ResourceId = inline ulong;   // inline: inherits .hash() for HashMap

const uint PAK_MAGIC = 0x314B4150;   // 'P','A','K','1' in little-endian
const uint PAK_VERSION = 1;
const usz HEADER_SIZE = 16;
const usz TOC_ENTRY_SIZE = 16;
const usz ALIGN = 16;

fn ResourceId path_id(String path)
{
    ulong h = 0xcbf29ce484222325;
    foreach (c : path)
    {
        char ch = c == '\\' ? '/' : (c >= 'A' && c <= 'Z' ? c + 32 : c);
        h = (h ^ ch) * 0x100000001b3;
    }
    return (ResourceId)h;
}

// --------------------------------------------------- byte helpers
fn void put_u32(List{char}* out, uint v)
{
    for (int i = 0; i < 4; i++) out.push((char)(v >> (8 * i)));
}
fn void put_u64(List{char}* out, ulong v)
{
    for (int i = 0; i < 8; i++) out.push((char)(v >> (8 * i)));
}
fn void patch_u32(List{char}* out, usz at, uint v)
{
    for (usz i = 0; i < 4; i++) out.entries[at + i] = (char)(v >> (8 * i));
}
fn uint get_u32(char[] b, usz at)
    => (uint)b[at] | (uint)b[at + 1] << 8 | (uint)b[at + 2] << 16 | (uint)b[at + 3] << 24;
fn ulong get_u64(char[] b, usz at) => (ulong)get_u32(b, at) | (ulong)get_u32(b, at + 4) << 32;

// ======================================================= tools
struct SourceFile
{
    String path;
    String data;
}

struct TocEntry
{
    ResourceId id;
    uint offset;
    uint size;
}

fn void? build_pak(SourceFile[] files, List{char}* out)
{
    List{TocEntry} toc;
    toc.init(mem);
    defer toc.free();

    // TODO:
    //  1. HEADER_SIZE zero bytes (header placeholder).
    //  2. For each file: pad out with zeros to a multiple of ALIGN,
    //     record { path_id(f.path), offset, size } in toc, append the data
    //     (out.push_all(f.data)). After the last one — align again.
    //  3. Sort toc.array_view() by id (sort::quicksort with a lambda
    //     comparator), adjacent equal ids -> DUPLICATE_PATH~.
    //  4. toc_offset = the current length; write the TOC entries (put_u64 id,
    //     put_u32 offset, put_u32 size).
    //  5. patch_u32 at bytes 0, 4, 8, 12: PAK_MAGIC, PAK_VERSION, count, toc_offset.
    return DUPLICATE_PATH~;
}

// ======================================================= runtime
struct Pak
{
    String name;
    char[] blob;      // the whole file in memory (in reality — mmap)
    uint count;
    usz toc;
    int probes;       // binary search step counter (for statistics)
}

fn void? Pak.mount(&self, String name, char[] blob)
{
    if (blob.len < HEADER_SIZE || get_u32(blob, 0) != PAK_MAGIC || get_u32(blob, 4) != PAK_VERSION) return BAD_PAK~;
    self.name = name;
    self.blob = blob;
    self.count = get_u32(blob, 8);
    self.toc = get_u32(blob, 12);
    if (self.toc + (usz)self.count * TOC_ENTRY_SIZE > blob.len) return BAD_PAK~;
}

fn ResourceId Pak.toc_id(&self, usz i) => (ResourceId)get_u64(self.blob, self.toc + i * TOC_ENTRY_SIZE);

fn char[]? Pak.find(&self, ResourceId id)
{
    // TODO: binary search over [0, self.count) using self.toc_id(i);
    //       self.probes++ on each step. If found — read the entry's offset and size
    //       (bytes +8 and +12 from the start of the entry) and return
    //       self.blob[offset:size]. If not found — NOT_FOUND~.
    return NOT_FOUND~;
}

struct Handle
{
    uint index;
    uint generation;
}

struct Slot
{
    ResourceId id;
    uint generation;
    uint refcount;
    String data;          // points straight into the archive blob
    String source;        // name of the archive the resource came from
}

const usz MAX_SLOTS = 8;
const usz MAX_PAKS = 4;

struct Manager
{
    Pak[MAX_PAKS] paks;
    usz pak_count;
    Slot[MAX_SLOTS] slots;
    HashMap{ResourceId, uint} cache;
    int pak_lookups;      // how many times acquire had to search the archives
}

fn void Manager.init(&self)
{
    self.cache.init(mem);
    foreach (&s : self.slots) s.generation = 1;
}

fn void Manager.free(&self) => self.cache.free();

fn void? Manager.mount(&self, String name, char[] blob)
{
    assert(self.pak_count < MAX_PAKS);
    self.paks[self.pak_count].mount(name, blob)!;
    self.pak_count++;
}

fn Handle? Manager.acquire(&self, String path)
{
    ResourceId id = path_id(path);
    // TODO:
    //  1. id in self.cache -> refcount++ and return that slot's handle.
    //  2. Otherwise self.pak_lookups++ and walk the archives from the LAST to the first
    //     (`for (usz p = self.pak_count; p > 0; p--)`): the first one where find()
    //     succeeds provides the data. Take a free slot (refcount == 0):
    //     id, refcount = 1, data, source = pak.name; record it in cache.
    //     No free slots -> OUT_OF_SLOTS~.
    //  3. Not in any archive -> NOT_FOUND~.
    return NOT_FOUND~;
}

fn Slot*? Manager.slot_of(&self, Handle h)
{
    if (h.generation == 0 || h.index >= MAX_SLOTS) return STALE_HANDLE~;
    Slot* s = &self.slots[h.index];
    if (s.refcount == 0 || s.generation != h.generation) return STALE_HANDLE~;
    return s;
}

fn String? Manager.get(&self, Handle h) => self.slot_of(h).data;

fn void? Manager.release(&self, Handle h)
{
    Slot* s = self.slot_of(h)!;
    if (--s.refcount == 0)
    {
        self.cache.remove(s.id);
        s.generation++;
        s.data = "";
    }
}

// ======================================================= test
fn void main()
{
    // --- tools: build two archives and write them to disk ---
    SourceFile[*] base_files = {
        { "textures/hero.tex", "hero texture v1" },
        { "textures/tree.tex", "tree" },
        { "sounds/jump.wav",   "boing boing boing boing!" },
        { "config/game.ini",   "gravity=9.81" },
        { "levels/intro.lvl",  "intro level data" },
    };
    SourceFile[*] patch_files = {
        { "Textures\\Hero.tex", "hero texture v2 (patched)" },
        { "levels/bonus.lvl",   "bonus level (DLC)" },
    };
    List{char} out;
    out.init(mem);
    defer out.free();
    build_pak(&base_files, &out)!!;
    file::save("e0706_base.pak", out.array_view())!!;
    io::printfn("base.pak: %d bytes, toc at %d", out.len(), get_u32(out.array_view(), 12));
    out.clear();
    build_pak(&patch_files, &out)!!;
    file::save("e0706_patch.pak", out.array_view())!!;
    io::printfn("patch.pak: %d bytes", out.len());

    SourceFile[*] dup = { { "a/b.tex", "1" }, { "A\\B.TEX", "2" } };
    out.clear();
    assert(@catch(build_pak(&dup, &out)) == DUPLICATE_PATH, "two paths with the same id must be rejected");

    // --- runtime: read the archives from disk and mount them ---
    char[] base_blob = file::load(mem, "e0706_base.pak")!!;
    defer free(base_blob);
    char[] patch_blob = file::load(mem, "e0706_patch.pak")!!;
    defer free(patch_blob);

    Manager m;
    m.init();
    defer m.free();
    m.mount("base", base_blob)!!;
    Pak* base = &m.paks[0];
    assert(base.count == 5);
    for (usz i = 1; i < base.count; i++) assert(base.toc_id(i - 1) < base.toc_id(i), "TOC must be sorted by id");
    foreach (f : base_files)
    {
        char[] d = base.find(path_id(f.path))!!;
        assert((String)d == f.data, "wrong data for %s", f.path);
        assert((usz)(d.ptr - base_blob.ptr) % ALIGN == 0, "%s is not 16-byte aligned", f.path);
        assert(d.ptr >= base_blob.ptr && d.ptr < base_blob.ptr + base_blob.len, "find must not copy");
    }
    assert(base.probes <= 5 * 3, "binary search should need at most 3 probes for 5 entries");
    assert(@catch(base.find(path_id("nope.tex"))) == NOT_FOUND);

    io::printn("-- base only --");
    Handle hero = m.acquire("textures/hero.tex")!!;
    io::printfn("hero  -> '%s' from %s", m.get(hero)!!, m.slots[hero.index].source);
    m.release(hero)!!;

    m.mount("patch", patch_blob)!!;
    io::printn("-- base + patch --");
    Handle hero2 = m.acquire("TEXTURES/HERO.TEX")!!;
    Handle tree = m.acquire("textures/tree.tex")!!;
    Handle bonus = m.acquire("levels/bonus.lvl")!!;
    io::printfn("hero  -> '%s' from %s", m.get(hero2)!!, m.slots[hero2.index].source);
    io::printfn("tree  -> '%s' from %s", m.get(tree)!!, m.slots[tree.index].source);
    io::printfn("bonus -> '%s' from %s", m.get(bonus)!!, m.slots[bonus.index].source);
    assert(m.get(hero2)!! == "hero texture v2 (patched)", "patch must override base");
    assert(m.slots[tree.index].source == "base", "files absent from the patch come from base");
    assert(@catch(m.get(hero)) == STALE_HANDLE, "released handle must be stale");

    int lookups = m.pak_lookups;
    Handle tree2 = m.acquire("textures/tree.tex")!!;
    assert(m.pak_lookups == lookups, "second acquire must hit the cache");
    assert(tree2.index == tree.index && m.slots[tree.index].refcount == 2);
    assert(@catch(m.acquire("textures/missing.tex")) == NOT_FOUND);

    m.release(tree)!!;
    m.release(tree2)!!;
    m.release(hero2)!!;
    m.release(bonus)!!;
    assert(m.cache.len() == 0, "everything released");
    io::printfn("pak lookups: %d, all resources released", m.pak_lookups);
    file::delete("e0706_base.pak");
    file::delete("e0706_patch.pak");
}
