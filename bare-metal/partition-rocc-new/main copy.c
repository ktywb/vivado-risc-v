#include <stdint.h>
#include <stdlib.h>
#include <string.h>
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
  ROCC_INSTRUCTION(0, 0);

  int partition_num = 8;

  // --- load the data from headers ---
  uint8_t *input_mem = (uint8_t *)input_bin;  // Pointer to input data
  size_t input_file_size = input_bin_len;

  // --- result mem ---
  uint8_t *output_mem = (uint8_t *)malloc(input_bin_len + 50);
  memset(output_mem, 1, input_bin_len + 50);  // Clear the allocated memory
  size_t output_file_size = input_file_size;

  unsigned long long int temp=0;
  kprintf("%d\n", temp);
  for (size_t i = 0; i < output_file_size; i++){
    temp = temp + input_bin[i];
  }
  kprintf("%d\n", temp);

  kprintf("new version --- : full chisel\n");

  kprintf("main() started - Using embedded data\n");
  kprintf("  Input File Size: %ld bytes\n", input_file_size);

  ROCC_INSTRUCTION(0, 1);                                 // fence
  ROCC_INSTRUCTION_S(0, partition_num, 5);                // set partition num
  ROCC_INSTRUCTION_SS(0, input_mem, input_file_size, 6);         // ROCC_INSTRUCTION_SS(0, input_mem, input_file_size, 6); // set input src info addr：80001fe0      // ROCC_INSTRUCTION_SS(0, input_mem, input_file_size, 6); // set input src info addr：80001fe0
  ROCC_INSTRUCTION_SS(0, output_mem, output_file_size, 7);  // set output dst
  // info

  ROCC_INSTRUCTION(0, 2);  // start processing
  
  int check = -1;
  while ((check & 1) != 0) {
    ROCC_INSTRUCTION_D(0, check, 4);  // check completition
    kprintf(".");
  }
  ROCC_INSTRUCTION(0, 1);  // Fence

  kprintf("check : %d\n", check/2);
  kprintf("Accelerator likely finished.\n");

  // kprintf("\n--- Dumping Output Memory (%zu bytes) ---\n", output_file_size);
  // for (size_t i = 0; i < output_file_size; i++) {
  //   kprintf("%x \n", output_mem[i]);
  //   // if ((i + 1) % 16 == 0) {  kprintf("\n"); }
  // }
  // kprintf("\n--- End of Output Memory Dump ---\n\n");

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

