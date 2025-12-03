#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>

// sleep for a specified number of microseconds
static void usleep(unsigned us) {
    uintptr_t cycles0;
    uintptr_t cycles1;
    asm volatile ("csrr %0, 0xB00" : "=r" (cycles0));
    for (;;) {
        asm volatile ("csrr %0, 0xB00" : "=r" (cycles1));
        if (cycles1 - cycles0 >= us * FPGA_CPU_CLK_FREQ) break;
    }
}

// take snapshot of current CPU cycle count
static inline uint32_t read_mcycle() {
    uint32_t cycles;
    asm volatile ("csrr %0, mcycle" : "=r"(cycles));
    return cycles;
}

// sleep for a specified number of CPU cycles
static inline void usleep_cycles(uint64_t cycles) {
    uint64_t start;
    asm volatile("rdcycle %0" : "=r"(start));
    while ((read_mcycle() - start) < cycles);
}

static inline uint64_t read_mcycle64() {
    uint32_t hi1, lo, hi2;
    do {
        asm volatile ("csrr %0, mcycleh" : "=r"(hi1));
        asm volatile ("csrr %0, mcycle"  : "=r"(lo));
        asm volatile ("csrr %0, mcycleh" : "=r"(hi2));
    } while (hi1 != hi2);
    return ((uint64_t)hi1 << 32) | lo;
}

#endif
