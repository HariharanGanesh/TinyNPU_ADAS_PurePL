#ifndef MLX90640_FIXED_H
#define MLX90640_FIXED_H

#include <stdint.h>

// Q20 format: 12 bits integer, 20 bits fractional
#define Q_FRAC_BITS 20
#define FLOAT_TO_Q20(x) ((int32_t)((x) * (1 << Q_FRAC_BITS)))
#define Q20_TO_FLOAT(x) ((float)(x) / (1 << Q_FRAC_BITS))
#define Q20_MUL(a, b)   (int32_t)(((int64_t)(a) * (b)) >> Q_FRAC_BITS)

void mlx90640_init_i2c(void);
void mlx90640_trigger_dma_read(void);
int mlx90640_is_dma_complete(void);
void mlx90640_calculate_temperatures_q20(int32_t *temp_q20_array);

#endif
