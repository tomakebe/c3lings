// =====================================================================
//  103 · Собственный аллокатор, реализующий Allocator
// =====================================================================
//
//  Весь код стандартной библиотеки, который выделяет память, работает
//  через интерфейс Allocator (std::core::mem::alloc). Вот он целиком:
//
//      interface Allocator
//      {
//          fn void*? acquire(sz size, AllocInitType init_type, sz alignment = 0);
//          fn void*? resize(void* ptr, sz new_size, sz alignment = 0);
//          fn void release(void* ptr, bool aligned);
//      }
//
//  * acquire — выделить `size` байт (size > 0) с выравниванием
//    `alignment` (0 = «по умолчанию», mem::DEFAULT_MEM_ALIGNMENT,
//    16 на x86-64). init_type == ZERO — память надо обнулить,
//    NO_ZERO — можно оставить как есть. Нет места — вернуть
//    `mem::OUT_OF_MEMORY~`.
//  * resize — как realloc: вернуть блок нового размера с тем же
//    содержимым (в пределах меньшего из размеров). Может вернуть тот
//    же указатель или новый — тогда старый считается освобождённым.
//  * release — вернуть блок.
//
//  Чтобы структура реализовала интерфейс, её объявляют с `(Allocator)`,
//  а методы помечают @dynamic (вызов через интерфейс — динамический,
//  через таблицу методов, как виртуальные функции):
//
//      struct BumpAllocator (Allocator) { ... }
//      fn void*? BumpAllocator.acquire(&self, sz size, AllocInitType init_type, sz alignment) @dynamic { ... }
//
//  После этого указатель на ваш аллокатор — это Allocator:
//
//      BumpAllocator bump;
//      Allocator a = &bump;
//      List{int} list;  list.init(a);         // список растёт в вашей памяти
//      String s = string::format(a, "x=%d", 1);
//      int* p = alloc::new(a, int);           // типизированные помощники
//      int[] arr = alloc::new_array(a, int, 10);
//      alloc::free(a, p);
//
//  (Внимание: в старых версиях и в части документации это
//  `allocator::new(...)`; в 0.8.5 модуль называется `alloc`.)
//
//  Bump-аллокатор (он же линейный, он же арена) — самый простой и
//  самый быстрый: есть буфер и указатель «занято до сюда». Выделение
//  = выровнять указатель и сдвинуть его на size. Освобождать по
//  одному блоку он не умеет (release ничего не делает), зато сброс
//  всего сразу — одно присваивание `used = 0`. Идеален для данных
//  с общим временем жизни: всё, что нужно для одного кадра игры,
//  одного запроса сервера, одного прохода компилятора. Так устроены
//  tmem и @pool в самой C3 (и ArenaAllocator в std).
//
//  Выравнивание. Адрес блока должен быть кратен alignment (степень
//  двойки). Округление вверх: `(addr + align - 1) & ~(align - 1)` —
//  в стандартной библиотеке это `mem::aligned_pointer(ptr, align)`.
//  Невыровненный double или SIMD-вектор на x86 — в лучшем случае
//  медленно, в худшем — падение (movaps).
//
//  Заголовок блока. resize должен знать СТАРЫЙ размер блока, чтобы
//  скопировать данные. Поэтому перед каждым блоком мы храним маленький
//  заголовок BlockHeader с размером. Раскладка в буфере:
//
//      | ...занято... | BlockHeader | (padding) |  данные size байт  | ...
//                                                ^ возвращаемый указатель p,
//                                                  заголовок — (BlockHeader*)p - 1
//
//  Резервируем место под заголовок ДО выравнивания: берём
//  `start = buffer.ptr + used + BlockHeader::size`, выравниваем start
//  вверх — получаем p. Перед p гарантированно помещается заголовок.
//
//  Сравнение: в Zig то же самое — std.mem.Allocator с vtable
//  (alloc/resize/free), и все контейнеры принимают аллокатор явно.
//  В C++ — std::pmr::memory_resource. В C обычно этого нет вовсе.
//
//  ЗАДАЧА: реализуйте BumpAllocator.acquire:
//    1. alignment меньше mem::DEFAULT_MEM_ALIGNMENT (включая 0) —
//       используйте mem::DEFAULT_MEM_ALIGNMENT;
//    2. p = выровненный (buffer.ptr + used + BlockHeader::size);
//    3. конец блока end = (p - buffer.ptr) + size; если end больше длины
//       буфера — верните mem::OUT_OF_MEMORY~;
//    4. запишите size в заголовок, used = end, acquires++;
//    5. при init_type == ZERO обнулите блок: mem::clear(p, size);
//    6. верните p.
//
//  Ожидаемый вывод:
//      list: 40 items, last = 1521
//      acquires: 3, releases: 2, used: 496
//      greeting: hello, allocator #42
//      new int: 0, aligned: true
//      too big: mem::OUT_OF_MEMORY
//      after reset: used = 0
//
import std::io, std::collections::list;

struct BlockHeader
{
    sz size;
    sz _reserved;
}

struct BumpAllocator (Allocator)
{
    char[] buffer;
    sz used;
    int acquires;
    int releases;
}

fn void BumpAllocator.init(&self, char[] buffer)
{
    *self = { .buffer = buffer };
}

fn void BumpAllocator.reset(&self)
{
    self.used = 0;
}

fn void*? BumpAllocator.acquire(&self, sz size, AllocInitType init_type, sz alignment) @dynamic
{
    // TODO: см. ЗАДАЧУ в шапке
    return mem::OUT_OF_MEMORY~;
}

fn void*? BumpAllocator.resize(&self, void* ptr, sz new_size, sz alignment) @dynamic
{
    sz old_size = ((BlockHeader*)ptr - 1).size;
    void* p = self.acquire(new_size, NO_ZERO, alignment)!;
    mem::copy(p, ptr, min(old_size, new_size));
    self.release(ptr, alignment > 0);
    return p;
}

fn void BumpAllocator.release(&self, void* ptr, bool aligned) @dynamic
{
    // bump-аллокатор не освобождает отдельные блоки
    self.releases++;
}

fn void main()
{
    char[1024] storage @align(16);
    BumpAllocator bump;
    bump.init(&storage);
    Allocator a = &bump;

    List{int} list;
    list.init(a);
    for (int i = 0; i < 40; i++) list.push(i * i);
    io::printfn("list: %d items, last = %d", list.len(), list[^1]);
    io::printfn("acquires: %d, releases: %d, used: %d", bump.acquires, bump.releases, bump.used);

    String s = string::format(a, "hello, allocator #%d", 42);
    io::printfn("greeting: %s", s);

    int* p = alloc::new(a, int);
    io::printfn("new int: %d, aligned: %s", *p, (uptr)p % 16 == 0);

    int[]? huge = alloc::new_array_try(a, int, 1000);
    if (catch err = huge) io::printfn("too big: %s", err);

    bump.reset();
    io::printfn("after reset: used = %d", bump.used);
}
