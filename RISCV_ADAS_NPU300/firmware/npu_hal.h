// =============================================================================
// File:    npu_hal.h
// Project: RISCV_ADAS_NPU300
// Author:  TinyNPU ADAS Firmware
//
// Description:
//   Hardware Abstraction Layer (HAL) for the TinyNPU IP Core.
//   All AXI-Lite register addresses, bit definitions, and inline driver
//   functions are defined here.
//
//   Memory Map (from Block Design npu_system.bd):
//     RISC-V m_axi -> tinynpu_0 s_axi -> Base: 0x40000000
//
// Registers:
//   0x00 : CTRL     - Write 1 to start inference
//   0x04 : STATUS   - Bit[0]=Busy, Bit[1]=Done, Bit[2]=Error
//   0x08 : CFG      - Config: Bit[1:0]=activation (00=ReLU,01=Sigmoid,10=None)
//   0x0C : LAYER    - Current layer index (R/O)
//   0x10 : ACT_BASE - Base address of activation data in DDR
//   0x14 : WT_BASE  - Base address of weight data in DDR
//   0x18 : OUT_BASE - Base address of output buffer in DDR
//   0x1C : TILE_CFG - Tile dimensions [15:8]=rows, [7:0]=cols
//   0x50-0x6C : M0    - Requantization multipliers (layer 0..7)
//   0x70-0x8C : SHIFT - Requantization shifts (layer 0..7)
// =============================================================================

#ifndef NPU_HAL_H
#define NPU_HAL_H

#include <stdint.h>

// ============================================================================
// TinyNPU AXI-Lite Register Map
// ============================================================================
#define NPU_BASE            0x40000000UL

#define NPU_REG_CTRL        (NPU_BASE + 0x00)
#define NPU_REG_STATUS      (NPU_BASE + 0x04)
#define NPU_REG_CFG         (NPU_BASE + 0x08)
#define NPU_REG_LAYER       (NPU_BASE + 0x0C)
#define NPU_REG_ACT_BASE    (NPU_BASE + 0x10)
#define NPU_REG_WT_BASE     (NPU_BASE + 0x14)
#define NPU_REG_OUT_BASE    (NPU_BASE + 0x18)
#define NPU_REG_TILE_CFG    (NPU_BASE + 0x1C)

// Requantization parameter arrays (8 layers)
#define NPU_REG_M0_BASE     (NPU_BASE + 0x50)
#define NPU_REG_SHIFT_BASE  (NPU_BASE + 0x70)

// STATUS register bit masks
#define NPU_STATUS_BUSY     (1u << 0)
#define NPU_STATUS_DONE     (1u << 1)
#define NPU_STATUS_ERROR    (1u << 2)

// CFG register activation type
#define NPU_ACT_RELU        0x0
#define NPU_ACT_SIGMOID     0x1
#define NPU_ACT_NONE        0x2

// CTRL register bits
#define NPU_CTRL_START      (1u << 0)
#define NPU_CTRL_RESET      (1u << 1)

// ============================================================================
// Inline Register Access Helpers
// ============================================================================
static inline void npu_write_reg(uint32_t addr, uint32_t val) {
    *(volatile uint32_t*)addr = val;
}

static inline uint32_t npu_read_reg(uint32_t addr) {
    return *(volatile uint32_t*)addr;
}

// ============================================================================
// HAL API
// ============================================================================

// Reset the NPU state machine
static inline void npu_reset(void) {
    npu_write_reg(NPU_REG_CTRL, NPU_CTRL_RESET);
    // Hold reset for a few cycles
    for (volatile int i = 0; i < 16; i++);
    npu_write_reg(NPU_REG_CTRL, 0);
}

// Check if NPU is currently processing
static inline int npu_is_busy(void) {
    return (npu_read_reg(NPU_REG_STATUS) & NPU_STATUS_BUSY) != 0;
}

// Check if last inference is complete
static inline int npu_is_done(void) {
    return (npu_read_reg(NPU_REG_STATUS) & NPU_STATUS_DONE) != 0;
}

// Check for hardware error
static inline int npu_has_error(void) {
    return (npu_read_reg(NPU_REG_STATUS) & NPU_STATUS_ERROR) != 0;
}

// Block until NPU is idle (with a simple timeout counter)
// Returns 0 on success, -1 on timeout/error
static inline int npu_wait_idle(uint32_t timeout_cycles) {
    volatile uint32_t t = 0;
    while (npu_is_busy()) {
        if (++t > timeout_cycles) return -1;
    }
    if (npu_has_error()) return -1;
    return 0;
}

// Configure the inference parameters
static inline void npu_configure(
    uint32_t act_base_addr,
    uint32_t wt_base_addr,
    uint32_t out_base_addr,
    uint8_t  tile_rows,
    uint8_t  tile_cols,
    uint8_t  activation_type
) {
    npu_write_reg(NPU_REG_ACT_BASE, act_base_addr);
    npu_write_reg(NPU_REG_WT_BASE,  wt_base_addr);
    npu_write_reg(NPU_REG_OUT_BASE, out_base_addr);
    npu_write_reg(NPU_REG_TILE_CFG, ((uint32_t)tile_rows << 8) | tile_cols);
    npu_write_reg(NPU_REG_CFG,      activation_type);
}

// Load requantization parameters for all 8 layers
static inline void npu_load_requant_params(const uint32_t* m0_arr, const uint32_t* shift_arr, int num_layers) {
    for (int i = 0; i < num_layers && i < 8; i++) {
        npu_write_reg(NPU_REG_M0_BASE    + (i * 4), m0_arr[i]);
        npu_write_reg(NPU_REG_SHIFT_BASE + (i * 4), shift_arr[i]);
    }
}

// Fire the NPU (non-blocking)
static inline void npu_start(void) {
    npu_write_reg(NPU_REG_CTRL, NPU_CTRL_START);
}

#endif // NPU_HAL_H
