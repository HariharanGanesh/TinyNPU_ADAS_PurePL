#ifndef APDS9960_H
#define APDS9960_H
#include <stdint.h>

void apds9960_init(void);
int apds9960_check_authorized_gesture(void);

#endif
