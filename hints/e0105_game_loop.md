`start`: `self.last_us = clock.now_us();` — иначе первый кадр длиной в «аптайм».
`run_frame` — это E0103 плюс две вещи: при `paused` длительность кадра становится 0
(аккумулятор не меняется, поэтому alpha сама «замерзает»), а масштаб применяется к
кадру через остаток: `scaled = frame * num + rem; acc += scaled / den; rem = scaled % den;`.
Тики вызывают `game.fixed_update(self.tick, self.dt_us)` и увеличивают `self.tick`;
в конце — `game.render((double)self.acc_us / (double)self.dt_us)`.
