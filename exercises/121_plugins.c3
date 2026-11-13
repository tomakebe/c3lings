// =====================================================================
//  121 · Плагины: таблицы функций и интерфейсы
// =====================================================================
//
//  Движок, который можно расширять без перекомпиляции ядра: модули
//  рендера (Vulkan/D3D12), редакторские тулзы, моды, игровая логика с
//  горячей перезагрузкой (hot reload) DLL прямо во время игры. В основе
//  всего — граница между «хостом» и «плагином», проведённая через
//  ТАБЛИЦЫ ФУНКЦИЙ.
//
//  C-ABI ТАБЛИЦЫ (как в реальных движках)
//  --------------------------------------
//  Плагин из .so/.dll экспортирует ОДНУ функцию-точку входа (её находит
//  dlsym/GetProcAddress), которая возвращает описатель:
//
//      struct PluginApi {
//          uint abi_version;          // совпадает с версией хоста?
//          String name;
//          sz state_size;             // сколько памяти под состояние
//          InitFn init;               // обязательна
//          UpdateFn update;           // обязательна
//          EventFn on_event;          // НЕОБЯЗАТЕЛЬНА: может быть null
//          ShutdownFn shutdown;       // обязательна
//      }
//
//  А хост передаёт плагину свою таблицу сервисов (HostApi: логирование,
//  аллокатор, доступ к миру). Плагин не линкуется с движком напрямую —
//  он видит только эту таблицу. Так устроены The Machinery и Our
//  Machinery API registry, Godot GDExtension, Unreal modules (в C++-
//  обёртке), OBS, Vulkan (vkGetInstanceProcAddr), VST-плагины звука.
//
//  Ключевые решения:
//  * ВЕРСИЯ ABI: структура таблицы — контракт. Новый хост со старым
//    плагином должен отказать громко, а не позвать мусор по смещению.
//  * ОБЯЗАТЕЛЬНЫЕ И НЕОБЯЗАТЕЛЬНЫЕ функции: необязательную хост
//    проверяет на null перед вызовом; отсутствие обязательной — отказ
//    в загрузке.
//  * СОСТОЯНИЕ ПЛАГИНА ВЫДЕЛЯЕТ ХОСТ (state_size). Тогда при hot reload
//    DLL выгружается и загружается заново, а память состояния остаётся
//    у хоста — игра продолжает с того же места (приём из Handmade Hero
//    и The Machinery). Глобальные переменные в плагине при этом
//    теряются — поэтому их там не держат.
//  * ПОРЯДОК: инициализация в порядке загрузки, выгрузка — в ОБРАТНОМ
//    (как деструкторы и defer): поздние плагины могут зависеть от ранних.
//  * Ошибка в init — откатить: освободить состояние, не регистрировать.
//
//  Динамическую загрузку в упражнении мы имитируем: «точки входа» —
//  обычные функции в этом же файле, но хост работает только через
//  указатели из таблиц, ровно как с настоящей DLL.
//
//  ИНТЕРФЕЙСЫ C3 — ТО ЖЕ САМОЕ, НО КОМПИЛЯТОР ПОМОГАЕТ
//  ---------------------------------------------------
//  Внутри одного бинарника удобнее интерфейсы: `interface Tool { ... }`,
//  тип объявляет `struct Blur (Tool)` и методы с @dynamic. Значение
//  интерфейсного типа — это (указатель, typeid); вызов ищет метод в
//  таблице динамических методов типа. Необязательный метод помечается
//  `@optional`, а проверить его наличие у конкретного объекта можно так:
//      if (&tool.reset) tool.reset();
//  Это аналог проверки «указатель в таблице не null».
//
//  ЗАДАЧА:
//    1. PluginHost.load — валидация таблицы, выделение состояния,
//       init с откатом при неудаче;
//    2. PluginHost.update_all и broadcast (с учётом необязательного
//       on_event), unload_all (обратный порядок, освобождение памяти);
//    3. run_pipeline и reset_all для интерфейса Tool.
//
import std::io;
import std::collections::list;

// ================================================================ C-ABI часть

const uint HOST_ABI = 3;

alias LogFn = fn void(void* ctx, String msg);
alias StatFn = fn void(void* ctx, String key, int value);

struct HostApi
{
    void* ctx;           // указатель на хост для колбэков (замыканий нет!)
    LogFn log;
    StatFn set_stat;
}

alias InitFn = fn bool(HostApi* host, void* state);
alias UpdateFn = fn void(HostApi* host, void* state, int frame);
alias EventFn = fn void(HostApi* host, void* state, String event);
alias ShutdownFn = fn void(HostApi* host, void* state);

struct PluginApi
{
    uint abi_version;
    String name;
    sz state_size;
    InitFn init;
    UpdateFn update;
    EventFn on_event;      // может быть null
    ShutdownFn shutdown;
}

alias EntryFn = fn PluginApi*();   // то, что вернул бы dlsym("get_plugin_api")

excuse ABI_MISMATCH, MISSING_FUNCTION, INIT_FAILED;

struct LoadedPlugin
{
    PluginApi* api;
    void* state;
}

struct PluginHost
{
    HostApi api;
    List{LoadedPlugin} plugins;
    DString journal;           // весь лог хоста
    int stat_sum;
}

fn void host_log(void* ctx, String msg)
{
    PluginHost* h = ctx;
    h.journal.appendf("%s\n", msg);
}

fn void host_set_stat(void* ctx, String key, int value)
{
    PluginHost* h = ctx;
    h.stat_sum += value;
    h.journal.appendf("stat %s=%d\n", key, value);
}

fn void PluginHost.init(&self)
{
    self.plugins.init(mem);
    self.journal = dstring::new(mem);
    self.api = { self, &host_log, &host_set_stat };
}

fn void PluginHost.free(&self)
{
    self.plugins.free();
    self.journal.free();
}

fn void? PluginHost.load(&self, EntryFn entry)
{
    PluginApi* p = entry();
    // TODO:
    //  * abi_version != HOST_ABI -> ABI_MISMATCH~
    //  * init/update/shutdown == null -> MISSING_FUNCTION~ (on_event может быть null)
    //  * state = mem::calloc(state_size) (если state_size == 0 — null)
    //  * если !p.init(&self.api, state) — освободить state и INIT_FAILED~
    //  * добавить { p, state } в plugins
}

fn void PluginHost.update_all(&self, int frame)
{
    // TODO: update каждого в порядке загрузки
}

fn void PluginHost.broadcast(&self, String event)
{
    // TODO: on_event тем, у кого он есть
}

fn void PluginHost.unload_all(&self)
{
    // TODO: в ОБРАТНОМ порядке: shutdown, free(state); затем очистить список
}

// ---------------------------------------------------------------- «DLL» №1: счётчик кадров

struct CounterState
{
    int frames;
    int events;
}

fn bool counter_init(HostApi* host, void* state)
{
    host.log(host.ctx, "counter: init");
    return true;
}
fn void counter_update(HostApi* host, void* state, int frame)
{
    CounterState* s = state;
    s.frames++;
}
fn void counter_event(HostApi* host, void* state, String event)
{
    CounterState* s = state;
    s.events++;
    host.log(host.ctx, string::tformat("counter: event '%s'", event));
}
fn void counter_shutdown(HostApi* host, void* state)
{
    CounterState* s = state;
    host.set_stat(host.ctx, "frames", s.frames);
    host.set_stat(host.ctx, "events", s.events);
    host.log(host.ctx, "counter: shutdown");
}
PluginApi counter_api = {
    HOST_ABI, "counter", CounterState::size,
    &counter_init, &counter_update, &counter_event, &counter_shutdown,
};
fn PluginApi* counter_entry() => &counter_api;

// ---------------------------------------------------------------- «DLL» №2: без on_event и без состояния

fn bool ticker_init(HostApi* host, void* state)
{
    assert(state == null);
    host.log(host.ctx, "ticker: init");
    return true;
}
fn void ticker_update(HostApi* host, void* state, int frame)
{
    if (frame % 2 == 0) host.log(host.ctx, string::tformat("ticker: tick %d", frame));
}
fn void ticker_shutdown(HostApi* host, void* state) => host.log(host.ctx, "ticker: shutdown");
PluginApi ticker_api = { HOST_ABI, "ticker", 0, &ticker_init, &ticker_update, null, &ticker_shutdown };
fn PluginApi* ticker_entry() => &ticker_api;

// ---------------------------------------------------------------- «DLL» с проблемами

PluginApi old_api = { 2, "old", 0, &ticker_init, &ticker_update, null, &ticker_shutdown };
fn PluginApi* old_entry() => &old_api;

PluginApi broken_api = { HOST_ABI, "broken", 0, &ticker_init, null, null, &ticker_shutdown };
fn PluginApi* broken_entry() => &broken_api;

fn bool failing_init(HostApi* host, void* state)
{
    host.log(host.ctx, "failing: init refused");
    return false;
}
PluginApi failing_api = { HOST_ABI, "failing", 64, &failing_init, &ticker_update, null, &ticker_shutdown };
fn PluginApi* failing_entry() => &failing_api;

// ================================================================ интерфейсы

interface Tool
{
    fn String name();
    fn int apply(int x);
    fn void reset() @optional;
}

struct Adder (Tool) { int amount; int uses; }
fn String Adder.name(&self) @dynamic => "adder";
fn int Adder.apply(&self, int x) @dynamic { self.uses++; return x + self.amount; }
fn void Adder.reset(&self) @dynamic => self.uses = 0;

struct Doubler (Tool) { int dummy; }
fn String Doubler.name(&self) @dynamic => "doubler";
fn int Doubler.apply(&self, int x) @dynamic => x * 2;
// reset не реализован — он @optional

// Прогнать x через все инструменты по очереди.
fn int run_pipeline(Tool[] tools, int x)
{
    // TODO
    return x;
}

// Вызвать reset у тех, кто его реализует; вернуть, у скольких он был.
fn int reset_all(Tool[] tools)
{
    // TODO: if (&t.reset) ...
    return 0;
}

// ================================================================ проверка

fn void main()
{
    PluginHost host;
    host.init();
    defer host.free();

    host.load(&counter_entry)!!;
    host.load(&ticker_entry)!!;
    assert(@catch(host.load(&old_entry)) == ABI_MISMATCH, "old ABI must be rejected");
    assert(@catch(host.load(&broken_entry)) == MISSING_FUNCTION, "missing update must be rejected");
    assert(@catch(host.load(&failing_entry)) == INIT_FAILED, "failed init must be reported");
    assert(host.plugins.len() == 2, "only valid plugins are registered");

    @pool()
    {
        for (int frame = 1; frame <= 4; frame++) host.update_all(frame);
        host.broadcast("level_loaded");
        host.broadcast("player_died");
    };
    host.unload_all();
    assert(host.plugins.len() == 0);
    assert(host.stat_sum == 4 + 2, "counter must report 4 frames and 2 events");
    io::print(host.journal.str_view());

    Adder add = { .amount = 5 };
    Doubler dbl;
    Tool[*] tools = { &add, &dbl, &add };
    int r = run_pipeline(&tools, 1);       // ((1 + 5) * 2) + 5
    assert(r == 17 && add.uses == 2);
    int resets = reset_all(&tools);
    assert(resets == 2 && add.uses == 0, "Adder has reset (twice in the list), Doubler doesn't");
    io::printfn("pipeline(1) = %d, tools with reset: %d", r, resets);
}
