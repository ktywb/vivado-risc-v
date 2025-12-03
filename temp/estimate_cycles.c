#include <stdio.h>
#include <stdint.h>

// RISC-V rdtime CSR
static inline uint64_t rdtime(void) {
    uint64_t time;
    __asm__ volatile ("rdtime %0" : "=r"(time));
    return time;
}

// 系统配置 (从测试得出)
#define TIMEBASE_FREQ_HZ    625000      // 625 kHz (= ROCKET_FREQ_MHZ * 10000)
#define CPU_FREQ_HZ         62500000    // 62.5 MHz (当前runpa中FREQ=62.5)
#define CYCLES_PER_TICK     (CPU_FREQ_HZ / TIMEBASE_FREQ_HZ)  // = 100

int main() {
    printf("=== Cycle Estimation using rdtime ===\n");
    printf("Timebase Frequency: %u Hz (625 kHz)\n", TIMEBASE_FREQ_HZ);
    printf("CPU Frequency:      %u Hz (50 MHz)\n", CPU_FREQ_HZ);
    printf("Cycles per tick:    %u\n\n", CYCLES_PER_TICK);
    
    // 测试1: 简单循环
    printf("Test 1: Simple loop\n");
    uint64_t time_start = rdtime();
    
    volatile long sum = 0;
    for (int i = 0; i < 1000000; i++) {
        sum += i;
    }
    
    uint64_t time_end = rdtime();
    uint64_t time_delta = time_end - time_start;
    
    // 计算实际时间
    double elapsed_ms = (double)time_delta * 1000.0 / TIMEBASE_FREQ_HZ;
    
    // 估算周期数
    uint64_t estimated_cycles = time_delta * CYCLES_PER_TICK;
    
    printf("  rdtime delta:        %lu ticks\n", time_delta);
    printf("  Elapsed time:        %.3f ms\n", elapsed_ms);
    printf("  Estimated cycles:    %lu\n", estimated_cycles);
    printf("  Cycles per iteration: %.2f\n\n", (double)estimated_cycles / 1000000.0);
    
    // 测试2: 延迟估算
    printf("Test 2: Delay measurement\n");
    time_start = rdtime();
    
    // 模拟一些操作
    for (volatile int i = 0; i < 10000; i++);
    
    time_end = rdtime();
    time_delta = time_end - time_start;
    
    elapsed_ms = (double)time_delta * 1000.0 / TIMEBASE_FREQ_HZ;
    estimated_cycles = time_delta * CYCLES_PER_TICK;
    
    printf("  rdtime delta:     %lu ticks\n", time_delta);
    printf("  Elapsed time:     %.3f ms\n", elapsed_ms);
    printf("  Estimated cycles: %lu\n\n", estimated_cycles);
    
    // 测试3: 不同CPU频率下的估算
    printf("Test 3: Cycle estimation at different CPU frequencies\n");
    uint64_t sample_time_delta = 625000;  // 1秒的rdtime ticks
    
    printf("  If rdtime delta = %lu (1 second):\n", sample_time_delta);
    printf("    At 25 MHz:  %lu cycles\n", sample_time_delta * 40);
    printf("    At 50 MHz:  %lu cycles\n", sample_time_delta * 80);
    printf("    At 100 MHz: %lu cycles\n", sample_time_delta * 160);
    printf("    At 200 MHz: %lu cycles\n\n", sample_time_delta * 320);
    
    // 实用函数示例
    printf("=== Utility Functions ===\n\n");
    printf("// Convert rdtime to milliseconds\n");
    printf("double rdtime_to_ms(uint64_t ticks) {\n");
    printf("    return (double)ticks * 1000.0 / %u;\n", TIMEBASE_FREQ_HZ);
    printf("}\n\n");
    
    printf("// Estimate cycles from rdtime\n");
    printf("uint64_t rdtime_to_cycles(uint64_t ticks) {\n");
    printf("    return ticks * %u;  // multiply by %d\n", CYCLES_PER_TICK, CYCLES_PER_TICK);
    printf("}\n\n");
    
    printf("// Example usage:\n");
    printf("uint64_t t1 = rdtime();\n");
    printf("// ... your code ...\n");
    printf("uint64_t t2 = rdtime();\n");
    printf("uint64_t cycles = rdtime_to_cycles(t2 - t1);\n");
    printf("double ms = rdtime_to_ms(t2 - t1);\n");
    
    return 0;
}
