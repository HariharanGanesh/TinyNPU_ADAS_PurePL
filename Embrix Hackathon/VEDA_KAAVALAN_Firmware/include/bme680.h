#ifndef BME680_H
#define BME680_H
#include <stdint.h>

void bme680_init_i2c(void);
uint32_t bme680_read_gas_resistance(void);
int bme680_check_voc_anomaly(void);

#endif
