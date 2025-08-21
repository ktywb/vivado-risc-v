#include <stdint.h>
#include <stdlib.h>
// #include <stdio.h>
// #include <time.h>

#include "common.h"
#include "kprintf.h"
#include "timer.h"

#include "compiler.h"
#include "encoding.h"
#include "rocc.h"

#include "input800.h"
// #include "input8000.h"
// #include "input80000.h"


// #include "partition_data.h"


int main(void) {

  int partition_num = 8;
  uint8_t *input_mem = (uint8_t *)input_bin;  // Pointer to input data
  size_t input_file_size = input_bin_len;
  kprintf("new version -- : full chisel\n");

  kprintf("\n\npartition_num = %d ::: \n", partition_num);
  kprintf("main() started - Using embedded data\n");
  kprintf("  Input File Size: %ld bytes\n", input_file_size);

  ROCC_INSTRUCTION(0, 0);                                 // fence
  ROCC_INSTRUCTION_S(0, partition_num, 1);                // set partition num
  ROCC_INSTRUCTION_SS(0, input_bin, input_bin_len, 2);  // set input src info
  // ROCC_INSTRUCTION_SS(0, input_mem, input_file_size, 2);  // set input src info
  // ROCC_INSTRUCTION_SS(0, output_mem, output_file_size, 3);  // set output dst

  for (int i = 0; i < 1000; i++) {}

  ROCC_INSTRUCTION(0, 4);  // start processing
  unsigned long long start_cycle = read_mcycle();
  
  ROCC_INSTRUCTION(0, 0);  // Fence
  int check = -1;
  ROCC_INSTRUCTION_D(0, check, 6);  // check completition

  kprintf("check : %d\n", check);
  unsigned long long end_cycle = read_mcycle();
  unsigned long long cycle_diff = end_cycle - start_cycle;
  unsigned int cycle_high = (unsigned int)(cycle_diff >> 32);
  unsigned int cycle_low = (unsigned int)(cycle_diff & 0xFFFFFFFF);
  kprintf("Accelerator likely finished.\n");


  if (cycle_high > 0) {
    kprintf("ROCC Execution Cycles: 0x%x%08x\n", cycle_high, cycle_low);
  } else {
    kprintf("ROCC Execution Cycles: 0x%x\n", cycle_low);
  }

  kprintf("main() finished\n");
  return EXIT_SUCCESS;
}

/*
int main () {
    int i = 1;
    int j = 1;
    int result = -1;
    // ROCC_INSTRUCTION(0, 6);
    // while(i--){}
    // ROCC_INSTRUCTION_D(0, result, 9);
    // while(j--){}
    printf("Return one test: expected=1, actual=%d\n", result);
    return 0;
}   
*/

