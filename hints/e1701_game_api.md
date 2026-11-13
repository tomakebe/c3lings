`api_compatible`: null -> false; иначе сравните `magic` с API_MAGIC, `version` с API_VERSION
и `size` с `GameApi::size` (так ловится модуль, собранный с другой версией заголовка).
`reload`: получите `next = get_api()`; если несовместим — верните false, НЕ трогая `self.api`.
Иначе: если старый api есть — `on_unload(&self.memory)`, затем `self.api = next`,
`self.api.on_load(&self.memory)`, `reload_count++`, вернуть true.
