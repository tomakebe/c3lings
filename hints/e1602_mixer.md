`pan_gains`: угол `(pan + 1) * PI / 4`, левый — `math::cos`, правый — `math::sin` (не забудьте привести PI к float).
`mix_voice`: для каждого кадра f сначала проверьте `v.pos >= v.samples.len` — либо `pos = 0` (looping),
либо `active = false` и выход. Затем `s = samples[pos++] * gain`, `out[2f] += s*gl`, `out[2f+1] += s*gr`.
Обратите внимание: прибавляем (`+=`), а не присваиваем — иначе голоса затрут друг друга.
`to_s16_master`: y = x * master; считаем клиппинг ДО обрезки; потом hard/soft clip; потом округление как в e1601.
