Сначала нормализуйте выравнивание: `if (alignment < mem::DEFAULT_MEM_ALIGNMENT) alignment = mem::DEFAULT_MEM_ALIGNMENT;`.
Указатель: `void* p = mem::aligned_pointer(self.buffer.ptr + self.used + BlockHeader::size, alignment);`.
Конец блока: `sz end = (sz)(p - self.buffer.ptr) + size;` и сравнение с `(sz)self.buffer.len`.
Заголовок лежит прямо перед p: `((BlockHeader*)p - 1).size = size;` (resize его читает).
Не забудьте `self.used = end; self.acquires++;` и `mem::clear(p, size)` для ZERO.
