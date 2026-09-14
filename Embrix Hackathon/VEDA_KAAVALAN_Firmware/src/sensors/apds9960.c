#include "apds9960.h"

// APDS-9960 is on I2C2 at address 0x39
void apds9960_init(void) {
    // Enable Gesture engine and Proximity
}

int apds9960_check_authorized_gesture(void) {
    // Read gesture FIFO over I2C2
    // If sequence matches (e.g., UP, DOWN), return 1 (Authorized)
    return 0; // Default Unathorized
}
