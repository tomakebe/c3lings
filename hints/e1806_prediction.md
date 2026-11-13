`predict`: `Input in = { self.next_seq++, move };` примените `self.x = move_player(self.x, move)`,
добавьте `in` в `pending`, верните его.
`reconcile`: запомните `before = self.x`; оставьте в pending только вводы с `seq > last_seq` (сжатие массива);
`x = server_x`, затем для каждого оставшегося `x = move_player(x, pending[i].move)`; `self.x = x`;
если `self.x != before` — `corrections++`.
