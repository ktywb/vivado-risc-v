#include <stdio.h>

#ifdef __riscv
#include <sys/time.h>
#else
#include <time.h>
#include <x86intrin.h>
#endif

#include "encoding.h"  // For rdcycle

static inline unsigned long long get_cycles() {
#ifdef __riscv
  return rdcycle();
#else
  // Use host's monotonic clock (example using clock_gettime)
  // This gives nanoseconds, not cycles, but provides a time measurement
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (unsigned long long)ts.tv_sec * 1000000000 + ts.tv_nsec;
  // Alternatively, return 0 if host timing is not needed
  // return 0;
#endif
}

int main() {
  unsigned long long start_cycle = get_cycles();
  for (int i = 0; i < 10000; i++) {
    // nop
  }
  unsigned long long end_cycle = get_cycles();
  unsigned long long cycle_diff = end_cycle - start_cycle;
  unsigned int cycle_high = (unsigned int)(cycle_diff >> 32);
  unsigned int cycle_low = (unsigned int)(cycle_diff & 0xFFFFFFFF);

  printf("Execution Cycles: 0x%x%08x\n", cycle_high, cycle_low);
}