#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

#include "riscv_timing.h"

// #include "./dataset/inputData.h"   // Include the generated header for input data
// #include "./dataset/inputInfos.h"  // Include the generated header for input data
#include "./dataset/VAR_RO_K4to16_V4to16_T8to32_8_Data.h"
#include "./dataset/VAR_RO_K4to16_V4to16_T8to32_8_Info.h"
#include "encoding.h"
#include "rocc.h"

int main() {
    ROCC_INSTRUCTION(0, 0);  // Reset
    int partition_num = 8; //16;
    int check = -1;

    uint8_t* input_info_mem = (uint8_t*)inputInfos_bin;
    size_t input_info_file_size = inputInfos_bin_len;

    uint8_t* input_data_mem = (uint8_t*)inputData_bin;
    size_t input_data_file_size = inputData_bin_len;

    uint8_t* output_data_mem = (uint8_t*)malloc(input_data_file_size + 50);
    size_t output_data_file_size = input_data_file_size;

    uint8_t* output_info_mem = (uint8_t*)malloc(input_info_file_size + 50);
    size_t output_info_file_size = input_info_file_size;

    printf("Input Info Size: %zu bytes\n", input_info_file_size);
    printf("Input Data Size: %zu bytes\n", input_data_file_size);
    printf("Start\n");

    // ROCC Instructions
    ROCC_INSTRUCTION(0, 1);                   // fence
    ROCC_INSTRUCTION_S(0, partition_num, 5);  // set partition num
    ROCC_INSTRUCTION_SS(0, inputInfos_bin,  inputInfos_bin_len, 6);  // set input src info
    ROCC_INSTRUCTION_SS(0, output_data_mem, output_data_file_size, 7);  // set output dst info
    ROCC_INSTRUCTION_SS(0, inputData_bin,  inputData_bin_len, 8);  // set input dst info
    ROCC_INSTRUCTION_SS(0, output_info_mem, output_info_file_size, 9);  // set output dst info
    timing_t start = timing_start();

    // Start processing
    ROCC_INSTRUCTION(0, 2);  // start processing

    int max_iter = 1000000;
    int count = 0;
    
    while (check != 0) {
        ROCC_INSTRUCTION_D(0, check, 4);  // check completition
        count ++;
        // printf(".");
        //max_iter --;
        //if (max_iter < 0) break;
    }
    
    
    ROCC_INSTRUCTION(0, 1);  // Fence
    // timing_t stop = timing_stop();

    uint64_t total_cycles = timing_get_cycles(start);
    
    /*
    if (max_iter < 0) {
        printf("\nfailed\n");
        printf("check : %d\n", check);
        return 1;  
    }
    */
    printf("\nfinished\n");
    printf("check : %d\n", check);
    printf("count : %d\n", count);
    double elapsed_ms = timing_get_ms(start);
    printf("Performance:\n");
    printf("  Total cycles: %lu\n", total_cycles);
    printf("  Elapsed time: %.3f ms\n", elapsed_ms);
    printf("  Throughput: %.2f MB/s\n", 
            (input_data_file_size / 1024.0 / 1024.0) / (elapsed_ms / 1000.0));
    
    int dump_output = 0;
    int max_line = 5;
    if (dump_output == 1){
            printf("\n--- Dumping Output Memory (%zu bytes) ---\n", output_data_file_size);
            for (size_t i = 0; i < output_data_file_size; i++) {
                printf("%02x ", output_data_mem[i]);
                if ((i + 1) % 16 == 0) {  
                    printf("\n");
                }
                if (max_line > 0 && (i + 1) / 16 >= max_line) {
                    printf("... (output truncated after %d lines) ...\n", max_line);
                    break;
                }
            }
            printf("\n--- End of Output Memory Dump ---\n\n");
        }

    return 0;
}
