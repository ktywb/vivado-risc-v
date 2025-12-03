// RISC-V Performance Counter and Timing Utilities
// 基于 vivado-risc-v 配置

#ifndef RISCV_TIMING_H
#define RISCV_TIMING_H

#include <stdint.h>

// ============================================================================
// 系统配置 (基于 Makefile 和 runpa 脚本)
// ============================================================================

// Timebase 频率计算公式: ROCKET_TIMEBASE_FREQ = ROCKET_FREQ_MHZ * 10000
// 当前配置: FREQ=62.5 MHz (runpa 脚本)
#define CPU_FREQ_MHZ        62.5                    // CPU 主频 (MHz)
#define TIMEBASE_FREQ_HZ    625000                  // RTC timebase 频率 (Hz)
#define CPU_FREQ_HZ         62500000                // CPU 频率 (Hz)
#define CYCLES_PER_TICK     100                     // 每个 rdtime tick 对应的 CPU 周期数

// ============================================================================
// RISC-V CSR 读取指令
// ============================================================================

// 读取 cycle 计数器 (CPU 周期数)
static inline uint64_t rdcycle(void) {
    uint64_t cycles;
    __asm__ volatile ("rdcycle %0" : "=r"(cycles));
    return cycles;
}

// 读取 time 计数器 (实时时钟，基于 timebase 频率)
static inline uint64_t rdtime(void) {
    uint64_t time;
    __asm__ volatile ("rdtime %0" : "=r"(time));
    return time;
}

// 读取 instret 计数器 (已执行指令数)
static inline uint64_t rdinstret(void) {
    uint64_t instret;
    __asm__ volatile ("rdinstret %0" : "=r"(instret));
    return instret;
}

// ============================================================================
// 时间转换函数
// ============================================================================

// rdtime ticks 转换为秒
static inline double rdtime_to_seconds(uint64_t ticks) {
    return (double)ticks / TIMEBASE_FREQ_HZ;
}

// rdtime ticks 转换为毫秒
static inline double rdtime_to_ms(uint64_t ticks) {
    return (double)ticks * 1000.0 / TIMEBASE_FREQ_HZ;
}

// rdtime ticks 转换为微秒
static inline double rdtime_to_us(uint64_t ticks) {
    return (double)ticks * 1000000.0 / TIMEBASE_FREQ_HZ;
}

// ============================================================================
// 周期数估算函数 (基于 rdtime)
// ============================================================================

// 从 rdtime ticks 估算 CPU 周期数
static inline uint64_t rdtime_to_cycles(uint64_t ticks) {
    return ticks * CYCLES_PER_TICK;  // ticks * 100
}

// 从 rdtime ticks 估算 CPU 周期数 (精确浮点版本)
static inline double rdtime_to_cycles_precise(uint64_t ticks) {
    return (double)ticks * ((double)CPU_FREQ_HZ / (double)TIMEBASE_FREQ_HZ);
}

// ============================================================================
// 周期数转换函数
// ============================================================================

// CPU 周期数转换为秒
static inline double cycles_to_seconds(uint64_t cycles) {
    return (double)cycles / CPU_FREQ_HZ;
}

// CPU 周期数转换为毫秒
static inline double cycles_to_ms(uint64_t cycles) {
    return (double)cycles * 1000.0 / CPU_FREQ_HZ;
}

// CPU 周期数转换为微秒
static inline double cycles_to_us(uint64_t cycles) {
    return (double)cycles * 1000000.0 / CPU_FREQ_HZ;
}

// ============================================================================
// 简单的计时辅助结构
// ============================================================================

typedef struct {
    uint64_t get;
} timing_t;

// 开始计时 (使用 rdtime)
static inline timing_t timing_start(void) {
    timing_t t;
    t.get = rdtime();
    return t;
}
static inline timing_t timing_stop(void) {
    timing_t t;
    t.get = rdtime();
    return t;
}

// 获取经过的 ticks
static inline uint64_t timing_get_ticks(timing_t t) {
    return rdtime() - t.get;
}

// 获取估算的周期数
static inline uint64_t timing_get_cycles(timing_t t) {
    return rdtime_to_cycles(rdtime() - t.get);
}

// 获取经过的毫秒数
static inline double timing_get_ms(timing_t t) {
    return rdtime_to_ms(rdtime() - t.get);
}

#endif // RISCV_TIMING_H
