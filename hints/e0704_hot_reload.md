After `Time? t = file::last_modified(e.path);`, handle the error first: `if (catch t) { ...; continue; }` — after that `t` is unwrapped (flow typing) and can be compared with `e.mtime`.
Assign `e.mtime = t;` BEFORE calling reload: then a broken file will not be re-read on every poll, and `reload` copies the new mtime along with the rest of the entry.
`if (catch self.reload(i)) { /* ERROR ... */ continue; }`, then `e.version++; changed[i] = true; reloads++;` and the log line.
Re-linking is a separate loop AFTER the first one: otherwise a material that comes before its shader would not see the shader's new version.
