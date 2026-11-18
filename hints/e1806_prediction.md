`predict`: `Input in = { self.next_seq++, move };` apply `self.x = move_player(self.x, move)`,
append `in` to `pending`, return it.
`reconcile`: remember `before = self.x`; keep only inputs with `seq > last_seq` in pending (compact the array);
`x = server_x`, then for each remaining one `x = move_player(x, pending[i].move)`; `self.x = x`;
if `self.x != before` - `corrections++`.
