`begin`: если `cursor < txn_len`, обрежьте `txn_len = cursor`, а `cmd_len` поставьте на конец последней
оставшейся транзакции (`first + count`, или 0).
`commit` (слияние): pending.merge_key != 0, в pending одна команда, `cursor == txn_len`, у последней транзакции
тот же merge_key, одна команда и тот же target — тогда `lc.new_value = nc.new_value; self.cmd_len--; return;`.
`cancel` и `undo`: идите по командам от последней к первой и пишите `doc[target] = old_value`;
в cancel ещё верните `cmd_len = pending.first`.
