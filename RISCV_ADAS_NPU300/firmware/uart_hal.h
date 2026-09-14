// =============================================================================
// File:    uart_hal.h
// Project: RISCV_ADAS_NPU300
// Author:  TinyNPU ADAS Firmware
//
// Description:
//   Lightweight UART driver for debug output (e.g. TeraTerm / PuTTY).
//   Talks to the AXI UART Lite IP connected to the RISC-V via the PS7
//   AXI Peripheral bus.
//
//   Default baud rate: 115200
//   Base address: 0x42C00000 (standard Xilinx AXI UART Lite)
// =============================================================================

#ifndef UART_HAL_H
#define UART_HAL_H

#include <stdint.h>

// ============================================================================
// AXI UART Lite Register Map
// ============================================================================
#define UART_BASE           0x42C00000UL
#define UART_RX_FIFO        (UART_BASE + 0x00)  // Read data
#define UART_TX_FIFO        (UART_BASE + 0x04)  // Write data
#define UART_STATUS         (UART_BASE + 0x08)  // Status register
#define UART_CTRL           (UART_BASE + 0x0C)  // Control register

// STATUS register bits
#define UART_STATUS_RXVALID (1u << 0)   // RX FIFO has data
#define UART_STATUS_RXFULL  (1u << 1)   // RX FIFO full
#define UART_STATUS_TXEMPTY (1u << 2)   // TX FIFO empty
#define UART_STATUS_TXFULL  (1u << 3)   // TX FIFO full
#define UART_STATUS_IE      (1u << 4)   // Interrupt enabled
#define UART_STATUS_OE      (1u << 5)   // Overrun error

// ============================================================================
// UART Driver Functions
// ============================================================================

static inline void uart_putchar(char c) {
    // Wait until TX FIFO has space
    while (*(volatile uint32_t*)UART_STATUS & UART_STATUS_TXFULL);
    *(volatile uint32_t*)UART_TX_FIFO = (uint32_t)c;
}

static inline void uart_print(const char* s) {
    while (*s) uart_putchar(*s++);
}

static inline void uart_println(const char* s) {
    uart_print(s);
    uart_putchar('\r');
    uart_putchar('\n');
}

static inline void uart_print_hex(uint32_t val) {
    uart_print("0x");
    for (int i = 28; i >= 0; i -= 4) {
        uint8_t nibble = (val >> i) & 0xF;
        uart_putchar(nibble < 10 ? '0' + nibble : 'A' + nibble - 10);
    }
}

static inline void uart_print_int(int32_t val) {
    if (val < 0) { uart_putchar('-'); val = -val; }
    char buf[12];
    int  i = 0;
    if (val == 0) { uart_putchar('0'); return; }
    while (val > 0) { buf[i++] = '0' + (val % 10); val /= 10; }
    while (i > 0) uart_putchar(buf[--i]);
}

static inline void uart_print_uint(uint32_t val) {
    char buf[12];
    int  i = 0;
    if (val == 0) { uart_putchar('0'); return; }
    while (val > 0) { buf[i++] = '0' + (val % 10); val /= 10; }
    while (i > 0) uart_putchar(buf[--i]);
}

#endif // UART_HAL_H
