#ifndef BMI088_GOERTZEL_H
#define BMI088_GOERTZEL_H

#include <stdint.h>

// VEGA GPIO Pin definitions for Dual-CS
#define BMI088_CS_ACCEL_PIN 8
#define BMI088_CS_GYRO_PIN  9

void bmi088_init_spi(void);
void bmi088_trigger_dma_read_accel(void);
void bmi088_trigger_dma_read_gyro(void);

// Q15 Goertzel algorithm for 1-5Hz footstep cadence
#define Q15_SHIFT 15
#define FLOAT_TO_Q15(x) ((int32_t)((x) * (1 << Q15_SHIFT)))

int32_t goertzel_mag_q15(int16_t *data, int num_samples, int32_t coeff_q15);

#endif
