`execute_job`: `job.func(job.data); js.executed.add(1);` и, если есть счётчик, `job.counter.value.sub(1)`.
`run_jobs`: сначала `counter.value.add((int)jobs.len)`, и только потом `push` — иначе ожидающий может увидеть 0 раньше времени.
`foreach (job : jobs)` даёт копию задачи — её можно спокойно менять перед `push`.
`wait_for_counter`: `while (counter.value.load() != 0) { Job job; if (self.try_pop(&job)) { execute_job(self, job); } else { thread::yield(); } }`.
Если программа зависает — значит, ожидающий не выполняет чужие задачи сам (см. рисунок с deadlock в шапке).
