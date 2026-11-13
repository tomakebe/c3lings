import std::io, std::thread;
// Драйвер упражнения a1305. Этот файл НЕ нужно править — правьте spin.s.

extern fn CInt spin_trylock(CInt* l);
extern fn void spin_lock(CInt* l);
extern fn void spin_unlock(CInt* l);

const int THREADS = 4;
const int ITERS = 100_000;

CInt lock;
long plain_counter;      // НЕ атомарный — защищён спинлоком
long pairs_ok = 1;
long a_val;
long b_val;

fn int worker(void* arg)
{
    for (int i = 0; i < ITERS; i++)
    {
        spin_lock(&lock);
        plain_counter++;
        // инвариант a == b должен сохраняться внутри критической секции
        a_val++;
        if (a_val != b_val + 1) pairs_ok = 0;
        b_val++;
        spin_unlock(&lock);
    }
    return 0;
}

fn void main()
{
    CInt l;
    assert(spin_trylock(&l) == 1, "free lock must be acquired");
    assert(spin_trylock(&l) == 0, "taken lock must not be acquired");
    spin_unlock(&l);
    assert(l == 0);
    assert(spin_trylock(&l) == 1);
    spin_unlock(&l);
    io::printn("trylock ok");

    Thread[THREADS] ts;
    foreach (&t : ts) t.create(&worker, null)!!;
    foreach (t : ts) (void)t.join();
    io::printfn("counter = %d, invariant held = %d", plain_counter, pairs_ok);
    assert(plain_counter == THREADS * ITERS && pairs_ok == 1);
}
