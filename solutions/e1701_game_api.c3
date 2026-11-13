// =====================================================================
//  e1701 · Таблица функций: стабильный ABI между хостом и игрой
// =====================================================================
//
//  Горячая перезагрузка кода устроена так: исполняемый файл-«хост»
//  (платформа, окно, память, цикл) загружает игровую логику из
//  динамической библиотеки (game.so / game.dll). Когда вы пересобрали
//  библиотеку, хост выгружает старую и загружает новую — не перезапуская
//  игру. Подробно (и с настоящим dlopen) — в engine/docs/17_hot_reload.md.
//
//  Хост и модуль собираются РАЗНЫМИ вызовами компилятора, поэтому
//  договор между ними должен быть максимально простым и явным:
//
//    * единственная экспортируемая функция `get_game_api()`, которая
//      возвращает указатель на ТАБЛИЦУ ФУНКЦИЙ (struct из указателей);
//    * в начале таблицы — magic, версия ABI и размер структуры. Хост
//      ОБЯЗАН проверить их до первого вызова: если модуль собран с другим
//      заголовком, вызов «не той» функции по смещению — это падение или,
//      хуже, тихая порча памяти;
//    * всё состояние игры живёт в памяти, которую выделил ХОСТ и
//      передаёт в каждый вызов (GameMemory). Модуль приходит и уходит,
//      а память остаётся — поэтому состояние переживает перезагрузку.
//
//  Порядок перезагрузки:
//
//      new_api = get_api_of_new_module()
//      проверить new_api  --- плохо ---> оставить СТАРЫЙ модуль, вернуть false
//      old_api.on_unload(&memory)      (модуль может сбросить кэши)
//      api = new_api
//      api.on_load(&memory)            (модуль может перестроить кэши)
//
//  Здесь вместо настоящих .so — несколько «сборок» модуля в одной
//  программе: функции game_v1_api(), game_v2_api(), ... Механизм тот же.
//
//  ЗАДАЧА: реализуйте api_compatible и Host.reload.
//
import std::io;

const uint API_MAGIC = 0x47414D45;     // "GAME"
const uint API_VERSION = 3;

struct GameMemory
{
    char[256] storage @align(16);    // постоянная память игры (выделяет хост)
    bool initialized;
}

alias LifecycleFn = fn void(GameMemory*);
alias UpdateFn = fn void(GameMemory*, int input);
alias GetApiFn = fn GameApi*();

struct GameApi
{
    uint magic;
    uint version;
    usz size;            // GameApi::size на момент сборки модуля
    String build;
    LifecycleFn on_load;
    LifecycleFn on_unload;
    UpdateFn update;
}

struct GameState
{
    int frame;
    int score;
    int reloads_seen;
}

struct Host
{
    GameMemory memory;
    GameApi* api;
    int reload_count;
}

fn bool api_compatible(GameApi* api)
{
    if (api == null) return false;
    return api.magic == API_MAGIC && api.version == API_VERSION && api.size == GameApi::size;
}

// Попытаться переключиться на новый модуль. При несовместимости
// оставить старый и вернуть false.
fn bool Host.reload(&self, GetApiFn get_api)
{
    GameApi* next = get_api();
    if (!api_compatible(next)) return false;
    if (self.api) self.api.on_unload(&self.memory);
    self.api = next;
    self.api.on_load(&self.memory);
    self.reload_count++;
    return true;
}

// ---------------------------------------------------------------------
// «Модуль игры», несколько его сборок. Ниже ничего менять не нужно.

fn GameState* state_of(GameMemory* m)
{
    GameState* s = (GameState*)&m.storage;
    if (!m.initialized) { *s = {}; m.initialized = true; }
    return s;
}

fn void common_load(GameMemory* m) { state_of(m).reloads_seen++; }
fn void common_unload(GameMemory* m) {}

fn void v1_update(GameMemory* m, int input) { GameState* s = state_of(m); s.frame++; s.score += input; }
fn void v2_update(GameMemory* m, int input) { GameState* s = state_of(m); s.frame++; s.score += input * 10; }

GameApi g_v1 = { API_MAGIC, API_VERSION, GameApi::size, "v1", &common_load, &common_unload, &v1_update };
GameApi g_v2 = { API_MAGIC, API_VERSION, GameApi::size, "v2 (x10 score)", &common_load, &common_unload, &v2_update };
GameApi g_old = { API_MAGIC, 2, GameApi::size, "built with old header", &common_load, &common_unload, &v1_update };
GameApi g_garbage = { 0xDEADBEEF, 0, 0, "not a game module", null, null, null };

fn GameApi* game_v1_api() => &g_v1;
fn GameApi* game_v2_api() => &g_v2;
fn GameApi* game_old_api() => &g_old;
fn GameApi* garbage_api() => &g_garbage;
fn GameApi* missing_api() => null;

fn void main()
{
    Host host;
    assert(host.reload(&game_v1_api), "v1 должен загрузиться");
    for (int i = 1; i <= 5; i++) host.api.update(&host.memory, i);      // score 15

    assert(!host.reload(&game_old_api), "модуль со старой версией ABI нужно отвергнуть");
    assert(!host.reload(&garbage_api), "мусор нужно отвергнуть");
    assert(!host.reload(&missing_api), "null нужно отвергнуть");
    assert(host.api == &g_v1, "после неудачной перезагрузки работает старый модуль");
    host.api.update(&host.memory, 1);                                    // score 16

    assert(host.reload(&game_v2_api));
    for (int i = 1; i <= 3; i++) host.api.update(&host.memory, i);      // +60

    GameState* s = state_of(&host.memory);
    assert(s.score == 76, "состояние должно пережить перезагрузку");
    assert(s.reloads_seen == 2, "on_load вызывается при каждой успешной загрузке");
    io::printfn("module: %s", host.api.build);
    io::printfn("reloads=%d frame=%d score=%d", host.reload_count, s.frame, s.score);
}
