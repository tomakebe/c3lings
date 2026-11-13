// =====================================================================
//  e1403 · API «скрипт <-> сущности»: хендлы вместо указателей
// =====================================================================
//
//  Сначала прочитайте engine/docs/14_scripting.md (раздел «Объекты
//  движка в скрипте»).
//
//  Скрипт живёт дольше, чем вы думаете. Он сохранил «цель» в глобальную
//  переменную, подождал три секунды — а цель за это время умерла, и её
//  слот занял новый враг. Если скрипт хранил Entity*, он теперь молча
//  портит чужую сущность (или освобождённую память). Это классический
//  баг «use-after-free через скрипт», и его не поймает ни один assert.
//
//  Решение всех взрослых движков — скрипт видит только ХЕНДЛ:
//
//      31 ........ 12 11 ...... 0
//      [ generation ][   index   ]
//
//  * index — номер слота в массиве сущностей;
//  * generation — сколько раз слот переиспользовали. При destroy()
//    поколение слота увеличивается, и все старые хендлы протухают.
//  * поколения начинаются с 1, значит хендл 0 никогда не валиден и
//    служит «null» для скрипта.
//
//  Каждый натив превращает хендл в указатель через ОДНУ функцию —
//  World.resolve() — и не сохраняет указатель дольше вызова. Протухший
//  хендл даёт ошибку STALE_HANDLE (строгие нативы: damage, move, get_hp)
//  или просто ответ 0 («мягкий» натив alive). Какой стиль выбрать —
//  вопрос дизайна API; обычно есть оба.
//
//  Это та же идея, что слот-карта из главы 03, только теперь её
//  «клиент» — недоверенный код.
//
//  ЗАДАЧА:
//    * make_handle / handle_index / handle_gen — упаковка по схеме выше;
//    * World.destroy — не забудьте «протухнуть» старые хендлы;
//    * World.resolve — индекс в пределах выданных слотов, слот жив,
//      поколение совпадает; иначе STALE_HANDLE.
//
module entity_api;
import std::io;

excuse STACK_OVERFLOW, STACK_UNDERFLOW, STALE_HANDLE, WORLD_FULL;

// ---------------------------------------------------------------- world

// Скрипт никогда не видит Entity*. Он видит только int-хендл:
//
//     31 ........ 12 11 ...... 0
//     [ generation ][   index   ]
//
// generation начинается с 1, поэтому хендл 0 никогда не валиден
// («null-хендл» для скрипта).
const int INDEX_BITS = 12;
const int INDEX_MASK = (1 << INDEX_BITS) - 1;
const int MAX_ENTITIES = 4;

fn int make_handle(int index, int gen) => (gen << INDEX_BITS) | index;
fn int handle_index(int h) => h & INDEX_MASK;
fn int handle_gen(int h) => h >> INDEX_BITS;

struct Entity
{
    int gen;      // текущее поколение слота
    bool alive;
    int x;
    int hp;
}

struct World
{
    Entity[MAX_ENTITIES] slots;
    int[MAX_ENTITIES] free_list;
    int free_count;
    int used;     // сколько слотов вообще когда-либо выдано
}

fn int? World.spawn(&self, int x, int hp)
{
    int index;
    if (self.free_count > 0)
    {
        index = self.free_list[--self.free_count];
    }
    else
    {
        if (self.used >= MAX_ENTITIES) return WORLD_FULL~;
        index = self.used++;
        self.slots[index].gen = 1;
    }
    Entity* e = &self.slots[index];
    e.alive = true;
    e.x = x;
    e.hp = hp;
    return make_handle(index, e.gen);
}

fn void World.destroy(&self, int index)
{
    Entity* e = &self.slots[index];
    e.alive = false;
    e.gen++;                         // все старые хендлы на этот слот протухли
    self.free_list[self.free_count++] = index;
}

// Единственная дверь из «мира хендлов» в «мир указателей».
// Указатель живёт только внутри одного натива и никуда не сохраняется.
fn Entity*? World.resolve(&self, int h)
{
    int index = handle_index(h);
    if (index >= self.used) return STALE_HANDLE~;
    Entity* e = &self.slots[index];
    if (!e.alive || e.gen != handle_gen(h)) return STALE_HANDLE~;
    return e;
}

// ---------------------------------------------------------------- natives

alias NativeFn = fn int?(int[] args, void* ctx);
struct Native { String name; int arity; NativeFn func; }

fn int? n_spawn(int[] a, void* ctx) => ((World*)ctx).spawn(a[0], a[1]);

// «мягкий» запрос: протухший хендл — не ошибка, а ответ «нет»
fn int? n_alive(int[] a, void* ctx) => @ok(((World*)ctx).resolve(a[0])) ? 1 : 0;

fn int? n_get_hp(int[] a, void* ctx)
{
    Entity* e = ((World*)ctx).resolve(a[0])!;
    return e.hp;
}

// damage(h, amount) -> оставшееся hp; при hp <= 0 сущность уничтожается
fn int? n_damage(int[] a, void* ctx)
{
    World* w = ctx;
    Entity* e = w.resolve(a[0])!;
    e.hp -= a[1];
    if (e.hp > 0) return e.hp;
    w.destroy(handle_index(a[0]));
    return 0;
}

fn int? n_move(int[] a, void* ctx)
{
    Entity* e = ((World*)ctx).resolve(a[0])!;
    e.x += a[1];
    return e.x;
}

const Native[] NATIVES = {
    { "spawn", 2, &n_spawn },
    { "alive", 1, &n_alive },
    { "get_hp", 1, &n_get_hp },
    { "damage", 2, &n_damage },
    { "move", 2, &n_move },
};
const int SPAWN = 0;
const int ALIVE = 1;
const int GET_HP = 2;
const int DAMAGE = 3;
const int MOVE = 4;

// ---------------------------------------------------------------- VM

enum Op : char { PUSH, POP, LOAD, STORE, CALL, HALT }
struct Instr { Op op; int arg; }

struct Vm
{
    int[16] stack;
    int sp;
    int[8] globals;   // скрипт хранит здесь хендлы между вызовами
    void* ctx;
}

fn void? Vm.push(&self, int v)
{
    if (self.sp >= 16) return STACK_OVERFLOW~;
    self.stack[self.sp++] = v;
}

fn int? Vm.pop(&self)
{
    if (self.sp <= 0) return STACK_UNDERFLOW~;
    return self.stack[--self.sp];
}

fn int? Vm.run(&self, Instr[] code)
{
    self.sp = 0;
    foreach (ins : code)
    {
        switch (ins.op)
        {
            case PUSH: self.push(ins.arg)!;
            case POP: self.pop()!;
            case LOAD: self.push(self.globals[ins.arg])!;
            case STORE: self.globals[ins.arg] = self.pop()!;
            case CALL:
                Native n = NATIVES[ins.arg];
                if (self.sp < n.arity) return STACK_UNDERFLOW~;
                int base = self.sp - n.arity;
                int r = n.func(self.stack[base:n.arity], self.ctx)!;
                self.sp = base;
                self.push(r)!;
            case HALT: return self.pop()!;
        }
    }
    return self.sp > 0 ? self.pop()! : 0;
}

fn void main()
{
    // --- сначала сами хендлы
    int h = make_handle(3, 5);
    assert(handle_index(h) == 3 && handle_gen(h) == 5);
    assert(make_handle(0, 1) != 0, "handle 0 must stay invalid");

    World world;
    Vm vm = { .ctx = &world };

    // g0 = spawn(10, 30)  -- гоблин
    // g1 = spawn(50, 100) -- орк
    Instr[] setup = {
        { PUSH, 10 }, { PUSH, 30 }, { CALL, SPAWN }, { STORE, 0 },
        { PUSH, 50 }, { PUSH, 100 }, { CALL, SPAWN }, { STORE, 1 },
    };
    vm.run(setup)!!;
    io::printfn("goblin = %d (index %d, gen %d)", vm.globals[0], handle_index(vm.globals[0]), handle_gen(vm.globals[0]));
    io::printfn("orc    = %d (index %d, gen %d)", vm.globals[1], handle_index(vm.globals[1]), handle_gen(vm.globals[1]));

    // damage(goblin, 12) дважды; move(orc, -5)
    Instr[] fight = {
        { LOAD, 0 }, { PUSH, 12 }, { CALL, DAMAGE }, { POP, 0 },
        { LOAD, 1 }, { PUSH, -5 }, { CALL, MOVE }, { POP, 0 },
        { LOAD, 0 }, { PUSH, 12 }, { CALL, DAMAGE },
    };
    int hp = vm.run(fight)!!;
    assert(hp == 6, "goblin hp %d", hp);
    io::printfn("goblin hp after two hits: %d, orc x: %d", hp, world.resolve(vm.globals[1])!!.x);

    // добиваем гоблина -> слот освобождается
    Instr[] kill = { { LOAD, 0 }, { PUSH, 100 }, { CALL, DAMAGE }, { POP, 0 }, { LOAD, 0 }, { CALL, ALIVE } };
    int alive = vm.run(kill)!!;
    assert(alive == 0);
    io::printfn("goblin alive: %d", alive);

    // g2 = spawn(0, 7) -- новый враг занимает ТОТ ЖЕ слот, но с другим поколением
    Instr[] respawn = { { PUSH, 0 }, { PUSH, 7 }, { CALL, SPAWN }, { STORE, 2 } };
    vm.run(respawn)!!;
    int old_h = vm.globals[0];
    int new_h = vm.globals[2];
    io::printfn("bat    = %d (index %d, gen %d)", new_h, handle_index(new_h), handle_gen(new_h));
    assert(handle_index(new_h) == handle_index(old_h), "slot must be reused");
    assert(new_h != old_h, "generation must differ");

    // скрипт держит старый хендл гоблина. С указателем он бы сейчас
    // молча бил летучую мышь. С хендлом — получает отказ.
    Instr[] stale = { { LOAD, 0 }, { PUSH, 1 }, { CALL, DAMAGE } };
    int? r = vm.run(stale);
    if (catch err = r) io::printfn("damage(old goblin): %s", err);
    assert(@catch(r) == STALE_HANDLE);
    assert(world.resolve(new_h)!!.hp == 7, "the bat must be untouched");

    Instr[] q = { { LOAD, 0 }, { CALL, ALIVE }, { LOAD, 2 }, { CALL, ALIVE }, { CALL, SPAWN } };
    // хитрость: spawn(alive(old), alive(new)) = spawn(0, 1) -- просто чтобы прочитать оба ответа
    int h3 = vm.run(q)!!;
    Entity* e3 = world.resolve(h3)!!;
    io::printfn("alive(old) = %d, alive(new) = %d", e3.x, e3.hp);
    assert(e3.x == 0 && e3.hp == 1);

    // мусорные хендлы
    assert(@catch(world.resolve(0)) == STALE_HANDLE);
    assert(@catch(world.resolve(make_handle(3, 1))) == STALE_HANDLE);
    assert(@catch(world.resolve(12345)) == STALE_HANDLE);

    // мир полон
    assert(world.spawn(1, 1)!! != 0);
    assert(@catch(world.spawn(1, 1)) == WORLD_FULL);

    io::printn("entity api ok");
}
