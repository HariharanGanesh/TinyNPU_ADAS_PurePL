#include "bmi088_goertzel.h"

// Goertzel Algorithm in pure integer math (Q15 format)
// Avoids floating point FFT for detecting footstep frequencies
int32_t goertzel_mag_q15(int16_t *data, int num_samples, int32_t coeff_q15) {
    int32_t q0 = 0, q1 = 0, q2 = 0;
    
    for (int i = 0; i < num_samples; i++) {
        // q0 = coeff * q1 - q2 + data[i]
        // coeff is Q15, q1 is Q0. Multiply gives Q15, shift right 15 to get back to Q0
        int32_t cq1 = (coeff_q15 * q1) >> Q15_SHIFT;
        q0 = cq1 - q2 + data[i];
        
        q2 = q1;
        q1 = q0;
    }
    
    // Magnitude squared = q1^2 + q2^2 - coeff * q1 * q2
    int32_t mag_sq = (q1 * q1) + (q2 * q2) - (((coeff_q15 * q1) >> Q15_SHIFT) * q2);
    return mag_sq;
}

// Example usage inside scheduler:
// Target frequency: 2Hz (walking), Sampling rate: 25Hz, N: 256
// k = 256 * (2 / 25) = 20.48 -> approx 20
// w = (2 * PI * 20) / 256 = 0.4908
// coeff = 2 * cos(w) = 1.763
// coeff_q15 = 1.763 * 32768 = 57770
