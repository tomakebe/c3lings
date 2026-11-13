// =====================================================================
//  E0601 · Наблюдатель: сигнал с немедленной доставкой
// =====================================================================
//
//  Сначала прочитайте engine/docs/06_events.md (разделы 1–3).
//
//  Самая простая форма событий в движке — «сигнал» (signal/slot,
//  observer, delegate, multicast delegate в Unreal). Отправитель
//  ничего не знает о получателях: у него есть список «слотов», и при
//  emit() он просто вызывает их по очереди — немедленно, внутри
//  своего стека вызовов.
//
//  В C3 нет замыканий: лямбда не захватывает переменные. Поэтому
//  классический C-приём — пара (указатель на функцию, void* контекст):
//
//      alias DamageFn = fn void(void* ctx, int amount);
//      struct Slot { DamageFn cb; void* ctx; bool used; }
//
//  Контекст — это «this» получателя. Функция-обработчик приводит его
//  обратно к своему типу: `HealthBar* bar = ctx;` (void* неявно
//  приводится к любому указателю).
//
//  Слоты хранятся в массиве фиксированного размера — никаких аллокаций
//  при подписке. Идентификатор подписки — просто индекс слота. При
//  отписке слот помечается свободным и может быть переиспользован.
//  (Чем это опасно, если отписка происходит изнутри emit() или по
//  устаревшему индексу — разберём в E0605.)
//
//  Порядок вызова — порядок индексов слотов. Это важно: многие баги в
//  движках — это неявная зависимость от порядка подписчиков.
//
//  ЗАДАЧА: реализуйте методы Signal, помеченные TODO:
//    * connect    — занять ПЕРВЫЙ свободный слот, вернуть его индекс;
//                   если мест нет — вернуть -1;
//    * disconnect — освободить слот (неверный/свободный id игнорировать);
//    * emit       — вызвать все занятые слоты по возрастанию индекса;
//    * count      — число занятых слотов.
//
import std::io;

alias DamageFn = fn void(void* ctx, int amount);

struct Slot
{
    DamageFn cb;
    void* ctx;
    bool used;
}

const int MAX_SLOTS = 4;

struct Signal
{
    Slot[MAX_SLOTS] slots;
}

fn int Signal.connect(&self, DamageFn cb, void* ctx)
{
    // TODO
    return -1;
}

fn void Signal.disconnect(&self, int id)
{
    // TODO
}

fn void Signal.emit(&self, int amount)
{
    // TODO
}

fn int Signal.count(&self)
{
    // TODO
    return 0;
}

// ---------------------------------------------------------------------
// Получатели. Каждый ничего не знает об отправителе и о других.
// ---------------------------------------------------------------------

struct HealthBar { int hp; }
struct DamageStats { int total; int hits; }
struct Achievement { int threshold; bool unlocked; }

// Глобальный журнал вызовов, чтобы проверить порядок.
char[16] g_order;
int g_order_len;

fn void on_damage_bar(void* ctx, int amount)
{
    HealthBar* bar = ctx;
    bar.hp -= amount;
    if (bar.hp < 0) bar.hp = 0;
    g_order[g_order_len++] = 'B';
}

fn void on_damage_stats(void* ctx, int amount)
{
    DamageStats* st = ctx;
    st.total += amount;
    st.hits++;
    g_order[g_order_len++] = 'S';
}

fn void on_damage_achievement(void* ctx, int amount)
{
    Achievement* a = ctx;
    if (!a.unlocked && amount >= a.threshold)
    {
        a.unlocked = true;
    }
    g_order[g_order_len++] = 'A';
}

fn void main()
{
    Signal on_damage;
    HealthBar bar = { 100 };
    DamageStats stats;
    Achievement big_hit = { .threshold = 30 };

    int id_bar = on_damage.connect(&on_damage_bar, &bar);
    int id_stats = on_damage.connect(&on_damage_stats, &stats);
    int id_ach = on_damage.connect(&on_damage_achievement, &big_hit);
    assert(id_bar == 0 && id_stats == 1 && id_ach == 2, "connect must take the first free slot");
    assert(on_damage.count() == 3);

    on_damage.emit(10);
    on_damage.emit(35);
    assert(bar.hp == 55, "health bar should see both hits");
    assert(stats.total == 45 && stats.hits == 2);
    assert(big_hit.unlocked, "achievement should unlock on a 35 hit");
    assert((String)g_order[:g_order_len] == "BSABSA", "slots must be called in index order");

    // Полоска здоровья уничтожена вместе с UI — отписываемся.
    on_damage.disconnect(id_bar);
    on_damage.disconnect(id_bar);   // повторная отписка безопасна
    on_damage.disconnect(42);       // мусорный id безопасен
    assert(on_damage.count() == 2);
    on_damage.emit(5);
    assert(bar.hp == 55, "disconnected slot must not be called");
    assert(stats.total == 50 && stats.hits == 3);

    // Свободный слот 0 переиспользуется.
    HealthBar bar2 = { 20 };
    int id_bar2 = on_damage.connect(&on_damage_bar, &bar2);
    assert(id_bar2 == 0, "connect should reuse the freed slot 0");
    int id4 = on_damage.connect(&on_damage_stats, &stats);
    assert(id4 == 3);
    assert(on_damage.connect(&on_damage_stats, &stats) == -1, "signal is full");
    on_damage.emit(1);
    assert(bar2.hp == 19 && stats.hits == 5);

    io::printfn("order: %s", (String)g_order[:g_order_len]);
    io::printfn("bar=%d bar2=%d total=%d hits=%d unlocked=%s",
                bar.hp, bar2.hp, stats.total, stats.hits, big_hit.unlocked);
    io::printn("observer: all checks passed");
}
