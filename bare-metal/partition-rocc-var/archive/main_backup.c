// Backup of original main.c
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
// #include <unistd.h>  // 注释掉,与 timer.h 中的 usleep 冲突
// #include <stdio.h>
// #include <time.h>
#include <assert.h>
#include <stddef.h>

#include "common.h"
#include "kprintf.h"
#include "timer.h"

// #include "riscv_timing.h"

#include "compiler.h"
#include "encoding.h"
#include "rocc.h"

// #include "inputData.h" 
// #include "inputInfos.h"

// #include "VAR_U_FO_K4to8_V4to8_256_Data.h" 
// #include "VAR_U_FO_K4to8_V4to8_256_Info.h"

#include "dataset.h"

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

// int main(void) {
//     ROCC_INSTRUCTION(0, 0);
//     kprintf("");
//     int total_iter = 10;
//     int partition_num = 8; //16;

//     uint8_t* input_info_mem = (uint8_t*)inputInfos_bin;
//     size_t input_info_file_size = inputInfos_bin_len;
//     uint8_t* input_data_mem = (uint8_t*)inputData_bin;
//     size_t input_data_file_size = inputData_bin_len;

//     kprintf("Dataset sizes: data=%lu, info=%lu\n", 
//             (unsigned long)input_data_file_size, 
//             (unsigned long)input_info_file_size);

//     // Dynamically calculate safe heap start to avoid overlap with .rodata
//     // Get program end address from linker
//     extern char _end;
//     uintptr_t program_end = (uintptr_t)&_end;
    
//     // Add 16MB safety margin and align to 1MB boundary
//     uintptr_t safe_heap_start = (program_end + 0x01000000 + 0xFFFFF) & ~0xFFFFF;
    
//     kprintf("Memory boundaries:\n");
//     kprintf("  Program end (_end): 0x%lx\n", (unsigned long)program_end);
//     kprintf("  Safe heap start:    0x%lx\n", (unsigned long)safe_heap_start);
    
//     size_t output_data_alloc_size = input_data_file_size * 2 + 1024*1024;
//     uint8_t* output_data_mem = (uint8_t*)safe_heap_start;
//     kprintf("  output_data:        0x%lx, size: %lu MB\n", 
//             (unsigned long)output_data_mem,
//             (unsigned long)(output_data_alloc_size / (1024*1024)));
//     size_t output_data_file_size = input_data_file_size;

//     size_t output_info_alloc_size = input_info_file_size * 2 + 1024*1024;
//     uint8_t* output_info_mem = (uint8_t*)(safe_heap_start + output_data_alloc_size);
//     kprintf("  output_info:        0x%lx, size: %lu MB\n", 
//             (unsigned long)output_info_mem,
//             (unsigned long)(output_info_alloc_size / (1024*1024)));
//     size_t output_info_file_size = input_info_file_size;
    
//     kprintf("  Stack (approx):     0x%lx\n", (unsigned long)&total_iter);
//     kprintf("Starting benchmark loop...\n");

    
//     for(int i=0; i<total_iter;){
//         int check = -1;
//         long long int max_iter = 5000000;
//         // int count = 0;
//         ROCC_INSTRUCTION(0, 0);
//         ROCC_INSTRUCTION(0, 1);                   
//         ROCC_INSTRUCTION_S(0, partition_num, 5);  
//         ROCC_INSTRUCTION_SS(0, input_info_mem, input_info_file_size,6);  
//         ROCC_INSTRUCTION_SS(0, output_info_mem, output_info_file_size,7);
//         ROCC_INSTRUCTION_SS(0, input_data_mem, input_data_file_size,8);  
//         ROCC_INSTRUCTION_SS(0, output_data_mem, output_data_file_size,9);
//         ROCC_INSTRUCTION(0, 2);  // start processing

//         uint32_t start_cycle = read_mcycle();
        
//         // count = 0;
//         while (check != 0) {
//             ROCC_INSTRUCTION_D(0, check, 4);  // check completition
//             // kprintf(".");
//             max_iter --;
//             // count ++;
//             if (max_iter < 0) break;
//         }
//         // unsigned long long end_cycle = get_cycles();
//         uint32_t end_cycle = read_mcycle();
//         ROCC_INSTRUCTION(0, 0);
//         ROCC_INSTRUCTION(0, 1);  // Fence
//         if (max_iter < 0) {
//             kprintf("[%s][%d]%s\n", DATASET_NAME, i, "failed");
//             // kprintf("check : %d\n", check);
//             // return 1;  
//             usleep_cycles(2000);
//         }else{
//             uint32_t cycle_diff = end_cycle - start_cycle;
//             kprintf("[%s][%d-%lu]\n", DATASET_NAME, i, (unsigned long)cycle_diff);
//             i++;
//         }
//     }

//     // kprintf("main() finished\n");
//     return 0;
// }

//! =============================================================================
//! =============================================================================

static inline uint32_t rotl32(uint32_t x, int8_t r) {
  return (x << r) | (x >> (32 - r));
}

static inline uint32_t fmix32(uint32_t h) {
  h ^= h >> 16;
  h *= 0x85ebca6b;
  h ^= h >> 13;
  h *= 0xc2b2ae35;
  h ^= h >> 16;
  return h;
}

uint32_t MurmurHash3(const uint8_t* key, size_t len, uint32_t seed) {
  const uint8_t* data = (const uint8_t*)key;
  const int nblocks = len / 4;
  uint32_t h1 = seed;
  const uint32_t c1 = 0xcc9e2d51;
  const uint32_t c2 = 0x1b873593;

  //----------
  // body
  const uint32_t* blocks = (const uint32_t*)(data + nblocks * 4);
  for (int i = -nblocks; i; i++) {
    uint32_t k1;
    memcpy(&k1, blocks + i, sizeof(uint32_t));  // 安全的 unaligned read

    k1 *= c1;
    k1 = rotl32(k1, 15);
    k1 *= c2;

    h1 ^= k1;
    h1 = rotl32(h1, 13);
    h1 = h1 * 5 + 0xe6546b64;
  }

  //----------
  // tail
  const uint8_t* tail = (const uint8_t*)(data + nblocks * 4);
  uint32_t k1 = 0;
  switch (len & 3) {
    case 3:
      k1 ^= tail[2] << 16;
      [[fallthrough]];
    case 2:
      k1 ^= tail[1] << 8;
      [[fallthrough]];
    case 1:
      k1 ^= tail[0];
      k1 *= c1;
      k1 = rotl32(k1, 15);
      k1 *= c2;
      h1 ^= k1;
  };

  //----------
  // finalization
  h1 ^= len;
  h1 = fmix32(h1);

  return h1;
}

int main(void) {
    // 测试 kprintf 是否工作
    kprintf("=== Program Start ===\n");
    kprintf("");
    
    kprintf("Step 1: Variable initialization\n");
    int total_iter = 1;
    int partition_num = 8; //16;

    kprintf("Step 2: Getting dataset pointers\n");
    
    // 先不使用 volatile，看看是否是 volatile 导致的问题
    uint8_t* input_info_mem = (uint8_t*)inputInfos_bin;
    kprintf("  input_info_mem = 0x%lx\n", (unsigned long)input_info_mem);
    
    size_t input_info_file_size = inputInfos_bin_len;
    kprintf("  input_info_file_size = %lu\n", (unsigned long)input_info_file_size);
    
    uint8_t* input_data_mem = (uint8_t*)inputData_bin;
    kprintf("  input_data_mem = 0x%lx\n", (unsigned long)input_data_mem);
    
    size_t input_data_file_size = inputData_bin_len;
    kprintf("  input_data_file_size = %lu\n", (unsigned long)input_data_file_size);

    kprintf("Step 3: Calculating num_tuples\n");
    size_t num_tuples = input_info_file_size / 4;
    kprintf("  num_tuples = %lu\n", (unsigned long)num_tuples);

    kprintf("Step 4: Printing dataset sizes\n");
    kprintf("Dataset sizes: data=%lu, info=%lu\n", 
            (unsigned long)input_data_file_size, 
            (unsigned long)input_info_file_size);

   // === 使用 safe_heap_start (从 main() 复制) ===
    extern char _end;
    uintptr_t program_end = (uintptr_t)&_end;
    uintptr_t safe_heap_start = (program_end + 0x01000000 + 0xFFFFF) & ~0xFFFFF;
    
    // === 计算各个数组所需的大小 ===
    size_t ptr_array_size = partition_num * sizeof(uint8_t*);  // partition_data
    size_t size_array_size = partition_num * sizeof(size_t);   // partition_data_size
    size_t tuple_offsets_size = num_tuples * sizeof(size_t);   // tuple_data_offsets
    size_t tuple_ids_size = num_tuples * sizeof(uint8_t);      // tuple_partition_ids
    
    // === 逐个分配地址 (累加偏移) ===
    uintptr_t current_addr = safe_heap_start;
    
    // 1. partition_data (指针数组)
    uint8_t** partition_data = (uint8_t**)current_addr;
    current_addr += ptr_array_size;
    
    // 2. partition_info (指针数组)
    uint8_t** partition_info = (uint8_t**)current_addr;
    current_addr += ptr_array_size;
    
    // 3. partition_data_size (需要清零)
    size_t* partition_data_size = (size_t*)current_addr;
    current_addr += size_array_size;
    memset(partition_data_size, 0, size_array_size);  // calloc 等效
    
    // 4. partition_info_size (需要清零)
    size_t* partition_info_size = (size_t*)current_addr;
    current_addr += size_array_size;
    memset(partition_info_size, 0, size_array_size);  // calloc 等效
    
    // 5. tuple_data_offsets (初始化为0，虽然会在Pass 0填充，但O2优化需要)
    size_t* tuple_data_offsets = (size_t*)current_addr;
    current_addr += tuple_offsets_size;
    memset(tuple_data_offsets, 0, tuple_offsets_size);  // 防止O2优化问题
    
    // 6. tuple_partition_ids (初始化为0，虽然会在Pass 1填充，但O2优化需要)
    uint8_t* tuple_partition_ids = (uint8_t*)current_addr;
    current_addr += tuple_ids_size;
    memset(tuple_partition_ids, 0, tuple_ids_size);  // 防止O2优化问题
    
    // 7. partition_data_offset (需要清零)
    size_t* partition_data_offset = (size_t*)current_addr;
    current_addr += size_array_size;
    memset(partition_data_offset, 0, size_array_size);  // calloc 等效
    
    // 8. partition_info_offset (需要清零)
    size_t* partition_info_offset = (size_t*)current_addr;
    current_addr += size_array_size;
    memset(partition_info_offset, 0, size_array_size);  // calloc 等效
    
    // === 可选: 打印内存布局 ===
    kprintf("Main2 memory layout:\n");
    kprintf("  safe_heap_start: 0x%lx\n", (unsigned long)safe_heap_start);
    kprintf("  Total allocated: %lu bytes (%lu KB)\n", 
            (unsigned long)(current_addr - safe_heap_start),
            (unsigned long)(current_addr - safe_heap_start) / 1024);
    
    const uint8_t INVALID_PARTITION_ID = 0xFF;

    uintptr_t partition_pool_base = current_addr;
    size_t partition_pool_size = (input_data_file_size + input_info_file_size) * 2;  // 足够的池大小
    current_addr += partition_pool_size;

    kprintf("  partition_pool:     0x%lx, size: %lu MB\n",
            (unsigned long)partition_pool_base,
            (unsigned long)(partition_pool_size / (1024*1024)));
    kprintf("Starting CPU partition benchmark...\n");

    for(int i=0; i<total_iter;){
        // 重置计数器和偏移量
        memset(partition_data_size, 0, partition_num * sizeof(size_t));
        memset(partition_info_size, 0, partition_num * sizeof(size_t));
        memset(partition_data_offset, 0, partition_num * sizeof(size_t));
        memset(partition_info_offset, 0, partition_num * sizeof(size_t));

        // kprintf("Iteration %d starting...\n", i);
        
        // 内存屏障：确保memset完成
        __asm__ __volatile__("fence" ::: "memory");

        uint32_t start_cycle = read_mcycle();
        
        // ========================================================================
        // Pass 0: 预计算 Data Offsets
        // ========================================================================
        // kprintf("Pass 0: Building data offset index...\n");
        size_t current_data_offset = 0;
        for (size_t j = 0; j < num_tuples; j++) {
            tuple_data_offsets[j] = current_data_offset;
            uint8_t tuple_len = input_info_mem[j * 4];
            current_data_offset += tuple_len;
        }
        
        // 内存屏障：确保Pass 0完成
        __asm__ __volatile__("fence" ::: "memory");

        // ========================================================================
        // Pass 1: 统计大小并保存分区ID
        // ========================================================================
        // kprintf("Pass 1: Calculating partition sizes and IDs...\n");
        for (size_t j = 0; j < num_tuples; j++) {
            size_t info_offset = j * 4;
            size_t data_offset = tuple_data_offsets[j];

            // 读取info
            uint8_t tuple_len = input_info_mem[info_offset];
            uint8_t key_offset = input_info_mem[info_offset + 1];
            uint8_t key_len = input_info_mem[info_offset + 2];

            // 检查数据有效性
            if (data_offset + tuple_len > input_data_file_size) {
                kprintf("Error: tuple %lu extends beyond input data\n", j);
                tuple_partition_ids[j] = INVALID_PARTITION_ID;
                continue;
            }
            if (key_offset + key_len > tuple_len) {
                kprintf("Error: invalid key parameters for tuple %lu\n", j);
                tuple_partition_ids[j] = INVALID_PARTITION_ID;
                continue;
            }

            // 提取key并计算哈希
            const uint8_t* key_data = input_data_mem + data_offset + key_offset;
            uint32_t hash = MurmurHash3(key_data, key_len, 42);
            int partition_id = hash & (partition_num - 1);

            // 保存分区ID
            tuple_partition_ids[j] = (uint8_t)partition_id;

            // 统计大小
            partition_data_size[partition_id] += tuple_len;
            partition_info_size[partition_id] += 4;
        }

        // ========================================================================
        // 分配阶段: 从缓冲池分配
        // ========================================================================
        // kprintf("Allocation Phase:\n");
        uintptr_t partition_alloc_ptr = partition_pool_base;

        for (int p = 0; p < partition_num; p++) {
            if (partition_data_size[p] > 0) {
                partition_data[p] = (uint8_t*)partition_alloc_ptr;
                partition_alloc_ptr += partition_data_size[p];
            } else {
                partition_data[p] = NULL;
            }

            if (partition_info_size[p] > 0) {
                partition_info[p] = (uint8_t*)partition_alloc_ptr;
                partition_alloc_ptr += partition_info_size[p];
            } else {
                partition_info[p] = NULL;
            }
        }

        // 检查池大小
        if (partition_alloc_ptr > partition_pool_base + partition_pool_size) {
            kprintf("[CPU][%d] Error: partition pool overflow!\n", i);
            return 1;
        }

        // ========================================================================
        // Pass 2: 复制数据
        // ========================================================================
        // kprintf("Pass 2: Copying data...\n");
        for (size_t j = 0; j < num_tuples; j++) {
            // kprintf("Copying tuple %lu...\n", j);  // 注释掉以提升性能
            int partition_id = (int)tuple_partition_ids[j];

            // 跳过无效元组
            if (partition_id == INVALID_PARTITION_ID) {
                continue;
            }

            size_t data_offset = tuple_data_offsets[j];
            size_t info_offset = j * 4;

            uint8_t tuple_len = input_info_mem[info_offset];
            uint8_t key_offset = input_info_mem[info_offset + 1];
            uint8_t key_len = input_info_mem[info_offset + 2];
            uint8_t padding = input_info_mem[info_offset + 3];

            // 复制数据
            // kprintf("Copying data for tuple %lu...\n", j);  // 注释掉以提升性能
            if (partition_data[partition_id] != NULL) {
                memcpy(partition_data[partition_id] + partition_data_offset[partition_id],
                       input_data_mem + data_offset, tuple_len);
                partition_data_offset[partition_id] += tuple_len;
            }

            // 复制info
            // kprintf("Copying info for tuple %lu...\n", j);  // 注释掉以提升性能
            if (partition_info[partition_id] != NULL) {
                uint32_t info = tuple_len | (key_offset << 8) | (key_len << 16) | (padding << 24);
                memcpy(partition_info[partition_id] + partition_info_offset[partition_id],
                       &info, sizeof(info));
                partition_info_offset[partition_id] += 4;
            }
        }
        
        uint32_t end_cycle = read_mcycle();
        uint32_t cycle_diff = end_cycle - start_cycle;
        
        kprintf("[CPU][%s][%d-%lu]\n", DATASET_NAME, i, (unsigned long)cycle_diff);
        i++;
    }

    // kprintf("main() finished\n");
    return 0;
}

