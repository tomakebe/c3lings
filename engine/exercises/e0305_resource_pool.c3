// =====================================================================
//  E0305 · Пул ресурсов с типизированными handles и отложенным удалением
// =====================================================================
//
//  Сначала прочитайте engine/docs/03_containers.md (весь).
//
//  Соберём идеи главы в настоящую подсистему — пул GPU-ресурсов
//  (текстуры, меши), как в sokol_gfx или в RHI больших движков:
//
//  1. ТИПИЗИРОВАННЫЕ handles. `typedef TextureHandle = uint;` и
//     `typedef MeshHandle = uint;` — разные типы: передать MeshHandle
//     туда, где ждут TextureHandle, — ошибка компиляции. Пул generic по
//     двум параметрам: типу ресурса и типу handle:
//         struct ResourcePool <Type, HandleT> { ... }
//     Внутри handle — тот же формат, что в E0302: [gen:12][index:20],
//     поколения с 1, handle 0 — «нет ресурса».
//
//  2. Хранилище — массив слотов фиксированной ёмкости без плотного
//     массива (как в sokol_gfx): данные лежат прямо в слоте, свободные
//     слоты связаны в список (LIFO, через поле next_free). Адрес ресурса
//     стабилен, пока ресурс жив.
//
//  3. ОТЛОЖЕННОЕ удаление. GPU отстаёт от CPU на FRAMES_IN_FLIGHT кадров:
//     если удалить текстуру сразу, GPU может ещё рисовать ею кадр N-1.
//     Поэтому release(h, frame) делает handle недействительным СРАЗУ
//     (поколение++ — новые обращения получают null), но сам слот кладёт
//     в очередь отложенного удаления с номером кадра. collect(frame)
//     действительно уничтожает (вызывает destroy_fn и возвращает слот
//     в свободный список) только записи, у которых
//         frame - release_frame >= FRAMES_IN_FLIGHT.
//     Слот из очереди нельзя выдать заново раньше времени.
//
//  ЗАДАЧА: реализуйте методы ResourcePool, помеченные TODO:
//  create, get, release, collect.
//
import std::io;

const uint INDEX_BITS = 20;
const uint INDEX_MASK = (1u << INDEX_BITS) - 1;
const uint POOL_CAP = 8;
const ulong FRAMES_IN_FLIGHT = 2;

struct PoolSlot <Type>
{
    Type value;
    uint gen;
    uint next_free;
    bool alive;
}

struct Pending
{
    uint index;
    ulong frame;
}

alias DestroyFn = fn void(void* resource);

struct ResourcePool <Type, HandleT>
{
    PoolSlot{Type}[POOL_CAP] slots;
    uint free_head;          // POOL_CAP = пусто
    Pending[POOL_CAP] pending;
    uint pending_len;
    uint live;
    DestroyFn destroy_fn;
}

fn void ResourcePool.init(&self, DestroyFn destroy_fn)
{
    *self = {};
    self.destroy_fn = destroy_fn;
    for (uint i = 0; i < POOL_CAP; i++)
    {
        self.slots[i].gen = 1;
        self.slots[i].next_free = i + 1;   // 0 -> 1 -> ... -> POOL_CAP (конец)
    }
    self.free_head = 0;
}

fn HandleT ResourcePool.create(&self, Type value)
{
    // TODO: слот из головы свободного списка (POOL_CAP — список пуст,
    //       вернуть (HandleT)0); сохранить значение, alive, live++;
    //       handle = (gen << INDEX_BITS) | index
    return (HandleT)0;
}

fn Type* ResourcePool.get(&self, HandleT h)
{
    // TODO: распаковать индекс и поколение, проверить alive и gen
    return null;
}

fn bool ResourcePool.release(&self, HandleT h, ulong frame)
{
    // TODO: handle сразу становится недействительным (alive=false, gen++,
    //       live--), а слот — в очередь pending вместе с номером кадра
    return false;
}

// Возвращает число действительно уничтоженных ресурсов.
fn int ResourcePool.collect(&self, ulong frame)
{
    // TODO: уничтожить (destroy_fn) и вернуть в свободный список те записи
    //       pending, для которых frame - p.frame >= FRAMES_IN_FLIGHT;
    //       удалять из pending swap-remove'ом
    return 0;
}

// ---------------------------------------------------------------------

typedef TextureHandle = uint;
typedef MeshHandle = uint;

struct Texture { int width, height; int gpu_id; }
struct Mesh { int vertex_count; int gpu_id; }

int textures_destroyed;
int meshes_destroyed;
fn void destroy_texture(void* p) { textures_destroyed++; ((Texture*)p).gpu_id = -1; }
fn void destroy_mesh(void* p) { meshes_destroyed++; ((Mesh*)p).gpu_id = -1; }

alias TexturePool = ResourcePool{Texture, TextureHandle};
alias MeshPool = ResourcePool{Mesh, MeshHandle};

fn void draw(TexturePool* tp, MeshPool* mp, MeshHandle m, TextureHandle t)
{
    // draw(tp, mp, t, m);  <- не скомпилируется: handles разных типов
    Mesh* mesh = mp.get(m);
    Texture* tex = tp.get(t);
    if (mesh && tex) io::printfn("  draw mesh(%d verts) with texture %dx%d", mesh.vertex_count, tex.width, tex.height);
}

fn void main()
{
    TexturePool textures;
    MeshPool meshes;
    textures.init(&destroy_texture);
    meshes.init(&destroy_mesh);

    TextureHandle brick = textures.create({ 256, 256, 1 });
    TextureHandle grass = textures.create({ 512, 512, 2 });
    MeshHandle cube = meshes.create({ 24, 10 });
    assert((uint)brick != 0 && (uint)cube != 0, "valid handles are never 0");
    assert(textures.get(brick).gpu_id == 1 && textures.get(grass).width == 512);
    assert(textures.get((TextureHandle)0) == null, "handle 0 means 'no resource'");

    ulong frame = 10;
    io::printfn("frame %d:", frame);
    draw(&textures, &meshes, cube, brick);

    // Кадр 10: текстура brick больше не нужна.
    Texture* brick_ptr = textures.get(brick);
    assert(textures.release(brick, frame));
    assert(textures.get(brick) == null, "released handle is invalid immediately");
    assert(!textures.release(brick, frame), "double release");
    assert(textures.collect(frame) == 0, "GPU may still use it this frame");
    assert(brick_ptr.gpu_id == 1, "GPU-side data must survive until it's safe");

    // Пул почти полон, а слот brick ещё нельзя переиспользовать.
    TextureHandle[8] more;
    int created = 0;
    for (int i = 0; i < 8; i++)
    {
        more[i] = textures.create({ 16 * (i + 1), 16, 100 + i });
        if ((uint)more[i] != 0) created++;
    }
    io::printfn("created %d more textures while brick is pending (live=%d)", created, textures.live);
    assert(created == 6, "the pending slot must not be handed out");

    frame++;
    assert(textures.collect(frame) == 0, "1 frame later the GPU may still read it");
    frame++;
    int d = textures.collect(frame);
    io::printfn("frame %d: collected %d, destroyed so far %d", frame, d, textures_destroyed);
    assert(d == 1 && textures_destroyed == 1 && brick_ptr.gpu_id == -1);

    TextureHandle reuse = textures.create({ 1024, 1024, 7 });
    assert((uint)reuse != 0 && ((uint)reuse & INDEX_MASK) == ((uint)brick & INDEX_MASK), "the slot is free again");
    assert(textures.get(brick) == null && textures.get(reuse).width == 1024, "old handle stays dead");

    // Массовое освобождение: всё, кроме grass, в одном кадре.
    foreach (h : more[:created]) textures.release(h, frame);
    textures.release(reuse, frame);
    meshes.release(cube, frame);
    for (ulong f = frame; f < frame + 3; f++)
    {
        int dt = textures.collect(f);
        int dm = meshes.collect(f);
        io::printfn("frame %d: destroyed textures=%d meshes=%d", f, dt, dm);
    }
    io::printfn("live textures=%d meshes=%d; destroyed textures=%d meshes=%d",
                textures.live, meshes.live, textures_destroyed, meshes_destroyed);
    assert(textures.live == 1 && textures.get(grass).gpu_id == 2);
    assert(textures_destroyed == 8 && meshes_destroyed == 1);
    io::printn("resource pool OK");
}
