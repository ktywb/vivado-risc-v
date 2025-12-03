#include <stdint.h>
#include <stdlib.h>
#include "common.h"
#include "kprintf.h"
#include "timer.h"

// 测试配置
#define MAX_TEST_SIZE (128 * 1024 * 1024)  // 最大128MB
#define ITERATIONS 10            // 重复测试次数
#define WARMUP_ITERATIONS 2      // 预热次数
#define CPU_FREQ_MHZ 62.5        // CPU频率 62.5MHz

// 测试不同大小以观察cache效应
static const size_t test_sizes[] = {
    16 * 1024,        // 16KB - L1 cache内
    256 * 1024,       // 256KB - L1和L2之间
    1024 * 1024,      // 1MB - L2 cache大小
    4 * 1024 * 1024,  // 4MB - 超出L2
    16 * 1024 * 1024, // 16MB
    64 * 1024 * 1024  // 64MB - 大内存
};
#define NUM_TEST_SIZES (sizeof(test_sizes) / sizeof(test_sizes[0]))

// 使用volatile防止编译器优化
volatile uint64_t dummy_sum = 0;

// 计算中位数(更可靠)
uint32_t median_cycles(uint32_t* cycles, int n) {
    // 简单冒泡排序
    for (int i = 0; i < n-1; i++) {
        for (int j = 0; j < n-i-1; j++) {
            if (cycles[j] > cycles[j+1]) {
                uint32_t tmp = cycles[j];
                cycles[j] = cycles[j+1];
                cycles[j+1] = tmp;
            }
        }
    }
    return cycles[n/2];
}

void test_bandwidth_for_size(uint8_t* buffer, size_t test_size) {
    kprintf("\n--- Testing %lu KB ---\n", (unsigned long)(test_size / 1024));
    
    uint32_t write_cycles[ITERATIONS];
    uint32_t read_cycles[ITERATIONS];
    
    // ========== 写入测试 ==========
    kprintf("Write test:");
    
    // Warmup
    for (int iter = 0; iter < WARMUP_ITERATIONS; iter++) {
        uint64_t* buf64 = (uint64_t*)buffer;
        size_t size64 = test_size / 8;
        for (size_t i = 0; i < size64; i += 8) {
            buf64[i] = i; buf64[i+1] = i+1; buf64[i+2] = i+2; buf64[i+3] = i+3;
            buf64[i+4] = i+4; buf64[i+5] = i+5; buf64[i+6] = i+6; buf64[i+7] = i+7;
        }
    }
    
    // 正式测试
    for (int iter = 0; iter < ITERATIONS; iter++) {
        uint32_t start = read_mcycle();
        
        uint64_t* buf64 = (uint64_t*)buffer;
        size_t size64 = test_size / 8;
        for (size_t i = 0; i < size64; i += 8) {
            buf64[i] = i; buf64[i+1] = i+1; buf64[i+2] = i+2; buf64[i+3] = i+3;
            buf64[i+4] = i+4; buf64[i+5] = i+5; buf64[i+6] = i+6; buf64[i+7] = i+7;
        }
        
        uint32_t end = read_mcycle();
        write_cycles[iter] = end - start;
        
        if ((iter % 3) == 0) kprintf(".");
    }
    
    uint32_t write_cyc_med = median_cycles(write_cycles, ITERATIONS);
    double write_bw = (double)test_size / write_cyc_med;
    int write_int = (int)write_bw;
    int write_frac = (int)((write_bw - write_int) * 100);
    double write_mbps = write_bw * CPU_FREQ_MHZ * 1000000.0 / (1024.0 * 1024.0);
    int write_mbps_int = (int)write_mbps;
    
    kprintf(" %lu cyc, %d.%d B/cyc, %d MB/s\n", 
            (unsigned long)write_cyc_med, write_int, write_frac, write_mbps_int);
    
    // ========== 读取测试 ==========
    kprintf("Read test: ");
    
    // Warmup
    for (int iter = 0; iter < WARMUP_ITERATIONS; iter++) {
        uint64_t sum = 0;
        uint64_t* buf64 = (uint64_t*)buffer;
        size_t size64 = test_size / 8;
        for (size_t i = 0; i < size64; i += 8) {
            sum += buf64[i] + buf64[i+1] + buf64[i+2] + buf64[i+3];
            sum += buf64[i+4] + buf64[i+5] + buf64[i+6] + buf64[i+7];
        }
        dummy_sum = sum;
    }
    
    // 正式测试
    for (int iter = 0; iter < ITERATIONS; iter++) {
        uint64_t sum = 0;
        uint32_t start = read_mcycle();
        
        uint64_t* buf64 = (uint64_t*)buffer;
        size_t size64 = test_size / 8;
        for (size_t i = 0; i < size64; i += 8) {
            sum += buf64[i] + buf64[i+1] + buf64[i+2] + buf64[i+3];
            sum += buf64[i+4] + buf64[i+5] + buf64[i+6] + buf64[i+7];
        }
        
        uint32_t end = read_mcycle();
        read_cycles[iter] = end - start;
        dummy_sum = sum;
        
        if ((iter % 3) == 0) kprintf(".");
    }
    
    uint32_t read_cyc_med = median_cycles(read_cycles, ITERATIONS);
    double read_bw = (double)test_size / read_cyc_med;
    int read_int = (int)read_bw;
    int read_frac = (int)((read_bw - read_int) * 100);
    double read_mbps = read_bw * CPU_FREQ_MHZ * 1000000.0 / (1024.0 * 1024.0);
    int read_mbps_int = (int)read_mbps;
    
    kprintf(" %lu cyc, %d.%d B/cyc, %d MB/s\n", 
            (unsigned long)read_cyc_med, read_int, read_frac, read_mbps_int);
}

int main(void) {
    enable_fpu();
    kprintf("=== Memory Bandwidth Test ===\n");
    kprintf("CPU Frequency: 62.5 MHz\n");
    kprintf("L2 Cache: 1024 KB\n");
    kprintf("System Bus: 256-bit (32 bytes/cycle theoretical max)\n\n");
    
    // 分配最大测试数组
    uint8_t* buffer = (uint8_t*)malloc(MAX_TEST_SIZE);
    if (buffer == NULL) {
        kprintf("ERROR: Failed to allocate %d MB\n", MAX_TEST_SIZE / (1024*1024));
        return 1;
    }
    
    kprintf("Buffer allocated at: 0x%lx\n", (unsigned long)buffer);
    
    // 测试不同大小
    for (int i = 0; i < NUM_TEST_SIZES; i++) {
        test_bandwidth_for_size(buffer, test_sizes[i]);
    }
    
    
    free(buffer);
    kprintf("\nTest completed.\n");
    
    return 0;
}
