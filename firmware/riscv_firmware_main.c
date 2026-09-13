#include <stdint.h>
#include "dummy_data.h" // The 1-valued weights we generated earlier

// ============================================================================
// MEMORY MAP & HARDWARE REGISTERS (Pure PL Architecture)
// ============================================================================

// NPU Control & Status Registers (AXI-Lite Slave)
#define NPU_CSR_BASE       0x40000000
#define NPU_REG_START      (NPU_CSR_BASE + 0x00) // Write 1 to start NPU
#define NPU_REG_STATUS     (NPU_CSR_BASE + 0x04) // Read bit 0 for Busy
#define NPU_REG_CFG        (NPU_CSR_BASE + 0x08) // Config (e.g., Activation type)
#define NPU_REG_M0_BASE    (NPU_CSR_BASE + 0x50) // Requantization Multipliers
#define NPU_REG_SHIFT_BASE (NPU_CSR_BASE + 0x60) // Requantization Shifts

// AXI DMA Engine (Assumed standard Xilinx AXI DMA offset)
#define AXI_DMA_BASE       0x41E00000
#define DMA_MM2S_DMACR     (AXI_DMA_BASE + 0x00) // TX Control
#define DMA_MM2S_SA        (AXI_DMA_BASE + 0x18) // TX Source Address
#define DMA_MM2S_LENGTH    (AXI_DMA_BASE + 0x28) // TX Transfer Length (Bytes)

#define DMA_S2MM_DMACR     (AXI_DMA_BASE + 0x30) // RX Control
#define DMA_S2MM_DA        (AXI_DMA_BASE + 0x48) // RX Destination Address
#define DMA_S2MM_LENGTH    (AXI_DMA_BASE + 0x58) // RX Transfer Length (Bytes)

// UART Terminal (For printing to TeraTerm)
#define UART_BASE          0x42C00000
#define UART_TX_DATA       (UART_BASE + 0x04)
#define UART_STATUS        (UART_BASE + 0x08)

// Output Buffer for NPU Results
int8_t npu_output_buffer[4096] __attribute__((aligned(32)));

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

// Print a single character to the serial monitor
void uart_print_char(char c) {
    // Wait until TX FIFO is not full
    while ((*(volatile uint32_t*)UART_STATUS) & 0x08);
    *(volatile uint32_t*)UART_TX_DATA = c;
}

// Print a string to the serial monitor
void uart_print(const char* str) {
    while (*str) {
        uart_print_char(*str++);
    }
}

// Convert integer to string and print (for the NPU results)
void uart_print_int(int val) {
    char buffer[16];
    int i = 0;
    if (val == 0) {
        uart_print("0");
        return;
    }
    while (val > 0) {
        buffer[i++] = (val % 10) + '0';
        val /= 10;
    }
    while (i > 0) {
        uart_print_char(buffer[--i]);
    }
}

// ============================================================================
// MAIN FIRMWARE EXECUTION
// ============================================================================
int main() {
    uart_print("\n\n==========================================\n");
    uart_print("[RISC-V] Booting ADAS TinyNPU System...\n");
    uart_print("==========================================\n");

    // 1. Configure NPU Requantization (Identity / Pass-through)
    uart_print("[RISC-V] Configuring NPU INT8 Requantization...\n");
    for(int i = 0; i < 8; i++) {
        // Write M0 = 1, Shift = 0 so the INT32 MACs aren't scaled down
        *(volatile uint32_t*)(NPU_REG_M0_BASE + (i*4))    = dummy_m0[i];
        *(volatile uint32_t*)(NPU_REG_SHIFT_BASE + (i*4)) = dummy_shift[i];
    }

    // 2. Set up DMA to Receive Output Data from NPU
    uart_print("[RISC-V] Starting DMA RX Channel...\n");
    *(volatile uint32_t*)DMA_S2MM_DMACR = 0x0001; // Start RX
    *(volatile uint32_t*)DMA_S2MM_DA    = (uint32_t)npu_output_buffer;
    *(volatile uint32_t*)DMA_S2MM_LENGTH = 1024;  // Expect 1024 bytes back

    // 3. Set up DMA to Send Dummy 1-valued Weights/Activations to NPU
    uart_print("[RISC-V] Sending Dummy 1-Valued Tensors to NPU...\n");
    *(volatile uint32_t*)DMA_MM2S_DMACR = 0x0001; // Start TX
    *(volatile uint32_t*)DMA_MM2S_SA    = (uint32_t)dummy_activations;
    *(volatile uint32_t*)DMA_MM2S_LENGTH = 4096;  // Send 4096 bytes

    // 4. Fire the NPU!
    uart_print("[RISC-V] Firing NPU Hardware...\n");
    *(volatile uint32_t*)NPU_REG_START = 1; // Trigger state machine

    // 5. Wait for NPU to finish crunching
    while ((*(volatile uint32_t*)NPU_REG_STATUS) & 0x01) {
        // Spin lock until Busy flag drops to 0
    }

    // 6. Print the Results to TeraTerm!
    uart_print("[RISC-V] Hardware Execution Complete!\n");
    uart_print("[RISC-V] Reading Output Memory:\n");
    
    // For a 3x3 Convolution of 1s, every MAC should output exactly 9.
    for(int i = 0; i < 32; i++) {
        uart_print("Result[");
        uart_print_int(i);
        uart_print("] = ");
        uart_print_int(npu_output_buffer[i]);
        uart_print("\n");
    }

    uart_print("\n[RISC-V] Data Flow Verification Complete. Entering Sleep.\n");
    while(1); // Infinite sleep loop
    return 0;
}
