`init`: `self.prev = self.next = self`. `is_empty`: `self.next == self`.
`insert_after`: четыре присваивания из шапки (порядок важен: сначала заполните n, потом соседей).
`push_back(n)` == `self.prev.insert_after(n)`, `push_front(n)` == `self.insert_after(n)`.
`unlink`: связать соседей друг с другом, затем вернуть узел в «указывает на себя».
`@container_of`: `return ($Type*)((char*)ptr - $reflect($Type.$eval($member)).offset);`
`@list_each`: `for (ListNode* n = head.next; n != head;) { ListNode* next = n.next; @body(@container_of(n, $Type, $member)); n = next; }`
LRU: попадание — `unlink` + `push_front`; вытеснение — хвост это `self.order.prev`.
