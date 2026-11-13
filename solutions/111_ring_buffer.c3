// =====================================================================
//  111 · Generic кольцевой буфер + foreach
// =====================================================================
//
//  Кольцевой буфер (ring buffer, circular queue) — FIFO фиксированной
//  ёмкости поверх обычного массива. Нулевые аллокации после создания,
//  O(1) на операцию, предсказуемая память. Он везде:
//  * аудио: блоки сэмплов между потоком декодера и аудио-колбэком;
//  * сеть: история снапшотов для интерполяции и rollback-неткода;
//  * ввод: последние N событий клавиатуры, буфер для «комбо»;
//  * логи и профайлеры: «последние 1000 кадров» с перезаписью старых;
//  * ядро ОС и драйверы: очереди дескрипторов (io_uring, NIC rings).
//
//  КАК ХРАНИТЬ ПОЗИЦИИ
//  -------------------
//  Наивно: head/tail — индексы в [0, CAP), плюс отдельный count, иначе
//  head == tail неоднозначно («пусто» или «полно»?). Альтернатива —
//  жертвовать одной ячейкой.
//
//  Приём профессионалов: head и tail — МОНОТОННЫЕ счётчики (никогда не
//  обнуляются), а индекс в массиве — `counter & (CAP - 1)`.
//      len   = tail - head            // беззнаковое вычитание
//      empty = head == tail
//      full  = len == CAP
//  Беззнаковое переполнение uint определено (по модулю 2^32), поэтому
//  `tail - head` верно даже когда tail уже «перевалил» через 0, а head
//  ещё нет. Условие: CAP — степень двойки (тогда 2^32 делится на CAP и
//  маска согласована с переполнением). Этот же приём лежит в основе
//  lock-free очереди из следующего упражнения: производитель пишет
//  только tail, потребитель — только head.
//
//  ПОЛИТИКИ ПЕРЕПОЛНЕНИЯ
//  ---------------------
//  * Отказ (push возвращает ошибку) — очереди команд, где терять нельзя.
//  * Перезапись самого старого — телеметрия, история, логи.
//  * Блокировка — в многопоточных каналах.
//  Сделаем первые две: `push` -> `FULL~`, `push_overwrite` -> молча
//  выталкивает голову.
//
//  FOREACH ДЛЯ СВОЕГО ТИПА
//  -----------------------
//  В C3 foreach работает с любым типом, у которого есть методы с
//  атрибутами `@operator(len)` и `@operator([])`; для обхода по ссылке
//  (`foreach (&x : ring)`) нужен ещё `@operator(&[])`, а `[]=` даёт
//  присваивание `ring[i] = v`. Логический индекс 0 — самый старый
//  элемент, а не ячейка массива 0: оператор сам переводит индекс.
//  Тогда и `foreach_r` бесплатно идёт от новых к старым.
//
//  Константный параметр дженерика: `struct Ring <Type, CAP>` —
//  ёмкость известна при компиляции, массив лежит прямо в структуре
//  (`Type[CAP]`), маска — константа, `%` не нужен. Контракт
//  `@require` на объявлении проверяет степень двойки при инстанцировании.
//
//  ЗАДАЧА: реализуйте методы Ring, помеченные TODO. main() проверяет в
//  том числе переполнение счётчиков (стартуем у самого uint::max).
//
import std::io;

excuse FULL, EMPTY;

<* @require CAP > 0 && (CAP & (CAP - 1)) == 0 : "CAP must be a power of two" *>
struct Ring <Type, CAP>
{
    Type[CAP] items;
    uint head;     // счётчик извлечённых
    uint tail;     // счётчик записанных
}

// Для тестов: начать счётчики с произвольного значения.
fn void Ring.init_at(&self, uint start)
{
    self.head = start;
    self.tail = start;
}

fn uint Ring.mask(&self) @inline => (uint)CAP - 1;

fn sz Ring.len(&self) @operator(len)
{
    // TODO
    return (sz)(self.tail - self.head);
}

fn bool Ring.is_empty(&self) => self.len() == 0;
fn bool Ring.is_full(&self) => self.len() == CAP;

fn void? Ring.push(&self, Type v)
{
    // TODO: FULL~ если полон; иначе записать в items[tail & mask], tail++.
    if (self.is_full()) return FULL~;
    self.items[self.tail & self.mask()] = v;
    self.tail++;
}

// Если полон — выбросить самый старый элемент.
fn void Ring.push_overwrite(&self, Type v)
{
    // TODO
    if (self.is_full()) self.head++;
    self.items[self.tail & self.mask()] = v;
    self.tail++;
}

fn Type? Ring.pop(&self)
{
    // TODO: EMPTY~ если пуст; иначе взять items[head & mask], head++.
    if (self.is_empty()) return EMPTY~;
    Type v = self.items[self.head & self.mask()];
    self.head++;
    return v;
}

// Логический индекс: 0 — самый старый.
fn Type Ring.get(&self, sz i) @operator([])
{
    assert(i >= 0 && i < self.len(), "ring index %d out of bounds", i);
    // TODO
    return self.items[(self.head + (uint)i) & self.mask()];
}

fn Type* Ring.get_ref(&self, sz i) @operator(&[])
{
    assert(i >= 0 && i < self.len(), "ring index %d out of bounds", i);
    // TODO
    return &self.items[(self.head + (uint)i) & self.mask()];
}

fn void Ring.set(&self, sz i, Type v) @operator([]=)
{
    *self.get_ref(i) = v;
}

// ---------------------------------------------------------------- проверка

struct Sample
{
    int frame;
    float value;
}

alias History = Ring{Sample, 8};

fn void main()
{
    Ring{int, 4} r;
    assert(r.is_empty() && @catch(r.pop()) == EMPTY);
    r.push(1)!!;
    r.push(2)!!;
    r.push(3)!!;
    assert(r.len() == 3 && r[0] == 1 && r[2] == 3);
    assert(r.pop()!! == 1);
    r.push(4)!!;
    r.push(5)!!;
    assert(r.is_full() && @catch(r.push(6)) == FULL);
    int sum = 0;
    foreach (v : r) sum += v;
    assert(sum == 2 + 3 + 4 + 5, "foreach sum %d", sum);

    // foreach по ссылке и присваивание через []=
    foreach (&v : r) *v *= 10;
    r[0] = 7;
    DString s = dstring::new(mem);
    defer s.free();
    foreach_r (i, v : r) s.appendf("%d:%d ", i, v);
    io::printfn("reverse: %s", s.str_view());

    // --- переполнение счётчиков
    Ring{int, 4} w;
    w.init_at(uint::max - 2);
    for (int i = 0; i < 100; i++)
    {
        w.push_overwrite(i);
        assert(w.len() == (sz)(i < 4 ? i + 1 : 4), "len after %d pushes: %d", i + 1, w.len());
        assert(w[w.len() - 1] == i);
        // на 5-й записи tail уже перевалил через 0, а head — ещё нет
        if (i == 4) assert(w.tail < w.head && w.len() == 4, "tail - head must survive the wrap");
    }
    assert(w.pop()!! == 96 && w.pop()!! == 97 && w.len() == 2);
    io::printfn("after wrap: head=%d tail=%d len=%d", w.head, w.tail, w.len());

    // --- история кадров: последние 8 сэмплов, скользящее среднее
    History h;
    float[*] signal = { 1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23 };
    foreach (i, v : signal)
    {
        h.push_overwrite({ (int)i, v });
    }
    float avg = 0;
    foreach (smp : h) avg += smp.value;
    avg /= h.len();
    assert(h[0].frame == 4 && h[7].frame == 11);
    io::printfn("history frames %d..%d, avg=%.2f", h[0].frame, h[h.len() - 1].frame, avg);
}
