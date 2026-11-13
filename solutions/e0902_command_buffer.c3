// =====================================================================
//  e0902 · Командный буфер: фронтенд, radix sort, бэкенд
// =====================================================================
//
//  Сначала прочитайте engine/docs/09_rendering.md (разделы
//  «Фронтенд и бэкенд» и «Командный буфер»).
//
//  Рендерер делят на две половины:
//
//    фронтенд  — знает про сцену, камеры, материалы. Обходит видимые
//                объекты и ЗАПИСЫВАЕТ команды в буфер: «нарисуй меш M
//                материалом X шейдером S». Сам GPU не трогает.
//    бэкенд    — знает только графический API. Читает отсортированный
//                буфер и превращает команды в вызовы API (bind/draw).
//
//  Между ними — сортировка по 64-битному ключу. Сортируем не сами
//  команды (они могут быть большими), а пары {key, index}: 16 байт на
//  команду, хорошо ложится в кеш.
//
//  Для u64-ключей идеален LSD radix sort: 8 проходов по байтам, начиная
//  с младшего. Каждый проход — устойчивая сортировка подсчётом:
//
//      1) гистограмма: count[b]++ для байта b каждого ключа;
//      2) префиксные суммы: offset[b] = сумма count[0..b-1];
//      3) раскладка: dst[offset[b]++] = src[i]   (по порядку i!)
//      4) поменять src и dst местами.
//
//  Устойчивость (равные байты сохраняют относительный порядок) — это
//  то, что делает LSD-вариант корректным: старшие проходы не ломают
//  порядок, выстроенный младшими. Сложность O(8·n) без сравнений;
//  после чётного числа проходов результат снова лежит в исходном
//  массиве.
//
//  Бэкенд должен быть «stateful»: он помнит, какие шейдер/материал/меш
//  сейчас привязаны, и не делает повторный bind того же самого.
//  Именно поэтому ключ упорядочен shader > material > mesh — самая
//  дорогая смена состояния (шейдер, т.е. PSO) происходит реже всего.
//  Обратите внимание: при смене шейдера материал и меш тоже нужно
//  считать «сброшенными» — новый пайплайн требует заново выставить
//  ресурсы. (Это упрощённая, но реалистичная модель.)
//
//  ЗАДАЧА:
//    1) реализуйте `radix_sort` (LSD, 8 проходов по 8 бит, устойчиво);
//    2) в `Backend.execute` пропускайте избыточные bind'ы
//       (и сбрасывайте материал/меш при смене шейдера).
//
import std::io;

bitstruct RenderKey : ulong
{
    ushort seq      : 0..15;   // порядковый номер записи (стабильность)
    ushort mesh     : 16..31;
    ushort material : 32..47;
    ushort shader   : 48..63;  // самое дорогое — в старших битах
}

struct DrawCmd
{
    ushort shader;
    ushort material;
    ushort mesh;
    ushort instance;
}

struct SortItem
{
    ulong key;
    uint index;
}

const usz MAX_CMDS = 128;

struct CommandBuffer
{
    DrawCmd[MAX_CMDS] cmds;
    SortItem[MAX_CMDS] items;
    SortItem[MAX_CMDS] scratch;
    uint count;
}

fn void CommandBuffer.reset(&self) => self.count = 0;

fn void CommandBuffer.draw(&self, DrawCmd cmd)
{
    assert(self.count < MAX_CMDS, "command buffer overflow");
    RenderKey k = { .shader = cmd.shader, .material = cmd.material, .mesh = cmd.mesh,
                    .seq = (ushort)self.count };
    self.cmds[self.count] = cmd;
    self.items[self.count] = { (ulong)k, self.count };
    self.count++;
}

<*
 LSD radix sort пар по полю key. Результат должен оказаться в `items`.
 `scratch` — временный буфер того же размера.
 @require scratch.len >= items.len
*>
fn void radix_sort(SortItem[] items, SortItem[] scratch)
{
    // TODO
    SortItem[] src = items;
    SortItem[] dst = scratch[:items.len];
    for (uint pass = 0; pass < 8; pass++)
    {
        uint shift = pass * 8;
        uint[256] count;
        foreach (it : src) count[(it.key >> shift) & 0xFF]++;
        uint sum = 0;
        foreach (&c : count)
        {
            uint n = *c;
            *c = sum;
            sum += n;
        }
        foreach (it : src) dst[count[(it.key >> shift) & 0xFF]++] = it;
        SortItem[] t = src;
        src = dst;
        dst = t;
    }
    // 8 проходов — чётное число, результат снова в items.
}

struct Backend
{
    int cur_shader;
    int cur_material;
    int cur_mesh;
    uint shader_binds;
    uint material_binds;
    uint mesh_binds;
    uint draws;
    bool verbose;
}

fn void Backend.begin_frame(&self)
{
    *self = { .cur_shader = -1, .cur_material = -1, .cur_mesh = -1, .verbose = self.verbose };
}

// «Вызовы графического API». В настоящем движке тут был бы Vulkan/D3D12.
fn void Backend.api_bind_shader(&self, int s)   { self.shader_binds++;   if (self.verbose) io::printfn("  bind shader   %d", s); }
fn void Backend.api_bind_material(&self, int m) { self.material_binds++; if (self.verbose) io::printfn("  bind material %d", m); }
fn void Backend.api_bind_mesh(&self, int m)     { self.mesh_binds++;     if (self.verbose) io::printfn("  bind mesh     %d", m); }
fn void Backend.api_draw(&self, int inst)       { self.draws++;          if (self.verbose) io::printfn("  draw instance %d", inst); }

fn void Backend.execute(&self, CommandBuffer* cb, bool sorted)
{
    for (uint i = 0; i < cb.count; i++)
    {
        DrawCmd* c = &cb.cmds[sorted ? cb.items[i].index : i];
        // TODO: не делайте bind, если нужное состояние уже выставлено.
        if (c.shader != self.cur_shader)
        {
            self.api_bind_shader(c.shader);
            self.cur_shader = c.shader;
            self.cur_material = -1;
            self.cur_mesh = -1;
        }
        if (c.material != self.cur_material)
        {
            self.api_bind_material(c.material);
            self.cur_material = c.material;
        }
        if (c.mesh != self.cur_mesh)
        {
            self.api_bind_mesh(c.mesh);
            self.cur_mesh = c.mesh;
        }
        self.api_draw(c.instance);
    }
}

// ---------------------------------------------------------------------
// Ниже менять ничего не нужно.

uint rng_state = 12345;
fn uint rng()
{
    rng_state = rng_state * 1103515245 + 12345;
    return (rng_state >> 16) & 0x7FFF;
}

fn void test_radix()
{
    SortItem[100] a;
    SortItem[100] ref;
    SortItem[100] tmp;
    foreach (i, &it : a)
    {
        // Много повторов и все байты задействованы.
        ulong hi = (ulong)(rng() % 4) << 60;
        ulong mid = (ulong)(rng() % 3) << 29;
        ulong lo = (ulong)(rng() % 5);
        *it = { hi | mid | lo, (uint)i };
    }
    ref = a;
    // Эталон: устойчивая сортировка вставками.
    for (usz i = 1; i < ref.len; i++)
    {
        SortItem x = ref[i];
        usz j = i;
        while (j > 0 && ref[j - 1].key > x.key) { ref[j] = ref[j - 1]; j--; }
        ref[j] = x;
    }
    radix_sort(a[..], tmp[..]);
    foreach (i, it : a)
    {
        assert(it.key == ref[i].key, "radix_sort: wrong key order at %d", i);
        assert(it.index == ref[i].index, "radix_sort: not stable at %d", i);
    }
    // Пустой массив и один элемент не должны ломаться.
    radix_sort(a[0:0], tmp[..]);
    SortItem[1] one = { { 42, 7 } };
    radix_sort(one[..], tmp[..]);
    assert(one[0].key == 42 && one[0].index == 7);
    io::printn("radix_sort: 100 keys sorted, stable");
}

fn void record_frame(CommandBuffer* cb)
{
    cb.reset();
    // Обход «сцены» выдаёт объекты вперемешку.
    for (ushort i = 0; i < 24; i++)
    {
        ushort shader = (ushort)(i % 3);
        ushort material = (ushort)((i * 7) % 4);
        ushort mesh = (ushort)((i * 5) % 3);
        cb.draw({ .shader = shader, .material = material, .mesh = mesh, .instance = i });
    }
}

fn void main()
{
    test_radix();

    CommandBuffer cb;
    Backend be;

    record_frame(&cb);
    be.begin_frame();
    be.execute(&cb, false);
    io::printfn("unsorted: shader=%d material=%d mesh=%d draws=%d",
                be.shader_binds, be.material_binds, be.mesh_binds, be.draws);
    assert(be.draws == 24);
    assert(be.shader_binds == 24, "unsorted: every draw switches shader");

    radix_sort(cb.items[:cb.count], cb.scratch[..]);
    be.begin_frame();
    be.execute(&cb, true);
    io::printfn("sorted:   shader=%d material=%d mesh=%d draws=%d",
                be.shader_binds, be.material_binds, be.mesh_binds, be.draws);
    assert(be.shader_binds == 3);
    assert(be.material_binds == 12);
    assert(be.mesh_binds == 3, "mesh survives a material change");
    assert(be.draws == 24);

    // Маленький кадр с подробным логом.
    cb.reset();
    cb.draw({ 1, 2, 9, 100 });
    cb.draw({ 0, 5, 3, 101 });
    cb.draw({ 1, 2, 9, 102 });
    cb.draw({ 0, 5, 4, 103 });
    cb.draw({ 1, 1, 9, 104 });
    radix_sort(cb.items[:cb.count], cb.scratch[..]);
    be.verbose = true;
    be.begin_frame();
    io::printn("frame log:");
    be.execute(&cb, true);
    assert(be.shader_binds == 2 && be.material_binds == 3 && be.mesh_binds == 3 && be.draws == 5);
    io::printn("backend ok");
}
