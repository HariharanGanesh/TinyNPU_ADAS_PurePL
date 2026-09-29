#include "mlx90640_fixed.h"

// 1KB LUT for fast square root / polynomial approximation in Q20
// Flash resident (will be placed in .rodata)
__attribute__((section(".rodata"))) const int32_t mlx_compensation_lut[256] = {
    // ... Pre-computed Q20 values for V_ir approximation ...
    FLOAT_TO_Q20(1.0), FLOAT_TO_Q20(1.01), // Dummy values for compilation
};

void mlx90640_calculate_temperatures_q20(int32_t *temp_q20_array) {
    // Simplified fixed-point approximation replacing Melexis float math
    // Standard formula: Ta = (V_ir / sensitivity) + To
    
    for (int i = 0; i < 768; i++) {
        // 1. Read raw RAM pixel (simulated via DMA buffer)
        int32_t raw_pixel = 1500; // placeholder for RAM[i]
        
        // 2. Linear fixed-point compensation instead of power-series
        // Emulating: temp = (raw * gain) + offset
        int32_t gain_q20 = FLOAT_TO_Q20(0.025); 
        int32_t offset_q20 = FLOAT_TO_Q20(22.0); // Ambient baseline
        
        int32_t pixel_q20 = raw_pixel << Q_FRAC_BITS; // Convert raw to Q20
        
        // Multiply and add in Q20 domain
        int32_t temp = Q20_MUL(pixel_q20, gain_q20) + offset_q20;
        
        temp_q20_array[i] = temp;
    }
}
