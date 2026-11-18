// =====================================================================
//  e0702 · Resource manager: handles, generations and reference counting
// =====================================================================
//
//  Read engine/docs/07_resources.md first (sections "Handles
//  instead of pointers" and "Lifetime: reference counting").
//
//  Game code should not hold a `Texture*`: the resource may be unloaded,
//  reloaded (hot reload) or moved in memory. Instead of a pointer it
//  holds Handle { index, generation }:
//
//      slots:   [0]          [1]          [2]
//               gen=3        gen=1        gen=2
//               hero.png     tree.png     (free)
//
//      Handle{0, 3} -> valid
//      Handle{0, 2} -> stale: the slot has been reused -> STALE_HANDLE
//
//  generation == 0 is reserved for the "null" handle, so live
//  slots always have generation >= 1.
//
//  Resources are shared: ten objects with one texture means one load.
//  The manager looks up an already loaded resource by ResourceId (path hash) and
//  increments its reference count. release() decrements it.
//
//  An important detail from real engines: when refcount == 0 the resource is NOT
//  unloaded immediately. The typical "level change" pattern is to release
//  everything old and immediately request the new stuff; half the assets are shared, and
//  unloading immediately would mean unloading and reloading the same files
//  ("thrashing"). So resources with zero references stay loaded until an
//  explicit collect() (once per frame / on level change), and acquire() can
//  "resurrect" them without reloading.
//
//  TASK: implement the methods marked TODO:
//    * acquire(path)  — find by id or take a free slot and "load";
//    * get(h)         — validate the handle, return a pointer to the data;
//    * retain(h)      — +1 reference (an owner copies the handle);
//    * release(h)     — -1 reference, no unloading; releasing
//                       an "extra" handle must produce an error;
//    * collect()      — unload all slots with refcount == 0.
//  Free slots come from the free_list stack (last freed —
//  first taken).
//
import std::io;
import std::collections::map;

excuse STALE_HANDLE, OUT_OF_SLOTS, OVER_RELEASE;

typedef ResourceId = inline ulong;

fn ResourceId path_id(String path)
{
    ulong h = 0xcbf29ce484222325;
    foreach (c : path) h = (h ^ c) * 0x100000001b3;
    return (ResourceId)h;
}

struct Handle
{
    uint index;
    uint generation;   // 0 => null handle
}

// "Loaded data". In a real engine this would be a GPU object.
struct Texture
{
    int width;
    int height;
}

struct Slot
{
    ResourceId id;
    String path;       // for logs; points to a string literal
    uint generation;
    uint refcount;
    bool loaded;
    Texture data;
}

const usz MAX_SLOTS = 4;

struct TextureManager
{
    Slot[MAX_SLOTS] slots;
    uint[MAX_SLOTS] free_list;  // stack of free slot indices
    usz free_count;
    HashMap{ResourceId, uint} by_id; // id -> slot index (loaded only)
    int loads;
    int unloads;
}

fn void TextureManager.init(&self)
{
    self.by_id.init(mem);
    // Slot 0 must be handed out first -> push indices in reverse order.
    for (usz i = 0; i < MAX_SLOTS; i++)
    {
        self.slots[i].generation = 1;
        self.free_list[i] = (uint)(MAX_SLOTS - 1 - i);
    }
    self.free_count = MAX_SLOTS;
}

fn void TextureManager.free(&self) => self.by_id.free();

// Simulated disk load: the size depends on the path but is deterministic.
fn Texture fake_load(String path) => { (int)path.len * 16, (int)path.len * 8 };

fn void TextureManager.do_load(&self, uint index, String path)
{
    Slot* s = &self.slots[index];
    s.id = path_id(path);
    s.path = path;
    s.refcount = 1;
    s.loaded = true;
    s.data = fake_load(path);
    self.by_id.set(s.id, index);
    self.loads++;
    io::printfn("  load   %-10s slot=%d gen=%d", path, index, s.generation);
}

fn void TextureManager.do_unload(&self, uint index)
{
    Slot* s = &self.slots[index];
    io::printfn("  unload %-10s slot=%d gen=%d", s.path, index, s.generation);
    self.by_id.remove(s.id);
    s.loaded = false;
    s.generation++;            // all old handles to this slot go stale
    s.data = {};
    self.free_list[self.free_count++] = index;
    self.unloads++;
}

fn Handle? TextureManager.acquire(&self, String path)
{
    ResourceId id = path_id(path);
    if (try index = self.by_id.get(id))
    {
        Slot* s = &self.slots[index];
        s.refcount++;
        return { index, s.generation };
    }
    if (self.free_count == 0) return OUT_OF_SLOTS~;
    uint index = self.free_list[--self.free_count];
    self.do_load(index, path);
    return { index, self.slots[index].generation };
}

fn Slot*? TextureManager.slot_of(&self, Handle h)
{
    if (h.generation == 0 || h.index >= MAX_SLOTS) return STALE_HANDLE~;
    Slot* s = &self.slots[h.index];
    if (!s.loaded || s.generation != h.generation) return STALE_HANDLE~;
    return s;
}

fn Texture*? TextureManager.get(&self, Handle h)
{
    Slot* s = self.slot_of(h)!;
    return &s.data;
}

fn void? TextureManager.retain(&self, Handle h)
{
    Slot* s = self.slot_of(h)!;
    s.refcount++;
}

fn void? TextureManager.release(&self, Handle h)
{
    Slot* s = self.slot_of(h)!;
    if (s.refcount == 0) return OVER_RELEASE~;
    s.refcount--;
}

fn int TextureManager.collect(&self)
{
    int n = 0;
    for (uint i = 0; i < MAX_SLOTS; i++)
    {
        if (self.slots[i].loaded && self.slots[i].refcount == 0)
        {
            self.do_unload(i);
            n++;
        }
    }
    return n;
}

fn uint TextureManager.refs(&self, Handle h) => self.slot_of(h).refcount ?? 0;

fn void main()
{
    TextureManager tm;
    tm.init();
    defer tm.free();

    io::printn("level 1:");
    Handle hero = tm.acquire("hero.png")!!;
    Handle hero2 = tm.acquire("hero.png")!!;     // shared resource
    Handle tree = tm.acquire("tree.png")!!;
    assert(hero.index == 0 && hero.generation == 1, "first slot must be 0 with gen 1");
    assert(hero.index == hero2.index && hero.generation == hero2.generation,
           "the same path must give the same handle");
    assert(tm.loads == 2, "hero.png must be loaded only once (loads=%d)", tm.loads);
    assert(tm.refs(hero) == 2);
    assert(tm.get(tree)!!.width == 8 * 16);

    tm.retain(tree)!!;                           // someone copied the handle
    assert(tm.refs(tree) == 2);

    io::printn("level switch: release everything, then acquire level 2");
    tm.release(hero)!!;
    tm.release(hero2)!!;
    tm.release(tree)!!;
    tm.release(tree)!!;
    assert(tm.refs(hero) == 0 && tm.refs(tree) == 0);
    assert(tm.unloads == 0, "release must not unload immediately");
    assert(@catch(tm.release(tree)) == OVER_RELEASE, "releasing more than acquired must fail");

    Handle tree_again = tm.acquire("tree.png")!!;   // shared between levels
    Handle rock = tm.acquire("rock.png")!!;
    assert(tree_again.index == tree.index && tree_again.generation == tree.generation,
           "tree.png had zero refs but was still loaded: it must be resurrected, not reloaded");
    assert(tm.loads == 3, "only rock.png should have been loaded (loads=%d)", tm.loads);

    io::printn("end of frame: collect");
    int freed = tm.collect();
    assert(freed == 1, "only hero.png had zero refs");
    assert(@catch(tm.get(hero)) == STALE_HANDLE, "handle to an unloaded resource must be stale");

    io::printn("reuse freed slot:");
    Handle bush = tm.acquire("bush.png")!!;
    assert(bush.index == hero.index, "freed slot must be reused (LIFO free list)");
    assert(bush.generation == hero.generation + 1, "generation must grow on reuse");
    assert(@catch(tm.get(hero)) == STALE_HANDLE, "old handle must not alias the new resource");
    assert(@catch(tm.release(hero)) == STALE_HANDLE);
    assert(@catch(tm.get({})) == STALE_HANDLE, "null handle must be invalid");

    Handle grass = tm.acquire("grass.png")!!;
    assert(@catch(tm.acquire("sky.png")) == OUT_OF_SLOTS, "pool has only 4 slots");

    io::printn("shutdown:");
    tm.release(tree_again)!!;
    tm.release(rock)!!;
    tm.release(bush)!!;
    tm.release(grass)!!;
    assert(tm.collect() == 4);
    io::printfn("loads=%d unloads=%d", tm.loads, tm.unloads);
    assert(tm.loads == tm.unloads, "every load must be matched by an unload");
}
