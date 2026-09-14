# VEDA KAAVALAN - VEGA RISC-V Makefile
CC = riscv32-unknown-elf-gcc
OBJCOPY = riscv32-unknown-elf-objcopy
SIZE = riscv32-unknown-elf-size

CFLAGS = -O3 -march=rv32imc -mabi=ilp32 -Iinclude -Wall
LDFLAGS = -T linker_snippet.ld -nostartfiles -Wl,--gc-sections

SRCS = src/main.c \
       src/sensors/mlx90640_fixed.c \
       src/sensors/bmi088_goertzel.c \
       src/sensors/bme680.c \
       src/sensors/apds9960.c \
       src/comms/nina_ble.c \
       src/ai/cnn_int8.c

OBJS = $(SRCS:.c=.o)
TARGET = veda_firmware.elf

all: $(TARGET) size

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) -o $@ $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

size: $(TARGET)
	$(SIZE) $(TARGET)

clean:
	rm -f $(OBJS) $(TARGET)
