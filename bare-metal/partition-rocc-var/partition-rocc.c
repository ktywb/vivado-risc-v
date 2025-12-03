#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

#include "inputData.h"   // Include the generated header for input data
#include "inputInfos.h"  // Include the generated header for input data
#include "encoding.h"
#include "rocc.h"

// ============================================================================
// Helper function to get cycles/time
// ============================================================================
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
  //   ROCC_INSTRUCTION(0, 0);  // Reset
  int partition_num = 16;

  // ============================================================================
  // Load the data from headers
  // ============================================================================
  uint8_t* input_info_mem = (uint8_t*)inputInfos_bin;
  size_t input_info_file_size = inputInfos_bin_len;

  uint8_t* input_data_mem = (uint8_t*)inputData_bin;
  size_t input_data_file_size = inputData_bin_len;

  // ============================================================================
  // Result mem
  // ============================================================================
  uint8_t* output_data_mem = (uint8_t*)malloc(input_data_file_size + 50);
  size_t output_data_file_size = input_data_file_size;

  uint8_t* output_info_mem = (uint8_t*)malloc(input_info_file_size + 50);
  size_t output_info_file_size = input_info_file_size;

  printf("Input Info Size: %zu bytes\n", input_info_file_size);
  printf("Input Data Size: %zu bytes\n", input_data_file_size);
  printf("Output Info Size: %zu bytes\n", output_info_file_size);
  printf("Output Data Size: %zu bytes\n", output_data_file_size);

  // ============================================================================
  // ROCC Instructions
  // ============================================================================
  ROCC_INSTRUCTION(0, 1);                   // fence
  ROCC_INSTRUCTION_S(0, partition_num, 5);  // set partition num
  ROCC_INSTRUCTION_SS(0, input_info_mem, input_info_file_size,
                      6);  // set input src info
  ROCC_INSTRUCTION_SS(0, output_data_mem, output_data_file_size,
                      7);  // set output dst info
  ROCC_INSTRUCTION_SS(0, input_data_mem, input_data_file_size,
                      8);  // set input dst info
  ROCC_INSTRUCTION_SS(0, output_info_mem, output_info_file_size,
                      9);  // set output dst info

  // ============================================================================
  // Start processing
  // ============================================================================
  ROCC_INSTRUCTION(0, 2);  // start processing
  unsigned long long start_cycle = get_cycles();
  int check = -1;
  while (check != 0) {
    ROCC_INSTRUCTION_D(0, check, 4);  // check completition
  }
  ROCC_INSTRUCTION(0, 1);  // Fence
  // ============================================================================
  // Cycle Measurement End
  // ============================================================================
  unsigned long long end_cycle = get_cycles();
  unsigned long long cycle_diff = end_cycle - start_cycle;
  unsigned int cycle_high = (unsigned int)(cycle_diff >> 32);
  unsigned int cycle_low = (unsigned int)(cycle_diff & 0xFFFFFFFF);
  // Print as two 32-bit hex values if %llx is not supported
  if (cycle_high > 0) {
    printf("ROCC Execution Cycles: 0x%x%08x\n", cycle_high, cycle_low);
  } else {
    printf("ROCC Execution Cycles: 0x%x\n", cycle_low);
  }
  return 0;
}