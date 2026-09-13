#ifndef DUMMY_DATA_H
#define DUMMY_DATA_H

#include <stdint.h>

// -----------------------------------------------------------------------------
// TinyNPU FPGA Data Flow Verification Weights & Activations
// -----------------------------------------------------------------------------
// These arrays are filled entirely with `1`s (0x01) to easily verify the MAC 
// accumulators in the Systolic Array and Depthwise units. 
//
// GNU C designated initializers are used to compactly fill the arrays.
// Make sure to compile your firmware with a GCC-compatible compiler (e.g., riscv-gcc).

#define DATA_SIZE 4096

// Dummy 1-valued Weights
const int8_t dummy_weights[DATA_SIZE] __attribute__((aligned(32))) = { 
    [0 ... DATA_SIZE-1] = 1 
};

// Dummy 1-valued Activations
const int8_t dummy_activations[DATA_SIZE] __attribute__((aligned(32))) = { 
    [0 ... DATA_SIZE-1] = 1 
};

// Dummy Requantization Parameters (M0=1, Shift=0 for Identity Pass-through)
// Assuming 32 Output Channels
const int32_t dummy_m0[32] __attribute__((aligned(32))) = { 
    [0 ... 31] = 1 
};

const int32_t dummy_shift[32] __attribute__((aligned(32))) = { 
    [0 ... 31] = 0 
};

const int32_t dummy_bias[32] __attribute__((aligned(32))) = { 
    [0 ... 31] = 0 
};

#endif // DUMMY_DATA_H
