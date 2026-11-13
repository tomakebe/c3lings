Три шага по порядку. (1) `if (frame_us > self.max_frame_us)`: прибавить разницу к
`dropped_us`, обрезать кадр, `clamped_frames++`. (2) Цикл тиков с дополнительным
условием `steps < self.max_steps`. (3) После цикла, если `acc_us >= dt_us`:
`keep = acc_us % dt_us`, в `dropped_us` уходит `acc_us - keep`, `acc_us = keep`,
`limited_frames++`. Проверьте себя инвариантом `ticks*dt + acc + dropped == real`.
