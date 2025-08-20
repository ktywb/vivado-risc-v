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

#include "partition_data_tiny.h"
// #include "partition_data_small.h"
// #include "partition_data_medium.h"
// #include "partition_data_full.h"

// #include "partition_data.h"


int main(void) {
  // kprintf("\nRun after ");
  // int t;
  // for (t=5;t>0;t--) {
  //   kprintf("%d  ", t);
  //     usleep(1000000);
  // }kprintf("\n");

  int partition_num = 8;
  kprintf("\n\npartition_num = %d ::: \n", partition_num);
  kprintf("main() started - Using embedded data\n");
  kprintf("  Cache Line   Size: 0x%lx bytes\n", cache_line_data_size);
  kprintf("  Tuple Length Size: 0x%lx bytes\n", tuple_length_data_size);
  kprintf("  Key   Info   Size: 0x%lx bytes\n", key_info_data_size);

  // int i = 1, j = 1;
  // int result = -1;
  // unsigned long long start_cycle = read_mcycle();
  // ROCC_INSTRUCTION(0, 0);
  // ROCC_INSTRUCTION(0, 6);
  // while(i--){}
  // ROCC_INSTRUCTION_D(0, result, 9);
  // while(j--){}
  // kprintf("Return one test: expected=1, actual=%d\n", result);

  // int repeat_fence = 10;
  // for (int i=0; i < repeat_fence; i++){
  //   ROCC_INSTRUCTION(0, 0);                   // fence
  //   for (int j = 0; j < 100; j++) {}
  // }

  ROCC_INSTRUCTION(0, 0);         
  for (int j = 0; j < 100; j++) {}
  ROCC_INSTRUCTION(0, 0);         
  for (int j = 0; j < 100; j++) {}
  ROCC_INSTRUCTION(0, 0);         
  for (int j = 0; j < 100; j++) {}

  
  ROCC_INSTRUCTION(0, 0); // fence
  ROCC_INSTRUCTION_S (0, partition_num, 1);  
  ROCC_INSTRUCTION_SS(0, cache_line_data, cache_line_data_size, 2); 
  ROCC_INSTRUCTION_SS(0, tuple_length_data, tuple_length_data_size, 4); 
  for (int i = 0; i < 1000; i++){}
  ROCC_INSTRUCTION_SS(0, key_info_data, key_info_data_size, 5); 
  
  
  ROCC_INSTRUCTION(0, 6); 
  unsigned long long start_cycle = read_mcycle();
  
  ROCC_INSTRUCTION(0, 0); 
  int check = -1;
  ROCC_INSTRUCTION_D(0, check, 8);

  unsigned long long end_cycle = read_mcycle();

  // unsigned long long start_cycle_ = read_mcycle();
  // for (int i = 0; i < 1000; i++){}
  // unsigned long long end_cycle_ = read_mcycle();
  // unsigned long long cycle_diff_ = end_cycle_ - start_cycle_;

  unsigned long long cycle_diff = end_cycle - start_cycle ;
  unsigned int cycle_high = (unsigned int)(cycle_diff >> 32);
  unsigned int cycle_low = (unsigned int)(cycle_diff & 0xFFFFFFFF);

  
  
  if (cycle_high > 0) {
    kprintf("ROCC Execution Cycles : 0x%x%08x\n", cycle_high, cycle_low);
  } else {
    kprintf("ROCC Execution Cycles-: 0x%x\n", cycle_low);
  }




  kprintf("Cleaning up (no dynamic memory to free)...\n");
  kprintf("main() finished\n");
  kprintf("Finish \n");
  return 0;
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

