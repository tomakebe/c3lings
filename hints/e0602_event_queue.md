push: если `count == QUEUE_CAP` — `dropped++` и `return false`; иначе запись в
`items[(head + count) % QUEUE_CAP]` и `count++`.
pop: если пусто — `false`; иначе `*out = items[head]`, `head = (head + 1) % QUEUE_CAP`, `count--`.
dispatch: `while (q.pop(&ev)) { switch (ev.kind) { ... } }`. Помните, что в C3
`case` не проваливается и `break` не нужен (но им можно выйти из switch досрочно,
например для мёртвого актёра в HEAL). Событие DIED кладите через `q.push(...)`
прямо во время разбора — цикл его тоже подхватит.
