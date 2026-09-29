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

// ADAS Extended CSRs
#define NPU_REG_THRESH_LOGIT   (NPU_CSR_BASE + 0x84)
#define NPU_REG_MAX_CANDIDATES (NPU_CSR_BASE + 0x88)
#define NPU_REG_CLEAR_FRAME    (NPU_CSR_BASE + 0x8C)
#define NPU_REG_SCALE_ID       (NPU_CSR_BASE + 0x90)

// AXI DMA Engine
#define AXI_DMA_BASE       0x41E00000
#define DMA_MM2S_DMACR     (AXI_DMA_BASE + 0x00) // TX Control
#define DMA_MM2S_SA        (AXI_DMA_BASE + 0x18) // TX Source Address
#define DMA_MM2S_LENGTH    (AXI_DMA_BASE + 0x28) // TX Transfer Length (Bytes)

#define DMA_S2MM_DMACR     (AXI_DMA_BASE + 0x30) // RX Control
#define DMA_S2MM_DA        (AXI_DMA_BASE + 0x48) // RX Destination Address
#define DMA_S2MM_LENGTH    (AXI_DMA_BASE + 0x58) // RX Transfer Length (Bytes)

// UART Terminal
#define UART_BASE          0x42C00000
#define UART_TX_DATA       (UART_BASE + 0x04)
#define UART_STATUS        (UART_BASE + 0x08)

// ADAS BRAM (Memory mapped to RISC-V)
#define ADAS_BRAM_BASE     0xC0000000

// Output Buffer for NPU Results
int8_t npu_output_buffer[4096] __attribute__((aligned(32)));

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

void uart_print_char(char c) {
    while ((*(volatile uint32_t*)UART_STATUS) & 0x08);
    *(volatile uint32_t*)UART_TX_DATA = c;
}

void uart_print(const char* str) {
    while (*str) {
        uart_print_char(*str++);
    }
}

void uart_print_int(int val) {
    char buffer[16];
    int i = 0;
    if (val == 0) {
        uart_print("0");
        return;
    }
    if (val < 0) {
        uart_print_char('-');
        val = -val;
    }
    while (val > 0) {
        buffer[i++] = (val % 10) + '0';
        val /= 10;
    }
    while (i > 0) {
        uart_print_char(buffer[--i]);
    }
}

void uart_print_hex(uint32_t val) {
    char buffer[8];
    uart_print("0x");
    for (int i = 7; i >= 0; i--) {
        int nibble = (val >> (i * 4)) & 0xF;
        if (nibble < 10) uart_print_char(nibble + '0');
        else uart_print_char(nibble - 10 + 'A');
    }
}

// ============================================================================
// MAIN FIRMWARE EXECUTION
// ============================================================================
int main() {
    uart_print("\n\n==========================================\n");
    uart_print("[RISC-V] Booting ADAS TinyNPU System...\n");
    uart_print("==========================================\n");

    // 1. Configure NPU Requantization
    uart_print("[RISC-V] Configuring NPU INT8 Requantization...\n");
    for(int i = 0; i < 8; i++) {
        *(volatile uint32_t*)(NPU_REG_M0_BASE + (i*4))    = dummy_m0[i];
        *(volatile uint32_t*)(NPU_REG_SHIFT_BASE + (i*4)) = dummy_shift[i];
    }

    // 2. Configure ADAS Detection Head CSRs
    uart_print("[RISC-V] Configuring ADAS Detection Head...\n");
    *(volatile uint32_t*)NPU_REG_THRESH_LOGIT   = 0;   // Threshold = 0
    *(volatile uint32_t*)NPU_REG_MAX_CANDIDATES = 100; // Allow 100 candidates
    *(volatile uint32_t*)NPU_REG_SCALE_ID       = 1;   // Scale 1
    
    // Clear the frame BRAM
    *(volatile uint32_t*)NPU_REG_CLEAR_FRAME = 1;
    *(volatile uint32_t*)NPU_REG_CLEAR_FRAME = 0;

    // 3. Set up DMA to Receive Output Data from NPU (Raw Tensors)
    uart_print("[RISC-V] Starting DMA RX Channel...\n");
    *(volatile uint32_t*)DMA_S2MM_DMACR = 0x0001; // Start RX
    *(volatile uint32_t*)DMA_S2MM_DA    = (uint32_t)npu_output_buffer;
    *(volatile uint32_t*)DMA_S2MM_LENGTH = 1024;  // Expect 1024 bytes back

    // 4. Set up DMA to Send Dummy Activations
    uart_print("[RISC-V] Sending Dummy 1-Valued Tensors to NPU...\n");
    *(volatile uint32_t*)DMA_MM2S_DMACR = 0x0001; // Start TX
    *(volatile uint32_t*)DMA_MM2S_SA    = (uint32_t)dummy_activations;
    *(volatile uint32_t*)DMA_MM2S_LENGTH = 4096;  // Send 4096 bytes

    // 5. Fire the NPU!
    uart_print("[RISC-V] Firing NPU Hardware...\n");
    *(volatile uint32_t*)NPU_REG_START = 1;

    // 6. Wait for NPU to finish crunching
    while ((*(volatile uint32_t*)NPU_REG_STATUS) & 0x01) {
        // Spin lock
    }

    uart_print("[RISC-V] Hardware Execution Complete!\n");

    // 7. Verify ADAS Bounding Boxes in BRAM
    uart_print("[RISC-V] Checking ADAS BRAM for Candidates...\n");
    
    // BRAM is mapped at 0xC0000000. Each record is 128 bits (16 bytes = 4 uint32_t words)
    // We'll read the first 5 candidates.
    for (int i = 0; i < 5; i++) {
        uint32_t word0 = *(volatile uint32_t*)(ADAS_BRAM_BASE + (i * 16) + 0);
        uint32_t word1 = *(volatile uint32_t*)(ADAS_BRAM_BASE + (i * 16) + 4);
        uint32_t word2 = *(volatile uint32_t*)(ADAS_BRAM_BASE + (i * 16) + 8);
        uint32_t word3 = *(volatile uint32_t*)(ADAS_BRAM_BASE + (i * 16) + 12);
        
        uart_print("Candidate ["); uart_print_int(i); uart_print("]: ");
        uart_print_hex(word3); uart_print("_");
        uart_print_hex(word2); uart_print("_");
        uart_print_hex(word1); uart_print("_");
        uart_print_hex(word0); uart_print("\n");
    }

    uart_print("\n[RISC-V] Data Flow Verification Complete. Entering Sleep.\n");
    while(1); // Infinite sleep loop
    return 0;
}
