Label: `String name = text[:text.len - 1];`, duplicate check - `if (@ok(self.label_index(name))) return DUPLICATE_LABEL~;`,
then record `label_names`/`label_pos` (address = `self.len`) and increment `nlabels`.
Operands: `case "load": self.emit(LOAD, self.global_index(rest)!)!;`, `call` goes through `native_index(rest)!`,
jumps - `self.emit_jump(JMP, rest, self.error_line)!;`.
emit_jump: `if (try li = self.label_index(label)) { self.emit(op, self.label_pos[li])!; return; }`, otherwise a fixup.
At the end of assemble: `int li = self.label_index(f.label)!; self.code[f.at].arg = self.label_pos[li];`.
