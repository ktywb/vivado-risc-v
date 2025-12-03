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

#include "dataset.h"
// #include "input800.h"
// #include "input8000.h"
// #include "input80000.h"


// #include "partition_data.h"


int main(void) {
    ROCC_INSTRUCTION(0, 0);

    int partition_num = 32;
    int total_iter = 10;

    // --- load the data from headers ---
    uint8_t *input_mem = (uint8_t *)input_bin;  // Pointer to input data
    size_t input_file_size = input_bin_len;

    extern char _end;
    uintptr_t program_end = (uintptr_t)&_end;
    uintptr_t safe_heap_start = (program_end + 0x01000000 + 0xFFFFF) & ~0xFFFFF;
    uintptr_t safe_heap_start_aligned = (safe_heap_start + 0x3FFFF) & ~0x3FFFF;
    uintptr_t anti_aliasing_offset = 0;
    if (input_file_size <= 512*1024) {
        anti_aliasing_offset = 0x60000;  // 384KB, aligned to 64B naturally
        kprintf("  Anti-aliasing offset:   0x%lx (384KB, for dataset <= 512KB)\n", 
                (unsigned long)anti_aliasing_offset);
    }

    size_t output_data_alloc_size = input_file_size * 2 + 1024*1024;
    uint8_t *output_mem = (uint8_t*)(safe_heap_start_aligned + anti_aliasing_offset);
    size_t output_file_size = input_file_size;

    kprintf("main() started - Using embedded data\n");
    int failed_count = 0;
    for(int i=0; i<total_iter;){
        int check = -1;
        long long int max_iter = 5000000;
        
        asm volatile("fence.i" ::: "memory");
        asm volatile("fence rw,rw" ::: "memory");

        for (int j=0; j<1000; j++){}
        ROCC_INSTRUCTION(0, 1);                                 
        ROCC_INSTRUCTION_S(0, partition_num, 5);                
        ROCC_INSTRUCTION_SS(0, input_mem, input_file_size, 6);  
        ROCC_INSTRUCTION_SS(0, output_mem, output_file_size, 7);
        ROCC_INSTRUCTION(0, 2);  // start processing
        uint32_t start_cycle = read_mcycle();
        while ((check & 1) != 0) {
            ROCC_INSTRUCTION_D(0, check, 4);
            max_iter --;
            if (max_iter < 0) break;
        }
        uint32_t end_cycle = read_mcycle();
        ROCC_INSTRUCTION(0, 0);
        ROCC_INSTRUCTION(0, 1);  // Fence
        if (max_iter < 0) {
            failed_count ++;
            kprintf("[%s][%d]%s:%d\n", DATASET_NAME, i, "failed", failed_count);
            // kprintf("check : %d\n", check);
            // return 1;  
            if (failed_count == 5) {
                i++;
                failed_count = 0;
            }
            usleep_cycles(1000);
        }else{
            failed_count = 0;
            uint32_t cycle_diff = end_cycle - start_cycle;
            kprintf("[%s][%d-%lu]\n", DATASET_NAME, i, (unsigned long)cycle_diff);
            i++;
        }
    }

    kprintf("main() finished\n");
    return EXIT_SUCCESS;
}

