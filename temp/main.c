#include <stdio.h>
#include <stdint.h>

// Example: Read RISC-V cycle counter
static inline uint64_t rdcycle(void) {
    uint64_t cycles;
    __asm__ volatile ("rdcycle %0" : "=r"(cycles));
    return cycles;
}

static inline uint64_t rdtime(void) {
    uint64_t time;
    __asm__ volatile ("rdtime %0" : "=r"(time));
    return time;
}

static inline uint64_t rdinstret(void) {
    uint64_t instret;
    __asm__ volatile ("rdinstret %0" : "=r"(instret));
    return instret;
}

int main(int argc, char *argv[]) {
    printf("Hello from RISC-V 64-bit!\n");
    
    // Test performance counters
    uint64_t cycle1 = rdcycle();
    uint64_t time1 = rdtime();
    uint64_t inst1 = rdinstret();
    
    // Do some work
    volatile int sum = 0;
    for (int i = 0; i < 1000000; i++) {
        sum += i;
    }
    
    uint64_t cycle2 = rdcycle();
    uint64_t time2 = rdtime();
    uint64_t inst2 = rdinstret();
    
    printf("\nPerformance Counters:\n");
    printf("  Cycles:       %lu -> %lu (delta: %lu)\n", cycle1, cycle2, cycle2 - cycle1);
    printf("  Time:         %lu -> %lu (delta: %lu)\n", time1, time2, time2 - time1);
    printf("  Instructions: %lu -> %lu (delta: %lu)\n", inst1, inst2, inst2 - inst1);
    printf("  Result: %d\n", sum);
    
    return 0;
}
