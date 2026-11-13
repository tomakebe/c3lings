Метка: `String name = text[:text.len - 1];`, проверка повтора — `if (@ok(self.label_index(name))) return DUPLICATE_LABEL~;`,
затем запишите `label_names`/`label_pos` (адрес = `self.len`) и увеличьте `nlabels`.
Операнды: `case "load": self.emit(LOAD, self.global_index(rest)!)!;`, `call` — через `native_index(rest)!`,
переходы — `self.emit_jump(JMP, rest, self.error_line)!;`.
emit_jump: `if (try li = self.label_index(label)) { self.emit(op, self.label_pos[li])!; return; }`, иначе fixup.
В конце assemble: `int li = self.label_index(f.label)!; self.code[f.at].arg = self.label_pos[li];`.
