#include "nina_ble.h"
#include <stdio.h>

// Connected to UART2
void nina_uart_init(void) {
    // Init UART2 at 115200 baud
}

void nina_send_mqtt_alert(const char* type, const char* msg) {
    // Construct ESP-AT command
    // e.g. AT+MQTTPUB=0,"veda/alerts","{\"type\":\"THREAT_HUMAN\"}",0,0
}

int nina_scan_ble_iff(void) {
    // Send AT+BLESCAN=1
    // Parse UART RX for authorized MAC address
    return 0; // 1 if friendly found, 0 otherwise
}
