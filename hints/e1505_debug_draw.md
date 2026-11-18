`push`: check the mask `self.enabled_mask & (1u << cmd.cat.ordinal)`; then overflow
(`dropped++`), otherwise `self.cmds[self.count++] = cmd`.

`text`: build a `DebugCmd` with `.kind = TEXT`, copy `min(s.len, MAX_TEXT)` characters:
`cmd.text[:n] = s[:n];`, remember `text_len` and call `push`. You must not store the slice -
the caller's buffer will be overwritten.

BOX - four `c.line(...)` calls, one per side; TEXT - `c.plot(x0 + i, y0, text[i])` in a loop.

`flush`: first draw everything, then a second pass: `if (--cmds[i].frames_left > 0)
cmds[kept++] = cmds[i];` and `count = kept`. This is stable compaction - order is preserved.
