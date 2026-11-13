// =====================================================================
//  e1806 · Предсказание на клиенте и согласование с сервером
// =====================================================================
//
//  В модели «авторитетный сервер» клиент шлёт ВВОД, сервер симулирует
//  и шлёт обратно СОСТОЯНИЕ. Если клиент просто рисует состояние от
//  сервера, то при пинге 100 мс персонаж начинает двигаться через
//  100 мс после нажатия — играть невозможно.
//
//  Предсказание (client-side prediction): клиент применяет свой ввод
//  СРАЗУ, той же функцией движения, что и сервер, и хранит ещё не
//  подтверждённые вводы:
//
//      клиент: ввод #1 #2 #3 #4 #5 #6        x_pred идёт сразу
//      сервер:            ^ обработал #3: x = 30, last_seq = 3
//                         (пришло к клиенту, когда он уже на #6)
//
//  Согласование (server reconciliation) при получении состояния:
//
//      x = server.x                       // истина на момент #3
//      выбросить из pending все seq <= 3  // их сервер уже учёл
//      for (in : pending)  x = move(x, in)   // переиграть #4 #5 #6
//
//  Если сервер посчитал так же, как клиент, x не изменится — никакого
//  дёрганья. Если на сервере случилось то, чего клиент не знал (толчок,
//  стена, другой игрок), клиент плавно «телепортируется» на верный
//  результат, и дальше снова совпадает. Наивный вариант «x = server.x»
//  без переигрывания откатывает персонажа на RTT назад каждый пакет —
//  это знаменитый «резиновый» эффект (rubber-banding).
//
//  ЗАДАЧА: реализуйте Client.predict и Client.reconcile.
//
import std::io;

const int LATENCY = 4;     // тиков в каждую сторону
const int PENDING_CAP = 32;

struct Input { int seq; int move; }       // move: -1, 0, +1

// Общая (клиент и сервер) функция движения — ДОЛЖНА быть одинаковой.
fn int move_player(int x, int move) => x + move * 3;

struct Client
{
    int x;
    int next_seq;
    Input[PENDING_CAP] pending;
    int pending_count;
    int corrections;     // сколько раз согласование изменило предсказание
}

// Применить ввод локально и запомнить его. Вернуть ввод (с seq) для отправки.
fn Input Client.predict(&self, int move)
{
    // TODO: seq, применить move_player, положить в pending
    return { self.next_seq++, move };
}

// Пришло состояние от сервера: x после обработки ввода last_seq.
fn void Client.reconcile(&self, int server_x, int last_seq)
{
    // TODO: выбросить seq <= last_seq, x = server_x, переиграть оставшиеся;
    // если результат отличается от прежнего self.x — corrections++
    self.x = server_x;
    (void)last_seq;
}

// ---------------------------------------------------------------------
// Ниже ничего менять не нужно.

struct Server
{
    int x;
    int last_seq;
}

fn void Server.apply(&self, Input in, int tick)
{
    self.x = move_player(self.x, in.move);
    if (tick == 30) self.x -= 20;   // на сервере игрока толкнул взрыв — клиент не знал
    self.last_seq = in.seq;
}

struct ToServer { Input in; int arrive; }
struct ToClient { int x; int last_seq; int arrive; }

fn int script_move(int tick) => tick < 20 ? 1 : (tick < 35 ? 0 : (tick < 50 ? -1 : 1));

fn void main()
{
    Client c;
    Input i0 = c.predict(1);
    Input i1 = c.predict(1);
    Input i2 = c.predict(-1);
    assert(c.x == 3 && c.pending_count == 3 && i2.seq == 2, "предсказание применяется сразу");
    c.reconcile(3, 0);      // сервер учёл #0 и согласен
    assert(c.x == 3 && c.pending_count == 2 && c.corrections == 0, "согласие — без коррекции");
    c.reconcile(10, 1);     // сервер говорит: после #1 x = 10 (что-то случилось)
    assert(c.x == 7 && c.pending_count == 1 && c.corrections == 1, "10, затем переиграть #2 (-3)");
    (void)i0; (void)i1;
    io::printn("reconcile: ok");

    Client client;
    Server server;
    ToServer[64] up;
    int up_n = 0;
    ToClient[64] down;
    int down_n = 0;
    int rubber = 0;
    int prev_x = 0;
    for (int tick = 0; tick < 80; tick++)
    {
        // клиент: ввод и предсказание
        if (tick < 60)
        {
            Input in = client.predict(script_move(tick));
            up[up_n++] = { in, tick + LATENCY };
        }
        // сервер: обрабатывает пришедший ввод
        for (int k = 0; k < up_n; k++)
        {
            if (up[k].arrive == tick)
            {
                server.apply(up[k].in, tick);
                down[down_n++] = { server.x, server.last_seq, tick + LATENCY };
            }
        }
        // клиент: получает состояния
        for (int k = 0; k < down_n; k++)
        {
            if (down[k].arrive == tick) client.reconcile(down[k].x, down[k].last_seq);
        }
        int moving = tick < 60 ? script_move(tick) : 0;
        if (moving > 0 && client.x < prev_x) rubber++;
        if (moving < 0 && client.x > prev_x) rubber++;
        prev_x = client.x;
        if (tick % 10 == 9) io::printfn("tick %2d: client x=%4d server x=%4d pending=%d", tick, client.x, server.x, client.pending_count);
    }
    assert(client.x == server.x && client.pending_count == 0, "в конце клиент и сервер согласны");
    io::printfn("corrections=%d rubber-band frames=%d", client.corrections, rubber);
}
