Цикл потребителя: `while (true) { int? n = st.jobs.pop(); if (catch n) break; ... }` — после `if (catch n)` переменная n уже обычный int.
Без `jobs.close()` рабочие вечно ждут в pop(), и join не вернётся (раннер оборвёт программу по таймауту).
В пул передаётся функция `fn void(void*)` и указатель на данные задачи: `&square_task` и `task` (это уже `SquareTask*`).
