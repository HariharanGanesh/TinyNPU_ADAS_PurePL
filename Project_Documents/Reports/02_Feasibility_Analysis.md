# VEGA-GUARDIAN — Deep Feasibility Verification
## Based on Official ARIES IoT v2.0 Product Reference Manual

---

## 1. Hardware Peripheral Audit (From Datasheet)

The first step is to map every feature we need to an actual, available peripheral on the board.

### 1.1 BMI088 — 6-Axis IMU (Accel + Gyro)
> **CRITICAL FINDING: The BMI088 uses SPI2, NOT I2C.**

From the pinout table:
```
SPI_SS2   → U14_14  (Connected to BMI088)
SPI_SCLK2 → U14_8
SPI_MISO2 → U14_10 / U14_15
SPI_MOSI2 → U14_9
GPIO21    → U14_5   (BMI088 interrupt pin)
```
✅ **Verdict:** The IMU is **pre-wired** on the board via SPI2. No external wiring needed.
⚠️ **Action Required:** The IMU driver must be SPI-based, NOT I2C-based.

---

### 1.2 MLX90640 Thermal Camera (External — You Bring This)
The MLX90640 uses an **I2C interface**.

Available I2C buses from the datasheet:
```
I2C0: SCL0=J10_12, SDA0=J10_10  → Available on Header J10 ✅
I2C1: SCL1=J1_1,  SDA1=J1_2    → Available on Header J1  ✅
I2C2: ALREADY USED INTERNALLY (BME680 + APDS-9960 + I2C ADC) ❌
```
✅ **Verdict:** Connect the MLX90640 to **I2C0 (Header J10)**. It is fully free.

---

### 1.3 Mode Switch (Defence / Industrial)
> **GREAT NEWS: No external switch needed!**

From the datasheet:
```
GPIO18 → BTN1 (Push Button 1) — already on the board
GPIO19 → BTN0 (Push Button 0) — already on the board
```
✅ **Verdict:** Use the **onboard BTN0 (GPIO19)** as the Defence/Normal mode toggle switch. It is physically on the board already.

---

### 1.4 NINA-W10 Wi-Fi Module
```
SPI1:  U11_28 (SS), U11_29 (SCLK), U11_1 (MISO), U11_21 (MOSI) → Pre-wired
UART2: RX2=U11_22, TX2=U11_23 → Pre-wired
GPIO16, GPIO17, GPIO20 → Pre-wired to NINA module
```
✅ **Verdict:** VEGA communicates with the NINA module via **UART2 using AT commands**. Fully pre-wired. No external wiring needed.

---

### 1.5 BME680 (Gas, Humidity, Pressure, Temperature)
```
I2C2: SCL2/SDA2 → U12 (BME680) — Pre-wired
```
✅ **Verdict:** Available for **both modes**. In Defence mode, the temperature reading can confirm false positives from weather (hot sun vs. human body temp). In Industrial mode, gas sensor detects workplace hazard gases.

---

### 1.6 APDS-9960 (Gesture + Proximity + Ambient Light)
```
I2C2: SCL2/SDA2 → U13 (APDS-9960) — Pre-wired
```
✅ **Bonus:** This sensor can be used as an **additional trigger** in Defence mode (proximity detection at close range) or as a gesture shortcut in Industrial mode.

---

### 1.7 Alerts & Output
```
Buzzer (LS1)    → GPIO (exact pin from board) ✅
RGB LED (LD1)   → GPIO22 (Green), GPIO23 (Blue), GPIO24 (Red) ✅
Push Buttons    → GPIO18 (BTN1), GPIO19 (BTN0) ✅
```
✅ **Verdict:** Full visual + audio alert capability is built-in.

---

## 2. Complete Hardware Resource Map

| Feature | Peripheral Used | Bus | Status |
|---|---|---|---|
| IMU (Accel + Gyro) | BMI088 | SPI2 (pre-wired) | ✅ Ready |
| Thermal Camera | MLX90640 (external) | I2C0 → Header J10 | ✅ Wire it |
| Env. Sensors | BME680 | I2C2 (pre-wired) | ✅ Ready |
| Proximity/Gesture | APDS-9960 | I2C2 (pre-wired) | ✅ Ready |
| Wi-Fi Alerts | NINA-W10 | UART2 (pre-wired) | ✅ Ready |
| Mode Switch | BTN0 | GPIO19 (pre-wired) | ✅ Ready |
| Status LED | RGB LED | GPIO22/23/24 | ✅ Ready |
| Audio Alert | Buzzer | GPIO (pre-wired) | ✅ Ready |
| Debug/Programming | USB-UART | UART0 | ✅ Ready |

**No I2C, SPI, or GPIO conflicts exist. Every peripheral has its own dedicated bus.**

---

## 3. Memory Budget (Revised with Actual Datasheet)

> Total SRAM: **256 KB**. The KEY insight: Store model weights in **2MB Flash** and load only the ACTIVE mode's weights into SRAM at runtime.

### SRAM Budget (Worst case, one mode active at a time)

| Component | Size (KB) |
|---|---|
| VEGA SDK + startup code + stack | ~50 KB |
| Active Mode CNN weights (INT8, from Flash) | ~60 KB |
| Active Mode activation scratchpad buffers | ~18 KB |
| Thermal frame buffer (32×24 = 768 bytes) | ~1 KB |
| IMU SPI ring buffer (50 samples × 6 × 2 bytes) | ~1 KB |
| BME680 sensor data | ~0.5 KB |
| APDS-9960 sensor data | ~0.5 KB |
| NINA Wi-Fi AT command TX/RX buffers | ~4 KB |
| Misc variables + padding | ~10 KB |
| **TOTAL (one mode active)** | **~145 KB** |
| **Headroom remaining** | **~111 KB ✅** |

### Flash Budget (2 MB total)

| Component | Size |
|---|---|
| Application firmware (code) | ~200 KB |
| Defence Mode CNN weights (INT8) | ~80 KB |
| Industrial Safety CNN weights (INT8) | ~50 KB |
| **TOTAL** | **~330 KB / 2048 KB** |
| **Flash headroom** | **~1.7 MB ✅ Massive room** |

✅ **Memory verdict: Fully feasible.** The trick is weights live in Flash, loaded on mode switch.

---

## 4. Software Feasibility

### 4.1 Development Environment
- **IDE:** VEGA Arduino IDE or Eclipse IDE (both supported per Section 4.1 of the manual)
- **Language:** C / C++
- **SDK:** VEGA SDK (full BSP, HAL drivers, examples)
- Links: `https://bit.ly/vega-windows`, `https://cdac-vega.gitlab.io/sdkuserguide.html`
✅ **Fully supported.**

### 4.2 Driver Availability
| Driver | Status | Notes |
|---|---|---|
| BMI088 SPI driver | ✅ Bosch provides official open-source C driver | Port to VEGA SPI HAL |
| MLX90640 I2C driver | ✅ Melexis provides official open-source C driver | Port to VEGA I2C HAL |
| BME680 driver | ✅ Bosch provides BSEC C library | Use simplified version |
| NINA-W10 Wi-Fi | ✅ AT command set via UART2 | Write simple AT command wrapper |
| APDS-9960 driver | ✅ Open-source C/C++ drivers available | Port to VEGA I2C HAL |

### 4.3 TinyML Inference Engine
> **TensorFlow Lite for Microcontrollers is TOO HEAVY** (requires ~300KB RAM minimum). Do NOT use it.

Instead, write a **bare-metal INT8 inference engine in C**. This is feasible and is exactly what your NPU background prepares you for.

The inference consists of only 4 primitive operations:
1. `conv2d_int8()` — for the thermal CNN
2. `maxpool2d()` — pooling layer
3. `conv1d_int8()` — for the IMU 1D-CNN
4. `dense_int8()` — for the final classification layer

Each of these is a simple nested `for` loop over the weight arrays. With your knowledge of INT8 requantization (scale factor M0, shift n, bias), you already know how to implement this precisely.

### 4.4 Mode Switch Software Logic
```c
// GPIO19 interrupt handler (BTN0)
void BTN0_IRQHandler() {
    if (current_mode == DEFENCE_MODE) {
        current_mode = INDUSTRIAL_MODE;
        load_model_from_flash(&industrial_cnn_weights); // Copy from Flash to SRAM
        init_sensors_industrial();  // Start IMU polling at 50Hz
        set_rgb_led(GREEN);
    } else {
        current_mode = DEFENCE_MODE;
        load_model_from_flash(&defence_cnn_weights);    // Swap model in SRAM
        init_sensors_defence();     // Start thermal I2C polling at 8fps
        set_rgb_led(RED);
    }
}
```
✅ **Fully feasible.** The model swap is a simple `memcpy` from Flash to SRAM (~60KB, takes ~10ms at 100MHz).

### 4.5 Wi-Fi Alerts via NINA-W10
The NINA module communicates over UART2 via AT commands:
```c
// Send threat alert over Wi-Fi (MQTT via AT commands)
uart2_send("AT+MQTTPUB=\"threat\",\"INTRUDER DETECTED\"\r\n");
```
✅ **Feasible.** The NINA module handles all the TCP/IP stack independently. The VEGA core just sends a text string.

---

## 5. Compute Timeline (Real-Time Feasibility)

### Defence Mode: Thermal Pipeline
```
1. Read MLX90640 frame over I2C0    → ~125 ms (I2C at 400KHz, 768 bytes)
2. Run 2-layer CNN inference (INT8) → ~5 ms
3. Run BME680 temp check            → ~2 ms
4. Fusion decision + alert          → ~1 ms
Total per cycle: ~133 ms = ~7.5 fps ✅ (adequate for perimeter detection)
```

### Industrial Mode: IMU Pipeline
```
1. Read BMI088 6-axis via SPI2      → ~0.5 ms (SPI is fast)
2. Fill 50-sample ring buffer       → runs at 50Hz (20ms period)
3. Run 1D-CNN inference             → ~1 ms
4. Alert if triggered               → ~1 ms
Total latency from motion to alert: ~22 ms ✅ (near-instant for human perception)
```

---

## 6. Final Verdict

| Requirement | Feasible? | Evidence |
|---|---|---|
| IMU (BMI088) | ✅ YES | Pre-wired on SPI2 |
| Thermal Camera | ✅ YES | Connects to free I2C0 Header J10 |
| Mode Switch | ✅ YES | Use onboard BTN0 (GPIO19) |
| Wi-Fi Alerts | ✅ YES | Pre-wired NINA-W10 via UART2 |
| Environmental Sensors | ✅ YES | BME680 pre-wired on I2C2 |
| Memory (SRAM) | ✅ YES | ~145KB used / 256KB, with Flash offloading |
| Flash Storage | ✅ YES | Only ~330KB used of 2MB |
| Real-time Inference | ✅ YES | 7.5fps thermal, 50Hz IMU |
| Software Stack | ✅ YES | VEGA SDK + custom INT8 C engine |
| No FPGA | ✅ YES | Pure software on RISC-V core |
| No FPU | ✅ HANDLED | INT8 quantization throughout |

> **VEGA-GUARDIAN is fully implementable on the ARIES IoT v2.0 board as described.**
> No peripheral conflicts. No memory overflow. No unsupported operations.
> The only external component needed is the **MLX90640 thermal camera module** (~₹2,500).
