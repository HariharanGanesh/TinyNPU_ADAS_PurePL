#ifndef NINA_BLE_H
#define NINA_BLE_H

void nina_uart_init(void);
void nina_send_mqtt_alert(const char* type, const char* msg);
int nina_scan_ble_iff(void);

#endif
