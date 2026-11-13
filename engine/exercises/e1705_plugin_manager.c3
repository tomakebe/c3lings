// =====================================================================
//  e1705 · Менеджер плагинов: зависимости и порядок загрузки
// =====================================================================
//
//  Когда плагинов много, у них появляются зависимости: «редактор
//  частиц» нужен «рендер» и «UI», «UI» нужен «рендер» и «шрифты».
//  Даже с поздним связыванием через реестр (e1704) порядок важен для
//  ИНИЦИАЛИЗАЦИИ: плагин в load() может сразу вызывать API зависимостей.
//
//  Правила:
//    * загрузка — в топологическом порядке (зависимости раньше);
//    * выгрузка — СТРОГО в обратном порядке загрузки (как деструкторы
//      в C++ или defer в C3): никто не переживёт то, от чего зависит;
//    * перезагрузка плагина P = выгрузить всех, кто зависит от P
//      (транзитивно), выгрузить P, загрузить P, загрузить зависимых;
//    * отсутствующая зависимость или цикл — ошибка конфигурации,
//      о которой надо сообщить ДО загрузки чего-либо.
//
//  Топологическая сортировка (алгоритм Кана):
//
//      indegree[p] = число зависимостей p
//      готовые = все p с indegree 0
//      пока есть готовые:
//          взять готовый с НАИМЕНЬШИМ индексом   <- детерминизм!
//          добавить в порядок; для всех q, зависящих от него: indegree[q]--
//      если в порядке меньше плагинов, чем всего — есть цикл
//
//  Детерминизм порядка важен: если он зависит от порядка файлов на
//  диске или от хеш-таблицы, баги инициализации станут
//  «плавающими» — у одного разработчика воспроизводятся, у другого нет.
//
//  ЗАДАЧА: реализуйте load_order (алгоритм Кана) и dependents_closure.
//
import std::io;

const int MAX_PLUGINS = 8;

excuse
{
    MISSING_DEPENDENCY,
    DEPENDENCY_CYCLE,
}

struct Plugin
{
    String name;
    String[] deps;
}

fn int index_of(Plugin[] plugins, String name)
{
    foreach (i, p : plugins) if (p.name == name) return (int)i;
    return -1;
}

// Записать в order индексы плагинов в порядке загрузки, вернуть их число.
fn int? load_order(Plugin[] plugins, int[] order)
{
    int n = (int)plugins.len;
    int[MAX_PLUGINS] indegree;
    // dep_of[a][b] == true  <=>  плагин b зависит от плагина a
    bool[MAX_PLUGINS][MAX_PLUGINS] dep_of;
    for (int i = 0; i < n; i++)
    {
        foreach (d : plugins[i].deps)
        {
            int j = index_of(plugins, d);
            if (j < 0) return MISSING_DEPENDENCY~;
            dep_of[j][i] = true;
            indegree[i]++;
        }
    }
    // TODO: алгоритм Кана; на каждом шаге — готовый плагин с наименьшим индексом
    (void)order;
    return 0;
}

// Отметить в out всех, кто зависит от root (прямо или транзитивно),
// включая сам root.
fn void dependents_closure(Plugin[] plugins, int root, bool[] out)
{
    // TODO: повторять, пока множество растёт
    (void)plugins;
    (void)out;
}

// ---------------------------------------------------------------------
// Ниже ничего менять не нужно.

fn void print_order(Plugin[] plugins, int[] order)
{
    io::printf("  load:  ");
    foreach (i : order) io::printf(" %s", plugins[i].name);
    io::printn();
    io::printf("  unload:");
    foreach_r (i : order) io::printf(" %s", plugins[i].name);
    io::printn();
}

fn void main()
{
    Plugin[*] plugins = {
        { "particles", { "render", "ui" } },
        { "ui", { "render", "fonts" } },
        { "fonts", {} },
        { "render", { "os" } },
        { "audio", { "os" } },
        { "os", {} },
    };
    int[MAX_PLUGINS] order;
    int n = load_order(&plugins, &order)!!;
    assert(n == plugins.len, "должны загрузиться все плагины");
    // проверка: каждая зависимость загружена раньше
    for (int k = 0; k < n; k++)
    {
        foreach (d : plugins[order[k]].deps)
        {
            int j = index_of(&plugins, d);
            bool before = false;
            for (int m = 0; m < k; m++) if (order[m] == j) before = true;
            assert(before, "зависимость должна грузиться раньше");
        }
    }
    io::printn("engine plugins:");
    print_order(&plugins, order[:n]);

    // перезагрузка render: кого придётся перезапустить?
    bool[MAX_PLUGINS] affected;
    dependents_closure(&plugins, index_of(&plugins, "render"), &affected);
    io::printf("reload render ->");
    foreach (k : order[:n]) if (affected[k]) io::printf(" %s", plugins[k].name);
    io::printn();
    assert(affected[0] && affected[1] && affected[3] && !affected[2] && !affected[4]);

    Plugin[*] broken = { { "a", { "b" } }, { "b", { "nope" } } };
    if (catch err = load_order(&broken, &order)) io::printfn("broken: %s", err);
    Plugin[*] cyclic = { { "a", { "c" } }, { "b", { "a" } }, { "c", { "b" } }, { "d", {} } };
    if (catch err = load_order(&cyclic, &order)) io::printfn("cyclic: %s", err);
}
