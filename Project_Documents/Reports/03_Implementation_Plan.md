# VEGA-GUARDIAN: Detailed Implementation Plan
### EMBRIX'26 VEGATHON — Track 2: Edge AI for Real-Time Decision Making
### Platform: VEGA ARIES IoT v2.0 | Language: C/C++ | SDK: VEGA SDK

---

## System Architecture Overview

```
+-------------------------------------------------------------------+
|                    VEGA ET1031 (100MHz RISC-V)                    |
|                                                                   |
|  +---------------+   GPIO19/BTN0   +---------------------------+  |
|  |   MODE FSM    |<----------------|  Mode Switch Handler      |  |
|  |   DEFENCE     |                 |  (GPIO Interrupt)         |  |
|  |   INDUSTRIAL  |                 +---------------------------+  |
|  +-------+-------+                                               |
|          |                                                        |
|  +-------v---------------------------------------------------+   |
|  |          Active Pipeline (one at a time)                   |   |
|  |                                                            |   |
|  |  DEFENCE MODE:              INDUSTRIAL MODE:               |   |
|  |  +------------------+       +--------------------+         |   |
|  |  | MLX90640 I2C0    |       | BMI088 SPI2 @ 50Hz |         |   |
|  |  | Thermal @ 8fps   |       +----------+---------+         |   |
|  |  +---------+--------+                  |                   |   |
|  |            |                           |                   |   |
|  |  +---------v--------+       +----------v---------+         |   |
|  |  | Thermal CNN INT8 |       | IMU 1D-CNN INT8    |         |   |
|  |  | 2-layer          |       | 2-layer            |         |   |
|  |  +---------+--------+       +----------+---------+         |   |
|  |            | +BME680 fusion             |                   |   |
|  |  +---------v---------------------------v---------+          |   |
|  |  |          Decision & Alert Engine              |          |   |
|  |  +--------+------------------------+-------------+          |   |
|  +-----------|------------------------|---------------------+  |   |
|              |                        |                        |   |
|       +------v------+         +-------v------+                |   |
|       | UART2->NINA |         | RGB LED +    |                |   |
|       | Wi-Fi MQTT  |         | Buzzer Alert |                |   |
|       +-------------+         +--------------+                |   |
+-------------------------------------------------------------------+
```

---

## Project Folder Structure

```
d:/Final year project/Embrix Hackathon/
├── 01_Project_Abstract.md
├── 02_Feasibility_Analysis.md
├── 03_Implementation_Plan.md          <- THIS FILE
├── firmware/
│   ├── main.c
│   ├── mode_fsm.c / mode_fsm.h
│   ├── drivers/
│   │   ├── bmi088_spi.c / .h          (IMU driver - SPI2)
│   │   ├── mlx90640_i2c.c / .h        (Thermal camera - I2C0)
│   │   ├── bme680.c / .h              (Environmental sensor - I2C2)
│   │   ├── nina_wifi.c / .h           (AT command Wi-Fi - UART2)
│   │   └── alert.c / .h               (RGB LED + Buzzer)
│   ├── inference/
│   │   ├── int8_inference.c / .h      (Core inference engine)
│   │   ├── defence_model_weights.h    (INT8 weights as C array)
│   │   └── industrial_model_weights.h (INT8 weights as C array)
│   └── utils/
│       ├── ring_buffer.c / .h
│       └── fixed_point_math.h
├── model_training/
│   ├── defence_thermal_cnn.py         (Train + quantize thermal model)
│   ├── industrial_imu_cnn.py          (Train + quantize IMU model)
│   ├── generate_c_array.py            (Convert .tflite -> .h weight array)
│   └── collect_imu_data.py            (Serial data logger from board)
└── dashboard/
    └── mqtt_dashboard.py              (Laptop-side alert viewer)
```

---

## Phase 1: Foundation (Hours 1-8)

### 1.1 Setup VEGA SDK (Hours 1-2)
- Install VEGA Arduino IDE or Eclipse IDE on the hackathon laptop
- Flash a "Hello World" blink sketch to verify the toolchain works
- Verify USB-UART (UART0) communication for printf debugging
OPERABILITY CHECK: RGB LED blinks. Serial monitor shows "VEGA-GUARDIAN BOOT OK".

### 1.2 BMI088 SPI Driver (Hours 2-4)
CRITICAL: The BMI088 is wired to SPI2 on the board (NOT I2C).
  SPI_SS2   -> U14_14
  SPI_SCLK2 -> U14_8
  SPI_MISO2 -> U14_10
  SPI_MOSI2 -> U14_9
  GPIO21    -> BMI088 interrupt

Steps:
1. Configure SPI2 at 10MHz, Mode 0
2. Write BMI088 ACC_CONF register (0x40) -> ODR=100Hz
3. Write BMI088 GYR_RANGE register -> +-500 deg/s
4. Read 12 bytes from ACC_DATA (0x12) + GYR_DATA (0x02)

OPERABILITY CHECK: Print raw values over UART0. Board at rest -> Z-axis ~9.8 m/s2.

### 1.3 MLX90640 Thermal Camera I2C Driver (Hours 4-6)
Connect MLX90640 to I2C0 on Header J10:
  SCL0 -> J10_12
  SDA0 -> J10_10
  VCC  -> 3.3V
  GND  -> GND

Write a custom fixed-point integer compensation driver (NOT the Melexis float driver). The VEGA ET1031 has no FPU - the official Melexis driver uses float math (sqrt, polynomials) which will be extremely slow. Implement linear integer approximation instead. to VEGA I2C HAL.
Set frame rate to 4fps (register 0x800D). Note: with integer temperature compensation (no FPU), expect 3-4fps actual throughput.

OPERABILITY CHECK: Print 32x24 temp grid over UART0.
Human hand over sensor shows hot region (~36C) vs background (~25C).

### 1.4 NINA-W10 Wi-Fi Driver (Hours 6-7)
NINA module is pre-wired on UART2:
  UART_RX2 -> U11_22
  UART_TX2 -> U11_23

Use AT commands at 115200 baud:
  AT          -> expect OK
  AT+CWJAP    -> connect to Wi-Fi
  AT+MQTTCONN -> connect to MQTT broker
  AT+MQTTPUB  -> publish alert

OPERABILITY CHECK: Laptop mosquitto_sub receives "NINA OK" from board.

### 1.5 Mode Switch & Alerts (Hours 7-8)
BTN0 = GPIO19 (already on board, no external switch needed!)
BTN1 = GPIO18 (reserved for future use)

Mode switch via GPIO19 falling-edge interrupt.
Alerts: RGB LED GPIO22/23/24, Buzzer LS1.

OPERABILITY CHECK: Press BTN0 -> LED changes RED to GREEN and back.

---

## Phase 2: Data Collection & Model Training (Hours 8-20)

### 2.1 IMU Data Collection (Hours 8-10)
Stream raw IMU data at 50Hz via UART0 to laptop CSV logger.
Collect 200 examples per class:
  Class 0: safe_motion     (normal walking)
  Class 1: fall_event      (sudden drop, >3g spike)
  Class 2: emergency_stop  (specific wrist flick gesture)

### 2.2 Thermal Data Collection (Hours 10-12)
Stream thermal frames via UART0 to laptop.
Collect 100 frames per class:
  Class 0: background    (empty scene)
  Class 1: human_threat  (person in frame)
  Class 2: non_threat    (hot cup, heat gun, sunlight)

### 2.3 Train IMU 1D-CNN (Hours 12-15)
Input: (50 samples x 6 axes)
Architecture:
  Conv1D(16 filters, kernel=5) -> ReLU -> MaxPool(2)
  Conv1D(32 filters, kernel=3) -> ReLU -> GlobalAvgPool
  Dense(3) -> Softmax
~25,000 parameters -> ~25KB INT8

Convert to TFLite INT8 using representative dataset calibration.

### 2.4 Train Thermal 2D-CNN (Hours 15-19)
Input: (32 x 24 x 1) thermal frame
Architecture:
  Conv2D(8 filters, 3x3) -> ReLU -> MaxPool(2) -> (16x12x8)
  Conv2D(16 filters, 3x3) -> ReLU -> MaxPool(2) -> (8x6x16)
  Flatten -> Dense(32) -> Dense(3) -> Softmax
~80,000 parameters -> ~80KB INT8

### 2.5 Convert to C Arrays (Hours 19-20)
Use generate_c_array.py to convert both .tflite models to .h files.
OPERABILITY CHECK: INT8 model accuracy on test set > 90% for both models.

---

## Phase 3: INT8 Inference Engine in C (Hours 20-36)

### 3.1 Core Inference Primitives (Hours 20-28)
Implement the following functions in C (integer arithmetic ONLY, no floats):

requantize(acc, bias, M0, n_shift):
  Uses IDENTICAL math to TinyNPU2050 RTL requantization unit.
  output = clamp(round((acc + bias) * M0 >> n_shift), -128, 127)

conv2d_int8()   - For thermal CNN
conv1d_int8()   - For IMU CNN
maxpool2d()     - Spatial pooling
dense_int8()    - Fully connected layer
relu_int8()     - Clamp negative values to 0
argmax_int8()   - Return class with highest logit

Input normalization (thermal: 15C to 45C -> -128 to 127) uses float
but only ONCE per frame, not per operation. Acceptable.

### 3.2 Defence Inference Pipeline (Hours 28-32)
Full pipeline in C:
  mlx90640_get_frame() -> normalize -> conv2d x2 -> dense x2 -> argmax
OPERABILITY CHECK:
  Human hand over camera -> prints "CLASS: HUMAN_THREAT"
  Hot cup over camera    -> prints "CLASS: NON_THREAT"
  Empty scene            -> prints "CLASS: BACKGROUND"

### 3.3 Industrial Inference Pipeline (Hours 32-35)
Full pipeline in C:
  bmi088_read() -> fill ring buffer -> conv1d x2 -> GAP -> dense -> argmax
OPERABILITY CHECK:
  Normal movement -> "CLASS: SAFE_MOTION"
  Drop the board  -> "CLASS: FALL_DETECTED"
  Wrist flick     -> "CLASS: EMERGENCY_STOP"

### 3.4 Performance Verification (Hour 35-36)
Measure inference time using hardware timer:
  Target: Thermal CNN < 10ms, IMU CNN < 5ms
Print timing results over UART0.
OPERABILITY CHECK: Both targets met at 100MHz.

---

## Phase 4: Integration & Demo (Hours 36-48)

### 4.1 Main Application Loop (Hours 36-40)
Integrate all components:
  - Mode FSM driven by BTN0 GPIO interrupt
  - Sensor fusion in Defence mode (thermal CNN + BME680 temp > 30C)
  - MQTT alert on threat/fall/emergency detection
  - RGB LED shows mode: RED=Defence, GREEN=Industrial
  - Serial debug log for judging panel to verify operation

### 4.2 MQTT Dashboard on Laptop (Hours 40-43)
Python script using paho-mqtt library.
Subscribes to "guardian/#" topic.
Displays formatted alert messages with timestamps.
Shows which mode triggered the alert.

### 4.3 Final Demo Rehearsal (Hours 43-48)
End-to-end run through both modes.
5-minute demo script:
  Step 1: Boot board -> "VEGA-GUARDIAN" on serial, RED LED (Defence)
  Step 2: Wave hand over thermal camera -> MQTT THREAT alert on laptop
  Step 3: Press BTN0 -> LED turns GREEN (Industrial mode)
  Step 4: Drop the board (simulate fall) -> buzzer + MQTT FALL alert
  Step 5: Perform emergency stop gesture -> MQTT STOP alert

---

## Operability Verification Checklist

HARDWARE CONNECTIVITY
[ ] Board powers up, heartbeat LED blinks
[ ] UART0 serial debug works on laptop
[ ] BMI088: Accel/Gyro values print at 50Hz (Z ~9.8 m/s2 at rest)
[ ] MLX90640: 768-pixel temp grid prints, body shows as hot region
[ ] BME680: Temperature/humidity/pressure values print
[ ] NINA Wi-Fi: AT OK received, board connects to Wi-Fi network
[ ] MQTT: Laptop receives test message from board
[ ] BTN0: Mode switch fires, LED changes colour
[ ] Buzzer: Sounds on alert_trigger() call

DEFENCE MODE PIPELINE
[ ] Thermal frame normalizes correctly (background = cold INT8, body = warm INT8)
[ ] Conv2D layer 1 produces non-zero output
[ ] Conv2D layer 2 produces non-zero output
[ ] Human hand -> CLASS: HUMAN_THREAT (3 of 3 tests)
[ ] Hot cup    -> CLASS: NON_THREAT   (3 of 3 tests)
[ ] Empty room -> CLASS: BACKGROUND  (3 of 3 tests)
[ ] MQTT alert fires ONLY on HUMAN_THREAT + BME680 temp > 30C fusion

INDUSTRIAL MODE PIPELINE
[ ] IMU ring buffer fills correctly (50 samples x 6 axes)
[ ] Inference runs in < 5ms (verified with hardware timer)
[ ] Normal movement  -> CLASS: SAFE_MOTION      (3 of 3 tests)
[ ] Board drop       -> CLASS: FALL_DETECTED    (2 of 3 tests acceptable)
[ ] Emergency gesture-> CLASS: EMERGENCY_STOP   (3 of 3 tests)
[ ] Buzzer + LED alert + MQTT all fire together on detection

MODE SWITCHING
[ ] BTN0 cycles DEFENCE -> INDUSTRIAL -> DEFENCE cleanly
[ ] LED changes correctly each switch
[ ] Inactive sensor halts during switch
[ ] 10 successive switches: system remains stable, no crashes

---

## Risk Register & Mitigations

| Risk | Probability | Mitigation |
|---|---|---|
| MLX90640 not detected on I2C0 | Low | Switch to I2C1 (Header J1) |
| Model accuracy < 90% | Medium | Collect more data; reduce model depth |
| SRAM overflow | Low | Reduce conv filters; offload activations |
| Wi-Fi unstable | Medium | Use BT UART as fallback alert |
| BMI088 SPI timing issue | Low | Reduce SPI clock to 1MHz for debug |

---

## Bill of Materials (External Components)

| Component | Purpose | Est. Cost | Source |
|---|---|---|---|
| MLX90640 Thermal Camera | Defence thermal sensing | Rs.2500-3500 | Robu.in / Amazon |
| Jumper wires (F-F, 4pcs) | I2C0 Header J10 wiring | Rs.50 | Electronics store |
| USB-C cable | Programming + power | Rs.150 | Any store |
| TOTAL | | Rs.2700-3700 | |

All other components (BMI088 IMU, NINA Wi-Fi, BME680, RGB LED,
Buzzer, Push Buttons) are already built into the ARIES IoT v2.0 board.


---

## Memory Specification Reference

Board SRAM: 256 KB (262,144 bytes)
Board Flash: 2 MB (2,097,152 bytes)

SRAM Budget Summary (one active mode at a time):
  Active CNN weights loaded from Flash : ~60 KB
  Activation scratchpad buffers        : ~18 KB
  SDK + code + stack                   : ~50 KB
  Sensor frame buffers                 : ~3 KB
  Wi-Fi AT command buffers             : ~4 KB
  Misc variables                       : ~10 KB
  TOTAL USED                           : ~145 KB / 256 KB  (56% utilization)
  HEADROOM                             : ~111 KB

Flash Budget Summary:
  Application firmware                 : ~200 KB
  Defence CNN weights (INT8)           : ~80 KB
  Industrial CNN weights (INT8)        : ~50 KB
  TOTAL USED                           : ~330 KB / 2048 KB (16% utilization)
  HEADROOM                             : ~1.7 MB

Both models fit comfortably. Weights stored in 2 MB Flash,
only active mode weights loaded to 256 KB SRAM at runtime.

