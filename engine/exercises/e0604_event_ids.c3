// =====================================================================
//  E0604 · Идентификаторы событий: хеширование строк при компиляции
// =====================================================================
//
//  Сначала прочитайте engine/docs/06_events.md (раздел 6).
//
//  Пока все события — элементы одного enum, всё просто. Но в реальном
//  движке события приходят и из данных: скрипт уровня говорит
//  "door_open 3", аниматор ставит на кадр анимации тег "footstep",
//  дизайнер в редакторе подписывает триггер на "boss_phase_2". Enum,
//  зашитый в код, тут не годится, а сравнивать строки на каждом
//  событии — дорого (и строки надо где-то хранить).
//
//  Стандартный ответ (StringId в Bitsquid/Stingray, FName в Unreal,
//  StringName в Godot, crc32-id в Frostbite): событие — это 32- или
//  64-битный ХЕШ своего имени. Сравнение — одна инструкция, событие
//  остаётся значением фиксированного размера.
//
//  Ключевой трюк: в коде хеш считается ВО ВРЕМЯ КОМПИЛЯЦИИ, поэтому
//  его можно использовать в `case` и в константах:
//
//      switch (id)
//      {
//          case @event_id("door_open"): ...
//      }
//
//  а для строк из данных — тот же алгоритм во время выполнения. Главное
//  — чтобы обе версии давали ОДИНАКОВЫЙ результат.
//
//  Алгоритм — FNV-1a, 32 бита:
//      h = 2166136261
//      для каждого байта c:  h = (h ^ c) * 16777619   (по модулю 2^32)
//
//  В C3 compile-time версия — макрос с compile-time параметром
//  `String $name` и циклом `$for`, накапливающим значение в
//  compile-time переменной `var $h`. Если в теле макроса остаётся
//  ровно один runtime-оператор `return`, вызов сворачивается в
//  константу, а атрибут `@const` заставляет компилятор это проверить.
//
//  Хеши могут совпасть (коллизия). Для 32 бит вероятность мала, но при
//  десятках тысяч имён уже реальна (парадокс дней рождения). Поэтому
//  известные имена проверяют на уникальность — здесь прямо при
//  компиляции, через `$assert`. Синтаксис сообщения в 0.8.5:
//      $assert cond : "message";
//
//  Обратная задача — по хешу получить имя для логов и отладки. Её
//  решают таблицей «хеш -> строка», которая есть только в debug/
//  editor-сборках.
//
//  ЗАДАЧА:
//    1. реализуйте макрос @event_id (compile-time FNV-1a);
//    2. реализуйте runtime-функцию event_id с тем же результатом;
//    3. допишите @check_unique: для каждой пары имён из EVENT_NAMES
//       проверить при компиляции (`$assert`), что хеши различны, и
//       вернуть число проверенных пар (compile-time счётчик `var $pairs`);
//    4. реализуйте name_of — поиск имени по хешу (или "<unknown>").
//
//  Пока макрос не реализован, программа не скомпилируется: сработает
//  проверка тестового вектора FNV-1a — это ожидаемо.
//
import std::io;

macro uint @event_id(String $name) @const
{
    // TODO
    return 0u;
}

fn uint event_id(String name)
{
    // TODO
    return 0;
}

// Тестовые векторы FNV-1a (32 бита) — проверяются при компиляции.
$assert @event_id("") == 0x811c9dc5 : "FNV-1a of empty string is the offset basis";
$assert @event_id("a") == 0xe40c292c : "@event_id is not FNV-1a yet";
$assert @event_id("foobar") == 0xbf9cf968 : "@event_id is not FNV-1a yet";

// Все имена событий, известные коду.
const String[*] EVENT_NAMES = {
    "door_open",
    "door_close",
    "player_spawn",
    "pickup_coin",
    "boss_phase_2",
    "footstep",
};

macro int @check_unique() @const
{
    // TODO
    return 0;
}

fn String name_of(uint id)
{
    // TODO
    return "<unknown>";
}

// ---------------------------------------------------------------------
// Использование: событие = (id, аргумент), приходит из «скрипта уровня».
// ---------------------------------------------------------------------

const uint EV_FOOTSTEP = @event_id("footstep");   // хеш как обычная константа

struct Event { uint id; int arg; }

struct Level
{
    int doors_open;
    int spawned;
    int coins;
    int boss_phase;
    int footsteps;
    int unknown;
}

fn void Level.handle(&self, Event ev)
{
    switch (ev.id)
    {
        case @event_id("door_open"):    self.doors_open += 1;
        case @event_id("door_close"):   self.doors_open -= 1;
        case @event_id("player_spawn"): self.spawned++;
        case @event_id("pickup_coin"):  self.coins += ev.arg;
        case @event_id("boss_phase_2"): self.boss_phase = 2;
        case EV_FOOTSTEP:               self.footsteps++;
        default:
            self.unknown++;
            io::printfn("  unknown event %s (0x%08x)", name_of(ev.id), ev.id);
    }
}

fn void main()
{
    int pairs = @check_unique();
    assert(pairs == EVENT_NAMES.len * (EVENT_NAMES.len - 1) / 2, "every pair must be checked");

    // Обе версии хеша обязаны совпадать.
    assert(event_id("") == 0x811c9dc5, "runtime FNV-1a: wrong offset basis");
    assert(event_id("a") == 0xe40c292c, "runtime FNV-1a is wrong");
    assert(event_id("door_open") == @event_id("door_open"), "runtime and compile-time ids differ");
    foreach (n : EVENT_NAMES)
    {
        assert(name_of(event_id(n)) == n, "name_of must invert event_id");
    }
    assert(name_of(12345) == "<unknown>");

    String script =
        "player_spawn 0\n"
        "door_open 1\n"
        "pickup_coin 5\n"
        "footstep 0\n"
        "footstep 0\n"
        "door_close 1\n"
        "door_open 2\n"
        "teleport 7\n"
        "pickup_coin 10\n"
        "boss_phase_2 0\n";

    Level level;
    int count;
    @pool()
    {
        foreach (line : script.tsplit("\n", skip_empty: true))
        {
            String[] parts = line.tsplit(" ");
            Event ev = { event_id(parts[0]), parts[1].to_int() ?? 0 };
            level.handle(ev);
            count++;
        }
    };

    assert(count == 10);
    assert(level.spawned == 1 && level.doors_open == 1 && level.coins == 15);
    assert(level.footsteps == 2 && level.boss_phase == 2 && level.unknown == 1);

    io::printfn("unique pairs checked at compile time: %d", pairs);
    io::printfn("door_open = 0x%08x", @event_id("door_open"));
    io::printfn("footstep  = 0x%08x -> %s", EV_FOOTSTEP, name_of(EV_FOOTSTEP));
    io::printfn("level: spawned=%d doors=%d coins=%d steps=%d boss=%d unknown=%d",
                level.spawned, level.doors_open, level.coins, level.footsteps,
                level.boss_phase, level.unknown);
    io::printn("event ids: all checks passed");
}
