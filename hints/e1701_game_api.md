`api_compatible`: null -> false; otherwise compare `magic` with API_MAGIC, `version` with API_VERSION
and `size` with `GameApi::size` (this catches a module built against a different version of the header).
`reload`: get `next = get_api()`; if it's incompatible - return false WITHOUT touching `self.api`.
Otherwise: if there's an old api - `on_unload(&self.memory)`, then `self.api = next`,
`self.api.on_load(&self.memory)`, `reload_count++`, return true.
