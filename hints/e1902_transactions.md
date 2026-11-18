`begin`: if `cursor < txn_len`, truncate `txn_len = cursor`, and set `cmd_len` to the end of the last
remaining transaction (`first + count`, or 0).
`commit` (merging): pending.merge_key != 0, pending has one command, `cursor == txn_len`, the last transaction has
the same merge_key, one command and the same target - then `lc.new_value = nc.new_value; self.cmd_len--; return;`.
`cancel` and `undo`: walk the commands from last to first and write `doc[target] = old_value`;
in cancel also restore `cmd_len = pending.first`.
