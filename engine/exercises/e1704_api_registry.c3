// =====================================================================
//  e1704 · Реестр API в стиле Our Machinery
// =====================================================================
//
//  Таблица функций одного модуля — хорошо. Но в большом движке десятки
//  плагинов (рендер, физика, звук, редакторные инструменты), и они
//  пользуются API друг друга. Our Machinery (движок от авторов
//  Bitsquid/Stingray) решил это одним механизмом — РЕЕСТРОМ API:
//
//      // плагин логгера при загрузке:
//      registry.set("log", 1, 0, &my_log_api, LogApi::size);
//      // плагин физики при загрузке:
//      LogApi* log = registry.get("log", 1, LogApi::size);
//      ...
//      log.write("contact!");
//
//  Ключевые свойства:
//
//    * get() возвращает указатель на СЛОТ внутри реестра, а не на
//      структуру внутри плагина. set() КОПИРУЕТ таблицу в слот.
//      Поэтому, когда логгер перезагружается и снова вызывает set(),
//      все, кто давно держит указатель `log`, сразу видят новые функции.
//      Никаких рассылок «обновите указатели».
//    * Позднее связывание: get() можно вызвать ДО set(). Слот
//      создаётся пустым (все указатели null), а когда плагин загрузится,
//      он будет заполнен. Порядок загрузки плагинов перестаёт быть важен.
//    * Версии: мажорная версия ломает совместимость (get с другой
//      мажорной -> null), минорная только добавляет функции в КОНЕЦ
//      структуры (старые клиенты не видят новых полей — и это нормально).
//    * Имя копируется в реестр: строковый литерал "log" живёт ВНУТРИ
//      .so плагина и исчезнет после его выгрузки (см. e1702).
//
//  ЗАДАЧА: реализуйте find, get, set и remove.
//
import std::io;

const int MAX_APIS = 8;
const usz MAX_API_SIZE = 64;
const usz MAX_NAME = 32;

struct ApiSlot
{
    char[MAX_NAME] name_buf;
    usz name_len;
    uint major;
    uint minor;
    bool implemented;
    char[MAX_API_SIZE] data @align(16);   // копия таблицы функций
}

struct ApiRegistry
{
    ApiSlot[MAX_APIS] slots;
    int count;
}

fn String ApiSlot.name(&self) => (String)self.name_buf[:self.name_len];

// Индекс слота с таким именем или -1.
fn int ApiRegistry.find(&self, String name)
{
    (void)name;
    return -1; // TODO
}

fn ApiSlot* ApiRegistry.create(&self, String name, uint major)
{
    assert(self.count < MAX_APIS && name.len <= MAX_NAME);
    ApiSlot* s = &self.slots[self.count++];
    *s = { .name_len = name.len, .major = major };
    s.name_buf[:name.len] = name[..];
    return s;
}

// Вернуть указатель на данные слота (создав пустой слот, если его нет).
// Если слот есть, но мажорная версия другая — null.
fn void* ApiRegistry.get(&self, String name, uint major, usz size)
{
    assert(size <= MAX_API_SIZE);
    // TODO
    (void)name;
    (void)major;
    return null;
}

// Зарегистрировать (или перерегистрировать) реализацию: скопировать
// size байт из api в слот. Мажорная версия слота берётся из set().
fn void ApiRegistry.set(&self, String name, uint major, uint minor, void* api, usz size)
{
    assert(size <= MAX_API_SIZE);
    // TODO
    (void)name;
    (void)major;
    (void)minor;
    (void)api;
}

// Плагин выгружается: слот остаётся (на него держат указатели!), но
// обнуляется, чтобы никто не вызвал код выгруженного плагина.
fn void ApiRegistry.remove(&self, String name)
{
    // TODO
    (void)name;
}

fn bool ApiRegistry.is_implemented(&self, String name)
{
    int i = self.find(name);
    return i >= 0 && self.slots[i].implemented;
}

// ---------------------------------------------------------------------
// Плагины. Ниже ничего менять не нужно.

alias WriteFn = fn void(String);
alias CountFn = fn int();

struct LogApi
{
    WriteFn write;
    CountFn count;
}

int g_lines;
fn void log_v1(String s) { g_lines++; io::printfn("[log v1] %s", s); }
fn void log_v2(String s) { g_lines++; io::printfn("[log v2] %s", s); }
fn int log_count() => g_lines;

struct Physics
{
    LogApi* log;   // получен один раз и больше не обновляется
}

fn void Physics.step(&self)
{
    if (self.log.write) self.log.write("physics step");
}

fn void main()
{
    ApiRegistry reg;

    // физика загружается РАНЬШЕ логгера
    Physics phys = { .log = reg.get("log", 1, LogApi::size) };
    assert(phys.log != null, "get до set должен вернуть пустой слот");
    assert(!reg.is_implemented("log"));
    phys.step();   // логгера ещё нет — тихо ничего

    // логгер загружается
    LogApi v1 = { &log_v1, &log_count };
    reg.set("log", 1, 0, &v1, LogApi::size);
    phys.step();

    // горячая перезагрузка логгера: новая таблица, тот же слот
    char[8] name_in_plugin = "log\0\0\0\0\0";   // имя в «памяти плагина»
    LogApi v2 = { &log_v2, &log_count };
    reg.set((String)name_in_plugin[:3], 1, 1, &v2, LogApi::size);
    name_in_plugin[..] = 'X';          // плагин выгрузился — память затёрта
    phys.step();
    assert(reg.find("log") == 0, "имя должно быть скопировано в реестр");
    assert(reg.count == 1, "перерегистрация не создаёт новый слот");

    // несовместимая мажорная версия
    assert(reg.get("log", 2, LogApi::size) == null, "major 2 несовместима с 1");

    // выгрузка
    reg.remove("log");
    assert(!reg.is_implemented("log") && phys.log.write == null);
    phys.step();

    io::printfn("lines=%d slots=%d minor=%d", phys.log.count ? 0 : g_lines, reg.count, reg.slots[0].minor);
}
