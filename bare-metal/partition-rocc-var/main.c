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
// #include "fpu.h"

// #include "riscv_timing.h"

#include "compiler.h"
#include "encoding.h"
#include "rocc.h"

// #include "inputData.h" 
// #include "inputInfos.h"

// #include "VAR_U_FO_K4to8_V4to8_256_Data.h" 
// #include "VAR_U_FO_K4to8_V4to8_256_Info.h"

// #include "dataset.h"
#include "dataset_test.h"

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

// int USE_ROCC = 1;
int USE_TEST =0;




int main_ROCC(void) {
    ROCC_INSTRUCTION(0, 0);
    kprintf("");
    int total_iter = 10;
    int max_failed_count = 3;
    int partition_num = 8; //16;

    uint8_t* input_info_mem = (uint8_t*)inputInfos_bin;
    size_t input_info_file_size = inputInfos_bin_len;
    uint8_t* input_data_mem = (uint8_t*)inputData_bin;
    size_t input_data_file_size = inputData_bin_len;

    // kprintf("Dataset sizes: data=%lu, info=%lu\n", 
    //         (unsigned long)input_data_file_size, 
    //         (unsigned long)input_info_file_size);

    // Dynamically calculate safe heap start to avoid overlap with .rodata
    // Get program end address from linker
    extern char _end;
    uintptr_t program_end = (uintptr_t)&_end;
    
    // Add 16MB safety margin and align to 1MB boundary
    uintptr_t safe_heap_start = (program_end + 0x01000000 + 0xFFFFF) & ~0xFFFFF;
    uintptr_t safe_heap_start_aligned = (safe_heap_start + 0x3FFFF) & ~0x3FFFF;
    
    // kprintf("Memory boundaries:\n");
    // kprintf("  Program end (_end):     0x%lx\n", (unsigned long)program_end);
    // kprintf("  Safe heap start (1MB):  0x%lx\n", (unsigned long)safe_heap_start);
    // kprintf("  Safe heap start (256KB):0x%lx\n", (unsigned long)safe_heap_start_aligned);
    
    // Anti-aliasing offset for small datasets to avoid L2 cache set conflicts
    uintptr_t anti_aliasing_offset = 0;
    if (input_data_file_size <= 512*1024) {
        // Strategy: Offset by a prime-like value to break power-of-2 alignment
        // Use ~384KB (0x60000) which is 3*128KB, avoiding multiples of cache set stride
        // This maps to ~384KB/64B = 6144 cache lines = 3 full set cycles (3*2048)
        anti_aliasing_offset = 0x60000;  // 384KB, aligned to 64B naturally
        // kprintf("  Anti-aliasing offset:   0x%lx (384KB, for dataset <= 512KB)\n", 
        //         (unsigned long)anti_aliasing_offset);
    }
    
    size_t output_data_alloc_size = input_data_file_size * 2 + 1024*1024;
    uint8_t* output_data_mem = (uint8_t*)(safe_heap_start_aligned + anti_aliasing_offset);
    // kprintf("  output_data:        0x%lx, size: %lu MB\n", 
    //         (unsigned long)output_data_mem,
    //         (unsigned long)(output_data_alloc_size / (1024*1024)));
    size_t output_data_file_size = input_data_file_size;

    size_t output_info_alloc_size = input_info_file_size * 2 + 1024*1024;
    uint8_t* output_info_mem = (uint8_t*)(safe_heap_start_aligned + anti_aliasing_offset + output_data_alloc_size);
    // kprintf("  output_info:        0x%lx, size: %lu MB\n", 
    //         (unsigned long)output_info_mem,
    //         (unsigned long)(output_info_alloc_size / (1024*1024)));
    size_t output_info_file_size = input_info_file_size;
    
    // kprintf("  Stack (approx):         0x%lx\n", (unsigned long)&total_iter);
    
    // L2 Cache Set Analysis (1024KB L2: 8-way, 2048 sets, 64B line)
    // kprintf("\n=== L2 Cache Set Analysis ===\n");
    // kprintf("L2 Config: 1024KB, 8-way, 2048 sets, 64B line\n");
    // kprintf("Set index bits: addr[16:6] (11 bits)\n");
    
    uint32_t set_input_data  = ((uintptr_t)input_data_mem >> 6) & 0x7FF;
    uint32_t set_output_data = ((uintptr_t)output_data_mem >> 6) & 0x7FF;
    uint32_t set_input_info  = ((uintptr_t)input_info_mem >> 6) & 0x7FF;
    uint32_t set_output_info = ((uintptr_t)output_info_mem >> 6) & 0x7FF;
    
    // kprintf("Base addresses map to sets:\n");
    // kprintf("  input_data  (0x%08lx) -> set %4u (0x%03x)\n", 
    //         (unsigned long)input_data_mem, set_input_data, set_input_data);
    // kprintf("  output_data (0x%08lx) -> set %4u (0x%03x)\n", 
    //         (unsigned long)output_data_mem, set_output_data, set_output_data);
    // kprintf("  input_info  (0x%08lx) -> set %4u (0x%03x)\n", 
    //         (unsigned long)input_info_mem, set_input_info, set_input_info);
    // kprintf("  output_info (0x%08lx) -> set %4u (0x%03x)\n", 
    //         (unsigned long)output_info_mem, set_output_info, set_output_info);
    
    int set_diff_io_data = ((int)set_output_data - (int)set_input_data) & 0x7FF;
    int set_diff_io_info = ((int)set_output_info - (int)set_input_info) & 0x7FF;
    
    // kprintf("Set distance (wrapping at 2048):\n");
    // kprintf("  input/output data: %d sets\n", set_diff_io_data);
    // kprintf("  input/output info: %d sets\n", set_diff_io_info);
    
    // if (set_diff_io_data < 256 || set_diff_io_data > 1792) {
    //     kprintf("  WARNING: Data buffers too close, may cause set conflicts!\n");
    // }
    // kprintf("==============================\n\n");
    
    // kprintf("Starting benchmark loop...\n");

    int failed_count = 0;
    for(int i=0; i<total_iter;){
        int check = -1;
        long long int max_iter = 5000000;
        
        // Strong memory barrier for small datasets
        if (input_data_file_size <= 512*1024) {
            asm volatile("fence.i" ::: "memory");
            asm volatile("fence rw,rw" ::: "memory");
        }
        
        for (int j=0; j<1000; j++){}
        // int count = 0;
        ROCC_INSTRUCTION(0, 0);
        ROCC_INSTRUCTION(0, 1);                   
        ROCC_INSTRUCTION_S(0, partition_num, 5);  
        ROCC_INSTRUCTION_S(0, 9630, 20);  
        
        // ROCC_INSTRUCTION_S(0, is_variable, 10);  // set is variable
        // ROCC_INSTRUCTION_S(0, key_len_fixed, 12);  // set key len fixed
        // ROCC_INSTRUCTION_S(0, tuple_len_fixed, 11);  // set tuple len fixed
        if (is_variable) {
            ROCC_INSTRUCTION_S(0, is_variable, 10);  // set is variable
        } else {
            ROCC_INSTRUCTION_S(0, key_len_fixed, 12);    // set key len fixed
            ROCC_INSTRUCTION_S(0, tuple_len_fixed, 11);  // set tuple len fixed
        }

        ROCC_INSTRUCTION_SS(0, input_info_mem, input_info_file_size,6);  
        ROCC_INSTRUCTION_SS(0, output_info_mem, output_info_file_size,7);
        ROCC_INSTRUCTION_SS(0, input_data_mem, input_data_file_size,8);  
        ROCC_INSTRUCTION_SS(0, output_data_mem, output_data_file_size,9);
        ROCC_INSTRUCTION(0, 2);  // start processing

        uint32_t start_cycle = read_mcycle();
        
        // count = 0;
        while (check != 0) {
            ROCC_INSTRUCTION_D(0, check, 4);  // check completition
            // kprintf(".");
            max_iter --;
            // count ++;
            if (max_iter < 0) break;
        }
        // unsigned long long end_cycle = get_cycles();
        uint32_t end_cycle = read_mcycle();
        ROCC_INSTRUCTION(0, 0);
        ROCC_INSTRUCTION(0, 1);  // Fence
        if (max_iter < 0) {
            failed_count ++;
            kprintf("[%s][%d]%s:%d\n", DATASET_NAME, i, "failed", failed_count);
            // kprintf("check : %d\n", check);
            // return 1;  
            if (failed_count == max_failed_count) {
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

    // kprintf("main() finished\n");
    return 0;
}

// //! =============================================================================
// //! =============================================================================

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
    //   [[fallthrough]];
    case 2:
      k1 ^= tail[1] << 8;
    //   [[fallthrough]];
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

int main_CPU() {
    kprintf("Using CPU\n");
    
    int partition_num = 8;
    // kprintf("Running OPTIMIZED SINGLE-THREADED partition for RISC-V (3-Pass)\n\n");

    // ============================================================================
    // 加载数据
    // ============================================================================
    uint8_t* input_info_mem = (uint8_t*)inputInfos_bin;
    size_t input_info_file_size = inputInfos_bin_len;
    uint8_t* input_data_mem = (uint8_t*)inputData_bin;
    size_t input_data_file_size = inputData_bin_len;

    // 新格式: 每个tuple的info是2字节 (tuple_len 1B + key_len 1B)
    size_t num_tuples = input_info_file_size / 2;

    // Debug: 打印前几个tuple的info
    kprintf("Debug: First few tuples info:\n");
    for (int i = 0; i < 3 && i < num_tuples; i++) {
        uint8_t tlen = input_info_mem[i * 2];
        uint8_t klen = input_info_mem[i * 2 + 1];
        kprintf("  Tuple %d: tuple_len=%u, key_len=%u\n", i, tlen, klen);
    }
    kprintf("Total tuples: %lu, data_size: %lu\n", 
            (unsigned long)num_tuples, (unsigned long)input_data_file_size);

    // ============================================================================
    // 分配跟踪数组
    // ============================================================================
    uint8_t** partition_data =
        (uint8_t**)malloc(partition_num * sizeof(uint8_t*));
    uint8_t** partition_info =
        (uint8_t**)malloc(partition_num * sizeof(uint8_t*));
    size_t* partition_data_size = (size_t*)calloc(partition_num, sizeof(size_t));
    size_t* partition_info_size = (size_t*)calloc(partition_num, sizeof(size_t));

    // --- 优化: 分配用于存储预计算结果的数组 ---
    size_t* tuple_data_offsets = (size_t*)malloc(num_tuples * sizeof(size_t));
    // 假设 partition_num <= 256
    uint8_t* tuple_partition_ids = (uint8_t*)malloc(num_tuples * sizeof(uint8_t));
    // 标记无效元组
    const uint8_t INVALID_PARTITION_ID = 0xFF;

    if (!partition_data || !partition_info || !partition_data_size ||
        !partition_info_size || !tuple_data_offsets || !tuple_partition_ids) {
        kprintf("Fatal: Failed to allocate tracking/optimization memory\n");
        return 1;
    }

    size_t* partition_data_offset =
            (size_t*)calloc(partition_num, sizeof(size_t));
    size_t* partition_info_offset =
        (size_t*)calloc(partition_num, sizeof(size_t));

    

    int iter = 5;
    int extra_iter = 0;
    int total_iter = iter + extra_iter;

    for(int j=0;j<total_iter;j++){
        // 重置分区大小和偏移量追踪器
        memset(partition_data_size, 0, partition_num * sizeof(size_t));
        memset(partition_info_size, 0, partition_num * sizeof(size_t));
        memset(partition_data_offset, 0, partition_num * sizeof(size_t));
        memset(partition_info_offset, 0, partition_num * sizeof(size_t));
        
        // 如果不是第一次迭代，先释放上一次的分配
        if (j > 0) {
            for (int i = 0; i < partition_num; i++) {
                free(partition_data[i]);
                free(partition_info[i]);
            }
        }
        
        // unsigned long long start_cycle = get_cycles();
        uint32_t start_cycle = read_mcycle();
        // ============================================================================
        // Pass 0: (新) 预计算 Data Offsets
        // ============================================================================
        // kprintf("Pass 0: Building data offset index...\n");
        size_t current_data_offset = 0;
        for (size_t i = 0; i < num_tuples; i++) {
            tuple_data_offsets[i] = current_data_offset;
            // 新格式: 读取tuple_len (1字节)
            uint8_t tuple_len = input_info_mem[i * 2];
            current_data_offset += tuple_len;
        }

        // ============================================================================
        // Pass 1: (修改) 统计大小 并 保存分区ID
        // ============================================================================
        // kprintf("Pass 1: Counting sizes and saving partition IDs...\n");

        for (size_t i = 0; i < num_tuples; i++) {
            size_t info_offset = i * 2;  // 新格式: 2字节per tuple
            // --- 优化: 使用 Pass 0 的结果 ---
            size_t data_offset = tuple_data_offsets[i];

            // 读取info (新格式: tuple_len 1B + key_len 1B)
            uint8_t tuple_len = input_info_mem[info_offset];
            uint8_t key_len = input_info_mem[info_offset + 1];
            uint8_t key_offset = 0;  // 新格式: key固定在tuple开头

            // 检查数据有效性
            if (data_offset + tuple_len > input_data_file_size) {
                kprintf("Error: tuple %lu extends beyond input data\n", i);
                tuple_partition_ids[i] = INVALID_PARTITION_ID;
                continue;
            }
            if (key_len > tuple_len) {
                kprintf("Error: invalid key parameters for tuple %lu\n", i);
                tuple_partition_ids[i] = INVALID_PARTITION_ID;
                continue;
            }

            // 提取key数据 (新格式: key在tuple开头)
            const uint8_t* key_data = input_data_mem + data_offset;
            uint32_t hash = MurmurHash3(key_data, key_len, 42);
            int partition_id = hash & (partition_num - 1);

            // --- 优化: 保存分区ID ---
            tuple_partition_ids[i] = (uint8_t)partition_id;

            // 计数
            partition_data_size[partition_id] += tuple_len;
            partition_info_size[partition_id] += 2;  // 新格式: 2字节per tuple
        }

        // ============================================================================
        // 分配阶段: (无变化)
        // ============================================================================
        // kprintf("Allocation Phase:\n");
        for (int i = 0; i < partition_num; i++) {
            if (partition_data_size[i] > 0) {
                partition_data[i] = (uint8_t*)malloc(partition_data_size[i]);
                if (partition_data[i] == NULL) {
                kprintf("Fatal: malloc failed for data partition %d (size %lu)\n", i,
                        (unsigned long)partition_data_size[i]);
                exit(EXIT_FAILURE);
                }
            } else {
                partition_data[i] = NULL;
            }

            if (partition_info_size[i] > 0) {
                partition_info[i] = (uint8_t*)malloc(partition_info_size[i]);
                if (partition_info[i] == NULL) {
                kprintf("Fatal: malloc failed for info partition %d (size %lu)\n", i,
                        (unsigned long)partition_info_size[i]);
                exit(EXIT_FAILURE);
                }
            } else {
                partition_info[i] = NULL;
            }
        }

        // ============================================================================
        // Pass 2: (修改) 仅复制数据 (无哈希)
        // ============================================================================
        // kprintf("Pass 2: Copying data (scatter)...\n");

        for (size_t i = 0; i < num_tuples; i++) {
            // --- 优化: 读取预计算的分区ID ---
            int partition_id = (int)tuple_partition_ids[i];

            // --- 跳过在 Pass 1 中标记为无效的元组 ---
            if (partition_id == INVALID_PARTITION_ID) {
                continue;
            }

            // --- 优化: 读取预计算的数据偏移量 ---
            size_t data_offset = tuple_data_offsets[i];

            // 仍然需要读取 info 来获取长度
            size_t info_offset = i * 2;  // 新格式: 2字节per tuple
            uint8_t tuple_len = input_info_mem[info_offset];
            uint8_t key_len = input_info_mem[info_offset + 1];

            // --- Pass 2: 不再需要哈希或key提取 ---
            // const uint8_t* key_data = input_data_mem + data_offset + key_offset;
            // uint32_t hash = MurmurHash3(key_data, key_len, 42);
            // int partition_id = hash & (partition_num - 1);

            // 复制数据 (使用新偏移量)
            if (partition_data[partition_id] != NULL) {
                memcpy(partition_data[partition_id] + partition_data_offset[partition_id],
                    input_data_mem + data_offset, tuple_len);
                partition_data_offset[partition_id] += tuple_len;
            }

            // 复制 info (使用新偏移量, 新格式: tuple_len 1B + key_len 1B)
            if (partition_info[partition_id] != NULL) {
                partition_info[partition_id][partition_info_offset[partition_id]] = tuple_len;
                partition_info[partition_id][partition_info_offset[partition_id] + 1] = key_len;
                partition_info_offset[partition_id] += 2;  // 新格式: 2字节per tuple
            }
        }
        uint32_t end_cycle = read_mcycle();
        uint32_t cycle_diff = end_cycle - start_cycle;
        kprintf("[%s][%d-%lu]\n", DATASET_NAME, j, (unsigned long)cycle_diff);
    }
    //kprintf("Done.\n");
    return 0;
}

int main(void){
    enable_fpu();
    
    if (USE_ROCC){
        main_ROCC();
    }else{
        main_CPU();
    }
    
    /*
    for(int i = 0; i<10;i++){
        kprintf("123\n");
    }*/
}
