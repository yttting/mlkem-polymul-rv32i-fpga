/* Compare CPU loop overhead when inputs already reside in local RAM. */

typedef unsigned int uint32_t;

#ifndef LOOP_MODE
#define LOOP_MODE 0
#endif

#if LOOP_MODE < 0 || LOOP_MODE > 3
#error "LOOP_MODE must be 0 (baseline), 1 (write x4), 2 (read x4), or 3 (both x4)"
#endif

#define ACCEL_BASE      0x40000000u
#define DBG_BASE        0x50000000u

#define ACCEL_CONTROL   (ACCEL_BASE + 0x0000u)
#define ACCEL_CYCLES    (ACCEL_BASE + 0x0004u)
#define ACCEL_SIGNATURE (ACCEL_BASE + 0x0008u)
#define ACCEL_A_BASE    (ACCEL_BASE + 0x1000u)
#define ACCEL_B_BASE    (ACCEL_BASE + 0x1200u)
#define ACCEL_O_BASE    (ACCEL_BASE + 0x1400u)

#define DBG_STATUS      (DBG_BASE + 0x00u)
#define DBG_DETAIL      (DBG_BASE + 0x04u)
#define DBG_MODE        (DBG_BASE + 0x08u)
#define DBG_WRITE       (DBG_BASE + 0x0cu)
#define DBG_START       (DBG_BASE + 0x10u)
#define DBG_POLL        (DBG_BASE + 0x14u)
#define DBG_READ        (DBG_BASE + 0x18u)
#define DBG_CALL        (DBG_BASE + 0x1cu)
#define DBG_CORE        (DBG_BASE + 0x20u)
#define DBG_POLLS       (DBG_BASE + 0x24u)
#define DBG_STAGE_SUM   (DBG_BASE + 0x28u)
#define DBG_RDCYCLE     (DBG_BASE + 0x2cu)

#define STATUS_RUNNING  0x52554e21u
#define STATUS_PASS     0x600d600du
#define STATUS_BAD_ID   0xdead0001u
#define STATUS_TIMEOUT  0xdead0002u
#define STATUS_MISMATCH 0xdead0003u
#define STATUS_ACCESS   0xdead0004u
#define STATUS_ACCOUNT  0xdead0005u

#define Q 3329u

#include "expected_words.h"

static uint32_t a_words[128];
static uint32_t b_words[128];
static volatile uint32_t benchmark_errors;

static inline void mmio_write32(uint32_t address, uint32_t value)
{
    *(volatile uint32_t *)address = value;
}

static inline uint32_t mmio_read32(uint32_t address)
{
    return *(volatile uint32_t *)address;
}

static inline uint32_t read_cycle(void)
{
    uint32_t value;
    __asm__ volatile ("rdcycle %0" : "=r"(value) : : "memory");
    return value;
}

static inline uint32_t add_mod_once(uint32_t x, uint32_t y)
{
    uint32_t z = x + y;
    return z >= Q ? z - Q : z;
}

static void generate_inputs(void)
{
    uint32_t a = 7u, da = 48u;
    uint32_t b = 19u, db = 40u;
    uint32_t i;

    for (i = 0; i < 128; ++i) {
        uint32_t a0 = a;
        a = add_mod_once(a, da);
        da = add_mod_once(da, 34u);
        uint32_t a1 = a;
        a = add_mod_once(a, da);
        da = add_mod_once(da, 34u);

        uint32_t b0 = b;
        b = add_mod_once(b, db);
        db = add_mod_once(db, 58u);
        uint32_t b1 = b;
        b = add_mod_once(b, db);
        db = add_mod_once(db, 58u);

        a_words[i] = a0 | (a1 << 16);
        b_words[i] = b0 | (b1 << 16);
    }
}

static void write_inputs(void)
{
    uint32_t i;
#if LOOP_MODE == 1 || LOOP_MODE == 3
#pragma GCC unroll 4
#endif
    for (i = 0; i < 128; ++i) {
        mmio_write32(ACCEL_A_BASE + 4u*i, a_words[i]);
        mmio_write32(ACCEL_B_BASE + 4u*i, b_words[i]);
    }
}

static uint32_t poll_until_done(uint32_t *polls_out)
{
    uint32_t control;
    uint32_t polls = 0;
    do {
        control = mmio_read32(ACCEL_CONTROL);
        ++polls;
        if (polls == 20000u) {
            *polls_out = polls;
            return 0xffffffffu;
        }
    } while ((control & 2u) == 0u);
    *polls_out = polls;
    return control;
}

static void read_outputs(void)
{
    uint32_t i;
#if LOOP_MODE == 2 || LOOP_MODE == 3
#pragma GCC unroll 4
#endif
    for (i = 0; i < 128; ++i)
        a_words[i] = mmio_read32(ACCEL_O_BASE + 4u*i);
}

static uint32_t check_outputs(void)
{
    uint32_t i;
    uint32_t errors = 0;
    for (i = 0; i < 128; ++i)
        if (a_words[i] != expected_words[i])
            ++errors;
    return errors;
}

void _start(void)
{
    uint32_t r0, r1, t0, t1, t2, t3, t4;
    uint32_t control, polls, errors, core_cycles;
    uint32_t write_cycles, start_cycles, poll_cycles, read_cycles;
    uint32_t call_cycles, stage_sum;

    mmio_write32(DBG_STATUS, STATUS_RUNNING);
    mmio_write32(DBG_DETAIL, 0u);
    if (mmio_read32(ACCEL_SIGNATURE) != 0x56333945u) {
        mmio_write32(DBG_STATUS, STATUS_BAD_ID);
        while (1) { }
    }

    /* The input source is local CPU RAM and is ready before call timing. */
    generate_inputs();
    r0 = read_cycle();
    r1 = read_cycle();
    t0 = read_cycle();

    write_inputs();
    t1 = read_cycle();
    mmio_write32(ACCEL_CONTROL, 1u);
    t2 = read_cycle();
    control = poll_until_done(&polls);
    t3 = read_cycle();

    if (control == 0xffffffffu) {
        mmio_write32(DBG_DETAIL, polls);
        mmio_write32(DBG_STATUS, STATUS_TIMEOUT);
        while (1) { }
    }
    if ((control & 0x10u) != 0u) {
        mmio_write32(DBG_DETAIL, control);
        mmio_write32(DBG_STATUS, STATUS_ACCESS);
        while (1) { }
    }

    read_outputs();
    t4 = read_cycle();

    /* Correctness checking is deliberately outside call timing. */
    errors = check_outputs();
    benchmark_errors = errors;

    write_cycles = t1 - t0;
    start_cycles = t2 - t1;
    poll_cycles = t3 - t2;
    read_cycles = t4 - t3;
    call_cycles = t4 - t0;
    stage_sum = write_cycles + start_cycles + poll_cycles + read_cycles;
    core_cycles = mmio_read32(ACCEL_CYCLES);

    mmio_write32(DBG_MODE, LOOP_MODE);
    mmio_write32(DBG_WRITE, write_cycles);
    mmio_write32(DBG_START, start_cycles);
    mmio_write32(DBG_POLL, poll_cycles);
    mmio_write32(DBG_READ, read_cycles);
    mmio_write32(DBG_CALL, call_cycles);
    mmio_write32(DBG_CORE, core_cycles);
    mmio_write32(DBG_POLLS, polls);
    mmio_write32(DBG_STAGE_SUM, stage_sum);
    mmio_write32(DBG_RDCYCLE, r1 - r0);

    if (stage_sum != call_cycles) {
        mmio_write32(DBG_DETAIL, stage_sum - call_cycles);
        mmio_write32(DBG_STATUS, STATUS_ACCOUNT);
    } else if (errors != 0u) {
        mmio_write32(DBG_DETAIL, errors);
        mmio_write32(DBG_STATUS, STATUS_MISMATCH);
    } else {
        mmio_write32(DBG_STATUS, STATUS_PASS);
    }

    while (1) { }
}
