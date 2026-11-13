// =====================================================================
//  075 · Методы generic-типов
// =====================================================================
//
//  Generic-структура без методов — полдела. Методы для неё объявляются
//  как обычно, а параметры структуры (`Type`) в них просто доступны:
//
//      struct Stack <Type>
//      {
//          Type[16] items;
//          usz len;
//      }
//
//      fn void Stack.push(&self, Type value)
//      {
//          self.items[self.len++] = value;
//      }
//
//  Метод автоматически становится частью той же группы, что и тип:
//  при создании `Stack{int}` появится и `Stack{int}.push(int)`.
//  Вызов — обычный, без всяких `{...}`: `s.push(3)`.
//
//  ПОДВОДНЫЙ КАМЕНЬ: у такого метода НЕ надо писать `<Type>` после
//  аргументов. Параметры приходят от типа, а `fn void Stack.push(...)
//  <Type>` даст ошибку "This declaration cannot be generic". И имя
//  должно совпадать с именем в объявлении структуры: если структура
//  объявлена как `<Type>`, в методе нельзя вдруг назвать его `Elem`.
//
//  Метод можно добавить и ТОЛЬКО одному инстанцированию:
//
//      fn int Stack{int}.sum(&self) { ... }
//
//  Теперь `sum` есть у `Stack{int}`, но не у `Stack{String}` (у строк
//  суммы и не бывает). Внутри такого метода `Type` недоступен — тип
//  конкретный, пишите `int`. Это аналог частичной специализации в C++,
//  только гораздо проще.
//
//  Методы работают и с перегрузкой операторов (упражнения 061–063), так
//  что generic-контейнер может поддерживать индексацию и `foreach`:
//
//      fn Type Stack.get(&self, usz i) @operator([]) => self.items[i];
//      fn usz Stack.count(&self) @operator(len) => self.len;
//
//      foreach (i, v : s) { ... }
//
//  Именно так устроены `List`, `HashMap` и прочие контейнеры std —
//  загляните в `lib/std/collections/list.c3`, теперь вы прочитаете
//  его без труда.
//
//  Методы можно добавлять к generic-типу и из ДРУГОГО модуля (как и к
//  любому типу) — например, дописать удобный метод к `List` у себя.
//
//  ЗАДАЧА:
//    1. Исправьте объявление `push` (компилятор подскажет, что не так).
//    2. Реализуйте `pop` и `peek`.
//    3. Реализуйте `sum` — метод, который есть только у `Stack{int}`.
//
import std::io;

struct Stack <Type>
{
    Type[16] items;
    usz len;
}

fn void Stack.push(&self, Type value)
{
    assert(self.len < self.items.len, "stack overflow");
    self.items[self.len++] = value;
}

fn Type Stack.pop(&self)
{
    assert(self.len > 0, "pop from empty stack");
    return self.items[--self.len];
}

fn Type Stack.peek(&self) => self.items[self.len - 1];

fn bool Stack.is_empty(&self) => self.len == 0;

fn Type Stack.get(&self, usz i) @operator([]) => self.items[i];
fn usz Stack.count(&self) @operator(len) => self.len;

fn int Stack{int}.sum(&self)
{
    int total;
    foreach (v : *self) total += v;
    return total;
}

fn void main()
{
    Stack{int} nums;
    for (int i = 1; i <= 4; i++) nums.push(i * 10);
    assert(nums.peek() == 40);
    assert(nums.sum() == 100);
    io::printfn("sum = %d", nums.sum());

    foreach (i, v : nums) io::printfn("nums[%d] = %d", i, v);

    assert(nums.pop() == 40);
    assert(nums.pop() == 30);
    io::printfn("after two pops: len = %d, top = %d", nums.len, nums.peek());

    Stack{String} words;
    words.push("first");
    words.push("second");
    io::printfn("%s", words.pop());
    io::printfn("%s", words.pop());
    assert(words.is_empty());

    // У Stack{String} метода sum нет:
    $assert !$defined(words.sum);
    io::printn("ok");
}
