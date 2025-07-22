#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <time.h>

#include "compiler.h"
#include "encoding.h"
#include "rocc.h"

// --- Helper function to get cycles/time ---
static inline unsigned long long get_cycles() {
#ifdef __riscv
  // Use RISC-V cycle counter
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

// Include the generated header with data arrays
#include "partition_data.h"

int main() {
  int partition_num = 8;  // As used in ROCC instruction
  // --- Data is included via partition_data.h ---

  printf("main() started - Using embedded data\n");
  printf("  Cache Line Size: 0x%lx bytes\n", cache_line_data_size);
  printf("  Tuple Length Size: 0x%lx bytes\n", tuple_length_data_size);
  printf("  Key Info Size: 0x%lx bytes\n", key_info_data_size);

  // --- ROCC Instructions using embedded data ---
  ROCC_INSTRUCTION(0, 0);                   // fence
  ROCC_INSTRUCTION_S(0, partition_num, 1);  // set partition num = 64

  // Use the arrays and sizes defined in the header
  ROCC_INSTRUCTION_SS(0, cache_line_data, cache_line_data_size,
                      2);  // set cache line src
  ROCC_INSTRUCTION_SS(0, tuple_length_data, tuple_length_data_size,
                      4);  // set tuple length
  ROCC_INSTRUCTION_SS(0, key_info_data, key_info_data_size,
                      5);  // set key info

  for (int i = 0; i < 1000; i++) {
  }

  // --- Cycle Measurement Start ---
  // printf("Starting partition via ROCC...\n");
  ROCC_INSTRUCTION(0, 6);  // partition start
  unsigned long long start_cycle = get_cycles();

  // --- Wait/Check (Still important!) ---
  ROCC_INSTRUCTION(0, 0);  // Fence

  int check = -1;
  ROCC_INSTRUCTION_D(0, check, 8);
  // printf("Check value: %d\n", check);

  // --- Cycle Measurement End ---
  unsigned long long end_cycle = get_cycles();
  unsigned long long cycle_diff = end_cycle - start_cycle;
  unsigned int cycle_high = (unsigned int)(cycle_diff >> 32);
  unsigned int cycle_low = (unsigned int)(cycle_diff & 0xFFFFFFFF);

  printf("Accelerator likely finished.\n");
  // Print as two 32-bit hex values if %llx is not supported
  if (cycle_high > 0) {
    printf("ROCC Execution Cycles: 0x%x%08x\n", cycle_high, cycle_low);
  } else {
    printf("ROCC Execution Cycles: 0x%x\n", cycle_low);
  }

  // cleanup: // Label might no longer be needed if no error jumps go here
  // --- Cleanup ---
  // No memory to free for these arrays
  printf("Cleaning up (no dynamic memory to free)...\n");

  printf("main() finished\n");
  return 0;  // Return 0 assuming success
}
