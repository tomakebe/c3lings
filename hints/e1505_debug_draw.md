`push`: проверка маски `self.enabled_mask & (1u << cmd.cat.ordinal)`; потом переполнение
(`dropped++`), иначе `self.cmds[self.count++] = cmd`.

`text`: соберите `DebugCmd` с `.kind = TEXT`, скопируйте `min(s.len, MAX_TEXT)` символов:
`cmd.text[:n] = s[:n];`, запомните `text_len` и вызовите `push`. Срез хранить нельзя —
буфер вызывающего будет переписан.

BOX — четыре `c.line(...)` по сторонам; TEXT — `c.plot(x0 + i, y0, text[i])` в цикле.

`flush`: сначала нарисуйте всё, потом второй проход: `if (--cmds[i].frames_left > 0)
cmds[kept++] = cmds[i];` и `count = kept`. Это стабильное уплотнение — порядок сохраняется.
