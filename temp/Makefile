# RISC-V 64-bit Linux Cross-Compilation Makefile

# Cross-compiler toolchain
CROSS_COMPILE ?= riscv64-linux-gnu-
CC = $(CROSS_COMPILE)gcc
CXX = $(CROSS_COMPILE)g++
AR = $(CROSS_COMPILE)ar
LD = $(CROSS_COMPILE)ld

# Compiler flags
CFLAGS = -Wall -O2 -march=rv64gc -mabi=lp64d
CXXFLAGS = -Wall -O2 -march=rv64gc -mabi=lp64d
LDFLAGS =

# Target binary name
TARGET = partition-rocc

# Source files
SRCS = partition-rocc.c
OBJS = $(SRCS:.c=.o)

# Default target
all: $(TARGET)

# Link object files to create executable
$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^
	@echo "Built RISC-V binary: $(TARGET)"

# Compile C source files
%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

# Clean build artifacts
clean:
	rm -f $(TARGET) $(OBJS)

# Check binary architecture
check:
	file $(TARGET)
	$(CROSS_COMPILE)readelf -h $(TARGET) | grep Machine

# Deploy to FPGA (modify IP address as needed)
FPGA_IP ?= 192.168.2.3
FPGA_USER ?= root
deploy:
	scp $(TARGET) $(FPGA_USER)@$(FPGA_IP):/root/

.PHONY: all clean check deploy
