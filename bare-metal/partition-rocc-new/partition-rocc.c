#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

#include "input8000.h"  // Include the generated header for input data
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

int main() {
  int partition_num = 8;

  // --- load the data from headers ---
  uint8_t *input_mem = (uint8_t *)input_bin;  // Pointer to input data
  size_t input_file_size = input_bin_len;

  // --- log info ---
  printf("main() started - Using embedded data\n");
  printf("  Input File Size: %ld bytes\n", input_file_size);

  // --- ROCC Instructions ---
  ROCC_INSTRUCTION(0, 0);                                 // fence
  ROCC_INSTRUCTION_S(0, partition_num, 1);                // set partition num
  ROCC_INSTRUCTION_SS(0, input_mem, input_file_size, 2);  // set input src info
  // ROCC_INSTRUCTION_SS(0, output_mem, output_file_size, 3);  // set output dst
  // info

  ROCC_INSTRUCTION(0, 4);  // start processing
  unsigned long long start_cycle = get_cycles();
  for (int i = 0; i < 1000; i++) {
  }
  ROCC_INSTRUCTION(0, 0);  // Fence
  int check = -1;
  ROCC_INSTRUCTION_D(0, check, 6);  // check completition

  printf("check : %d\n", check);
  
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

  printf("main() finished\n");
  return EXIT_SUCCESS;
}