// =====================================================================
//  e1802 · Надёжность поверх UDP: номера пакетов и ack-битовые поля
// =====================================================================
//
//  UDP не гарантирует ни доставку, ни порядок. TCP гарантирует оба, но
//  ценой задержки: если пакет 5 потерялся, пакеты 6, 7, 8 ждут в ядре,
//  пока 5 не придёт повторно (head-of-line blocking). Для игры это
//  катастрофа: свежая позиция игрока ждёт устаревшую. Поэтому игры
//  делают СВОЙ протокол поверх UDP — и надёжность только там, где нужна.
//
//  Схема Гленна Фидлера (Gaffer On Games, «Reliable UDP»):
//
//    * каждый пакет несёт номер `sequence` (ushort, растёт на 1);
//    * и подтверждения в ДРУГУЮ сторону — в каждом пакете:
//          ack       = самый свежий номер, полученный от собеседника;
//          ack_bits  = 32 бита: бит i => получен пакет (ack - 1 - i).
//      Одно подтверждение повторяется в ~33 пакетах подряд, поэтому
//      потеря пакета с acks почти ничего не стоит.
//
//          ack = 100, ack_bits = ...1011
//                                   |||'- 99 получен
//                                   ||'-- 98 получен
//                                   |'--- 97 НЕ получен
//                                   '---- 96 получен
//
//  ushort переполняется каждые 65536 пакетов (~18 мин при 60 Гц),
//  поэтому «новее» сравнивают с учётом заворота:
//
//      s1 новее s2, если (s1 > s2 && s1 - s2 <= 32768)
//                     || (s1 < s2 && s2 - s1 >  32768)
//
//  ЗАДАЧА: реализуйте seq_greater, Endpoint.on_receive (обновление
//  ack/ack_bits) и Endpoint.process_acks (пометить подтверждённые
//  отправленные пакеты).
//
import std::io;

const int WINDOW = 256;     // сколько последних отправленных пакетов помним

fn bool seq_greater(ushort s1, ushort s2)
{
    return s1 > s2; // TODO: учесть заворот
}

struct Packet
{
    ushort sequence;
    ushort ack;
    uint ack_bits;
}

struct SentInfo
{
    ushort sequence;
    bool valid;
    bool acked;
}

struct Endpoint
{
    ushort next_sequence;
    // приём
    ushort remote_ack;      // самый свежий полученный номер
    uint remote_ack_bits;
    bool received_any;
    // отправка
    SentInfo[WINDOW] sent;
    int acked_count;
}

fn Packet Endpoint.make_packet(&self)
{
    ushort seq = self.next_sequence++;
    self.sent[seq % WINDOW] = { seq, true, false };
    return { seq, self.remote_ack, self.remote_ack_bits };
}

// Учесть полученный номер в ack/ack_bits.
fn void Endpoint.on_receive(&self, ushort seq)
{
    // TODO: первый пакет; более новый (сдвиг битов); опоздавший (поставить бит)
    self.remote_ack = seq;
}

fn void Endpoint.ack_one(&self, ushort seq)
{
    SentInfo* s = &self.sent[seq % WINDOW];
    if (s.valid && s.sequence == seq && !s.acked)
    {
        s.acked = true;
        self.acked_count++;
    }
}

// Обработать заголовок пакета собеседника: его ack и ack_bits.
fn void Endpoint.process_acks(&self, ushort ack, uint ack_bits)
{
    // TODO: ack_one для ack и для каждого установленного бита
    (void)ack;
    (void)ack_bits;
}

// ---------------------------------------------------------------------
// Симуляция сети. Ниже ничего менять не нужно.

struct Lcg { uint state; }
fn uint Lcg.next(&self) { self.state = self.state * 1103515245 + 12345; return (self.state >> 16) & 0x7FFF; }

struct InFlight { Packet p; int arrive; bool to_b; bool used; }

fn void main()
{
    assert(seq_greater(1, 0) && !seq_greater(0, 1));
    assert(seq_greater(0, 65535), "0 новее 65535 (заворот)");
    assert(seq_greater(10, 65000) && !seq_greater(65000, 10));
    assert(!seq_greater(5, 5));

    Endpoint t;
    t.on_receive(10);
    t.on_receive(12);
    assert(t.remote_ack == 12 && t.remote_ack_bits == 0b10, "получены 12 и 10, 11 нет");
    t.on_receive(11);
    assert(t.remote_ack_bits == 0b11, "опоздавший 11");
    t.on_receive(50);
    assert(t.remote_ack == 50 && t.remote_ack_bits == 0, "большой скачок обнуляет биты");
    io::printn("acks: ok");

    // Два конца, 300 тиков, оба шлют пакет каждый тик. Сеть: задержка
    // 3..6 тиков (возможна перестановка), потеря 20%. Номера стартуют
    // у 65500, чтобы проверить заворот.
    Endpoint a = { .next_sequence = 65500 };
    Endpoint b = { .next_sequence = 65400 };
    InFlight[64] net;
    Lcg rng = { 12345 };
    int lost = 0;
    int sent_a = 0;
    for (int tick = 0; tick < 300; tick++)
    {
        // доставка
        foreach (&f : net)
        {
            if (!f.used || f.arrive != tick) continue;
            f.used = false;
            Endpoint* dst = f.to_b ? &b : &a;
            dst.on_receive(f.p.sequence);
            dst.process_acks(f.p.ack, f.p.ack_bits);
        }
        // отправка
        for (int dir = 0; dir < 2; dir++)
        {
            Endpoint* src = dir == 0 ? &a : &b;
            Packet p = src.make_packet();
            if (dir == 0) sent_a++;
            if (rng.next() % 100 < 20) { lost++; continue; }
            foreach (&f : net)
            {
                if (f.used) continue;
                *f = { p, tick + 3 + (int)(rng.next() % 4), dir == 0, true };
                break;
            }
        }
    }
    io::printfn("a: sent=%d acked=%d (next seq %d)", sent_a, a.acked_count, a.next_sequence);
    io::printfn("b: acked=%d, lost in network=%d", b.acked_count, lost);
    assert(a.acked_count > 220 && a.acked_count < 260);
}
