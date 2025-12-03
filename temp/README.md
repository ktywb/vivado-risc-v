# RISC-V 64-bit Linux 程序编译指南

## 目录结构
```
temp/
├── Makefile        # 编译配置文件
├── main.c          # 示例C程序
└── README.md       # 本文件
```

## 快速开始

### 1. 编译程序
```bash
cd /home/name/vivado_prj/vivado-risc-v/temp
make
```

### 2. 检查生成的二进制文件
```bash
make check
```

### 3. 部署到FPGA（需要网络连接）
```bash
# 修改Makefile中的FPGA_IP和FPGA_USER
make deploy
```

### 4. 清理编译产物
```bash
make clean
```

## 工具链说明

- **编译器**: `riscv64-linux-gnu-gcc`
- **架构**: `rv64gc` (RV64IMAFD_Zicsr_Zifencei)
- **ABI**: `lp64d` (64位指针，double浮点)

## Makefile变量

可以通过命令行覆盖变量：

```bash
# 自定义目标名称
make TARGET=my_program

# 自定义编译器
make CROSS_COMPILE=riscv64-unknown-linux-gnu-

# 添加额外的编译选项
make CFLAGS="-Wall -O3 -g"

# 指定FPGA IP地址
make deploy FPGA_IP=192.168.1.100
```

## 示例程序说明

`main.c` 包含：
- 基本的Hello World输出
- RISC-V性能计数器测试（rdcycle, rdtime, rdinstret）
- 简单的计算循环

## 添加更多源文件

在Makefile中修改 `SRCS` 变量：

```makefile
SRCS = main.c utils.c module1.c
```

## 静态链接

如果需要静态链接（FPGA上可能缺少动态库）：

```bash
make LDFLAGS="-static"
```

## 调试版本

编译带调试信息的版本：

```bash
make CFLAGS="-Wall -O0 -g"
```

## 性能计数器支持

如果在FPGA上运行时性能计数器不工作，需要：

1. 确保已启用用户态访问：
```bash
echo 2 | sudo tee /proc/sys/kernel/perf_user_access
```

2. 检查内核是否支持：
```bash
dmesg | grep -i pmu
```

## 交叉编译其他类型的程序

### C++程序
```makefile
SRCS = main.cpp utils.cpp
OBJS = $(SRCS:.cpp=.o)

$(TARGET): $(OBJS)
	$(CXX) $(LDFLAGS) -o $@ $^

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<
```

### 汇编程序
```makefile
SRCS = main.S
OBJS = $(SRCS:.S=.o)

%.o: %.S
	$(CC) $(CFLAGS) -c -o $@ $<
```
