get_int: `return parse_int(find_value(cfg, key)!);` — `!` пробрасывает MISSING_KEY, а результат parse_int и так `int?`.
port: `get_int(cfg, "port")!`; workers: `get_int(cfg, "workers") ?? 4`.
timeout: `??` справа может стоять ошибка: `get_int(cfg, "timeout") ?? INVALID_TIMEOUT~` — это всё ещё `int?`, так что добавьте `!` в конце, чтобы пробросить.
describe: `switch (err) { case MISSING_KEY: return "..."; ... default: return "unknown error"; }`.
