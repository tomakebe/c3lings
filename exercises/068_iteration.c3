// =====================================================================
//  068 · Итерация по собственным типам
// =====================================================================
//
//  В C3 два основных способа «пройтись по элементам» своего типа.
//
//  1) foreach через операторы `len` и `[]` (см. 062). Подходит, когда
//     у элементов есть индексы. Хранить элементы не обязательно —
//     `[]` может их ВЫЧИСЛЯТЬ:
//
//         struct Squares { int count; }
//         fn int Squares.get(&self, sz i) @operator([]) => (int)(i * i);
//         fn sz  Squares.len(&self) @operator(len) => self.count;
//
//         foreach (x : (Squares){ 5 }) ...   // 0 1 4 9 16 — без массива
//
//  2) Итератор с методом `next()`, возвращающим Optional. Когда элементы
//     кончились, `next()` возвращает ошибку (обычно свою excuse вроде
//     `DONE` или стандартную `NO_MORE_ELEMENT`). А цикл — это `while`
//     с `try`-распаковкой, которую вы знаете из 032:
//
//         while (try x = it.next())
//         {
//             ...   // x — уже обычное значение, не Optional
//         }
//
//     Цикл заканчивается, как только `next()` вернул ошибку. Такой
//     итератор подходит для потоков, генераторов, парсеров — там, где
//     длина заранее неизвестна, а произвольного доступа нет.
//     Итератор — обычная структура с состоянием; `next` принимает
//     `&self`, потому что сдвигает это состояние.
//
//  Стандартная библиотека использует второй стиль повсюду. Например,
//  `String.tokenize(разделители)` возвращает `Splitter` — итератор по
//  кускам строки без выделения памяти:
//
//      Splitter words = "a b  c".tokenize(" ");
//      while (try w = words.next()) io::printn(w);   // a, b, c
//
//  (Есть и третий способ — макрос с «хвостовым блоком», как у
//  `HashMap.@each`, — его мы научимся писать в разделе про макросы.)
//
//  ЗАДАЧА: допишите конец итерации в `Range.next`, циклы по Range и по
//  словам. Ожидаемый вывод:
//      squares: 0 1 4 9 16
//      range: 10 13 16 19
//      words: the|quick|brown|fox
//      word count: 4
//
import std::io;

excuse DONE;

// Вычисляемая последовательность квадратов: ничего не хранит.
struct Squares
{
    int count;
}
fn int Squares.get(&self, sz i) @operator([]) => (int)(i * i);
fn sz Squares.len(&self) @operator(len) => self.count;

// Арифметическая прогрессия [start, end) с шагом step.
struct Range
{
    int current, end, step;
}

fn int? Range.next(&self)
{
    // TODO: когда прогрессия дошла до end, сообщите о конце итерации
    int value = self.current;
    self.current += self.step;
    return value;
}

fn void main()
{
    io::print("squares:");
    foreach (x : (Squares){ 5 }) io::printf(" %d", x);
    io::printn();

    Range r = { .current = 10, .end = 20, .step = 3 };
    io::print("range:");
    while (???) io::printf(" %d", v);
    io::printn();

    Splitter words = "the quick  brown fox".tokenize(" ");
    int count;
    io::print("words: ");
    foreach (w : words)   // <- у Splitter нет len и []
    {
        if (count > 0) io::print("|");
        io::print(w);
        count++;
    }
    io::printn();
    io::printfn("word count: %d", count);
}
