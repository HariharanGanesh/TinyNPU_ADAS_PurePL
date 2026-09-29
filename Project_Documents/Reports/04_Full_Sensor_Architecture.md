> [!IMPORTANT]
> This document has been updated after hardware verification.
> THREE corrections applied:
> 1. APDS-9960 IR torch (850nm) detection REMOVED - UV-IR filter blocks 850nm physically
> 2. BME680 explosion shockwave detection REMOVED - sensor is wrong tool (too slow, IIR filtered)
> 3. MLX90640 frame rate corrected to 3-4 FPS (integer compensation required, no FPU)
> BLE AT commands corrected: use ESP-AT firmware (AT+BLESCAN) not u-connectXpress
> See 05_Verification_Report.md for full technical justification.

# VEGA-GUARDIAN: Complete Sensor Architecture
## Defence Mode with IFF + Industrial Mode (All Sensors Utilized)

---

## Complete Onboard Sensor Inventory & Roles

| Sensor | Interface | Defence Mode Role | Industrial Mode Role |
|---|---|---|---|
| MLX90640 (external) | I2C0 | Primary thermal threat classifier | Fall posture detection |
| BMI088 Accel+Gyro | SPI2 | Seismic footstep/vehicle detection + tamper | Ground impact corroboration |
| BME680 Gas/Humid/Pressure/Temp | I2C2 | Exhaust fumes + explosion shockwave | Gas/chemical hazard detection |
| APDS-9960 Proximity/Light/RGB/Gesture | I2C2 | IFF gesture + IR torch detect + close-range | Zone entry counting + proximity |
| Thermistor (Analog) | ADC CH0 | Secondary temp cross-validation | Electronics health monitoring |
| Potentiometer (Analog) | ADC CH1 | Operator sensitivity threshold knob | Alert zone radius adjustment |
| NINA-W10 BT 4.2 | UART2 | BLE IFF token scanner | N/A (Wi-Fi alerts only) |
| NINA-W10 Wi-Fi | UART2 | MQTT alert to command post | MQTT alert to supervisor |
| RGB LED | GPIO 22/23/24 | Threat level indicator | Zone status indicator |
| Buzzer | GPIO | Local alert siren | Fall/gas alarm |
| BTN0 (GPIO19) | GPIO | Mode switch | Mode switch |
| BTN1 (GPIO18) | GPIO | Manual override / all-clear | Manual reset |

---

## DEFENCE MODE: 5-Layer Multi-Modal IFF Architecture

```
LAYER 0: ENVIRONMENTAL BASELINE (Always running, 1Hz)
┌──────────────────────────────────────────────────────────┐
│ BME680   → Establish normal gas/humidity/pressure/temp   │
│ BMI088   → Establish seismic noise floor of environment  │
│ APDS-9960→ Establish ambient light baseline              │
│ Thermistor→ Cross-validate ambient temperature           │
│ Potentiometer → Read operator sensitivity setting (0-100%)│
└──────────────────────────────────────────────────────────┘
              (Any deviation from baseline → escalate)
                            │
                            ▼
LAYER 1: LONG-RANGE EARLY WARNING (Seismic + Chemical)
┌──────────────────────────────────────────────────────────┐
│ BMI088 ACCELEROMETER (Seismic):                          │
│   Footstep pulses @ ~2Hz    → Infantry approaching       │
│   Rapid pulses  @ ~4Hz      → Running / assault          │
│   Ultra-slow @ <0.5Hz       → Crawling infiltration      │
│   Continuous high-freq      → Vehicle / motor            │
│                                                          │
│ BMI088 GYROSCOPE:                                        │
│   Structural resonance pattern → Vehicle weight on road  │
│   Large sudden rotation        → Station tamper attempt  │
│                                                          │
│ BME680 GAS SENSOR:                                       │
│   Diesel/petrol VOC spike   → Vehicle exhaust detected   │
│   Smoke/combustion products → Fire or weapon discharge   │
│                                                          │
│ BME680 PRESSURE:                                         │
│   Sudden pressure spike     → Explosion shockwave nearby │
│   Gradual pressure drop     → Weather change (low risk)  │
│                                                          │
│ APDS-9960 AMBIENT LIGHT:                                 │
│   Sudden light drop         → Object/person blocking sun │
│   IR channel spike          → Enemy night-vision torch   │
│   Rapid light flicker       → Movement across light path │
└──────────────────────────────────────────────────────────┘
              (Seismic OR Chemical trigger → activate Layer 2)
                            │
                            ▼
LAYER 2: VISUAL THREAT DETECTION (Thermal CNN)
┌──────────────────────────────────────────────────────────┐
│ MLX90640 THERMAL CAMERA (32x24):                         │
│                                                          │
│ CNN classifies thermal blob:                             │
│   Narrow vertical blob (~36C)  → HUMAN detected         │
│   Wide horizontal blob (>60C)  → VEHICLE detected       │
│   No blob / cold scene         → FALSE ALARM, reset     │
│                                                          │
│ Count blobs → single person vs. group                    │
│                                                          │
│ Thermistor cross-check:                                  │
│   If ambient temp > 40C (hot day), raise threshold       │
│   for thermal detection to reduce sun-heat false positives│
└──────────────────────────────────────────────────────────┘
              (HUMAN or VEHICLE confirmed → initiate IFF)
                            │
                            ▼
LAYER 3: IFF — IDENTIFICATION FRIEND OR FOE
┌──────────────────────────────────────────────────────────┐
│                                                          │
│ CHALLENGE 1: BLE TOKEN (NINA-W10 Bluetooth 4.2)         │
│   Scan for pre-shared UUID beacon (1 second window)     │
│   Friendly carries phone / BLE tag broadcasting UUID    │
│   UUID found → POSSIBLE FRIENDLY, go to Challenge 2     │
│   UUID not found → SUSPECTED HOSTILE                    │
│                                                          │
│ CHALLENGE 2: APDS-9960 GESTURE IFF                      │
│   System expects specific hand gesture within 5 seconds  │
│   (e.g., Left-Right-Left wave pattern)                  │
│   Gesture matched → FRIENDLY CONFIRMED                  │
│   Gesture missed  → HOSTILE CONFIRMED                   │
│                                                          │
│ CHALLENGE 3: APDS-9960 RGB COLOR MARKER                  │
│   Authorized personnel wear specific color patch         │
│   RGB sensor reads reflected color signature             │
│   Color match → additional friendly confidence          │
│                                                          │
│ IFF DECISION TABLE:                                      │
│   BLE✅ + Gesture✅ + Color✅ → FRIENDLY (3/3) PASS     │
│   BLE✅ + Gesture✅ + Color❌ → FRIENDLY (2/3) PASS     │
│   BLE✅ + Gesture❌ + Color❌ → SUSPICIOUS (1/3) WARN   │
│   BLE❌ + Gesture❌ + Color❌ → HOSTILE (0/3) ALERT     │
└──────────────────────────────────────────────────────────┘
                            │
              ┌─────────────┴─────────────┐
           FRIENDLY                    HOSTILE
              │                           │
              ▼                           ▼
LAYER 4: FRIENDLY CLEARED          THREAT CONFIRMED
┌───────────────────┐       ┌───────────────────────────┐
│ Log entry/exit    │       │ Seismic corroboration:    │
│ No alert          │       │ Footstep pattern matches  │
│ RGB LED: BLUE     │       │ human gait? (final check) │
│ (person cleared)  │       │         │                 │
└───────────────────┘       │ YES → HIGH CONFIDENCE    │
                            │         │                 │
                            │  BME680 check:            │
                            │  Gas/exhaust present?     │
                            │         │                 │
                            └─────────┼─────────────────┘
                                      │
                                      ▼
LAYER 5: ALERT ENGINE
┌──────────────────────────────────────────────────────────┐
│                                                          │
│ THREAT LEVEL CLASSIFICATION:                             │
│                                                          │
│ 🟡 CAUTION  (Layer 1 only, no visual confirmation)      │
│   RGB LED: YELLOW | No buzzer | MQTT: "MOTION DETECTED" │
│                                                          │
│ 🟠 WARNING  (Layer 2 confirmed, IFF inconclusive)       │
│   RGB LED: ORANGE | Slow buzzer | MQTT: "UNIDENTIFIED"  │
│                                                          │
│ 🔴 THREAT   (All layers, IFF FAILED)                    │
│   RGB LED: RED flash | Rapid buzzer | MQTT: "HOSTILE"   │
│   Seismic class included (INFANTRY / VEHICLE)           │
│                                                          │
│ ⚫ TAMPER   (Gyro detects station movement)              │
│   RGB LED: WHITE flash | Continuous buzzer              │
│   MQTT: "STATION COMPROMISED"                           │
│                                                          │
│ 💥 BLAST    (Pressure spike > threshold)                 │
│   All alerts simultaneously                             │
│   MQTT: "EXPLOSION DETECTED"                            │
└──────────────────────────────────────────────────────────┘
```

---

## Potentiometer — Operator Sensitivity Knob

This is a critical human-in-the-loop control. The ADC reads the
potentiometer (0V to 3.3V → 0 to 4095 raw ADC value) and maps it
to a sensitivity profile:

```
Potentiometer Position:
  0%  - 25%  : LOW SENSITIVITY
               Seismic threshold HIGH (vehicles only)
               Thermal: Only very close humans trigger
               Good for: Noisy environments, busy roads nearby

  25% - 60%  : MEDIUM SENSITIVITY (default)
               Seismic threshold MEDIUM (humans + vehicles)
               Thermal: Standard detection range
               Good for: Normal field deployment

  60% - 100% : HIGH SENSITIVITY
               Seismic threshold LOW (even crawling detected)
               Thermal: Maximum range, lower confidence required
               Good for: High-risk zones, quiet environments
```

```c
// Read sensitivity from potentiometer
uint16_t pot_raw = adc_read(ADC_CH1);          // 0-4095
float sensitivity = (float)pot_raw / 4095.0f;  // 0.0 - 1.0

// Map to seismic threshold
int seismic_threshold = 3000 - (int)(sensitivity * 2500); // 500-3000
// Map to thermal confidence required
float thermal_confidence = 0.9f - (sensitivity * 0.3f);   // 0.6-0.9
```

---

## Thermistor — Environmental Temperature Compensation

The thermistor provides an analog temperature reading independent
of BME680. This is used for:

1. Hot environment compensation:
   If ambient temp > 35C (desert/summer), thermal camera baseline
   shifts upward. The thermistor-measured ambient temp adjusts
   the CNN input normalization range dynamically.

2. BME680 cross-validation:
   If BME680 temp and thermistor temp differ by > 5C, flag
   sensor fault and raise maintenance alert.

```c
// Read thermistor (Steinhart-Hart equation simplified)
uint16_t therm_raw = adc_read(ADC_CH0);
float resistance = (4095.0f / therm_raw - 1.0f) * 10000.0f;
float temp_kelvin = 1.0f / (0.001129f + 0.000234f * log(resistance));
float ambient_temp_c = temp_kelvin - 273.15f;

// Adjust thermal normalization range based on ambient
float thermal_min = ambient_temp_c + 5.0f;   // Background
float thermal_max = ambient_temp_c + 20.0f;  // Human body
```

---

## APDS-9960 — Full 4-Mode Utilization

### Mode 1: Proximity (Last-Line Alert)
Detects physical presence < 1 metre from the station.
Even if all other systems are offline, proximity triggers local buzzer.

### Mode 2: Ambient Light (IR Torch Detection)
Night vision devices emit near-IR (850-950nm).
APDS-9960 IR channel spikes when an IR torch is pointed at it.
This detects enemies using night vision equipment.

```c
// Detect IR illumination (enemy night vision torch)
uint16_t ir_reading = apds9960_read_ir();
if (ir_reading > IR_BASELINE * 2.5f) {
    // IR torch detected — enemy may be using night vision
    raise_alert(ALERT_LEVEL_WARNING, "IR ILLUMINATION DETECTED");
}
```

### Mode 3: RGB Color (Friendly Color Marker IFF)
Authorized personnel wear a retro-reflective patch of a specific color
(e.g., a specific IR-reflective NATO marking or a color code).

```c
// Read RGB from APDS-9960
uint16_t r, g, b, c;
apds9960_read_color(&r, &g, &b, &c);
// Check for friendly color signature (pre-calibrated ratio)
float r_ratio = (float)r / c;
float b_ratio = (float)b / c;
bool friendly_color = (r_ratio > FRIENDLY_R_MIN && b_ratio < FRIENDLY_B_MAX);
```

### Mode 4: Gesture (Disarm Code)
Authorized personnel approaching can perform a pre-defined gesture
sequence to locally disarm the alert (e.g., Left-Right-Left).
This provides a silent, non-electronic disarm method.

```c
// Gesture sequence IFF: expects LEFT, RIGHT, LEFT within 5 seconds
GestureSequence expected[] = {GESTURE_LEFT, GESTURE_RIGHT, GESTURE_LEFT};
bool gesture_iff_pass = match_gesture_sequence(expected, 3, 5000);
```

---

## Seismic Classification (BMI088 in Detail)

The accelerometer data is analyzed using a sliding window FFT-lite
(implemented as a simple frequency bin counter in C without float FFT):

```
FOOTSTEP DETECTION:
  Peak detection in 1-3 Hz range → walking
  Peak detection in 3-5 Hz range → running
  Peak detection in 0.1-0.5 Hz range → crawling
  No peaks, DC offset shift → static load (person standing still)

VEHICLE DETECTION:
  Continuous energy in 10-50 Hz range → engine vibration
  Combined with periodic low-freq (wheel rotation) → moving vehicle
  High amplitude 10-50Hz + no footstep cadence → engine only (stationary vehicle)

EXPLOSION DETECTION:
  Single massive multi-axis spike > 5g → shockwave
  Followed by BME680 pressure spike → confirmed explosion

TAMPER DETECTION:
  GYROSCOPE angular rate > 10 deg/s → station being moved/rotated
  Triggers STATION COMPROMISED alert regardless of other states
```

---

## Complete Threat Intelligence Report (MQTT Payload)

When a threat is confirmed, the MQTT message includes ALL sensor data:

```json
{
  "alert_level": "THREAT",
  "threat_class": "INFANTRY",
  "iff_result": "HOSTILE",
  "iff_details": {
    "ble_token": false,
    "gesture_iff": false,
    "color_marker": false
  },
  "sensors": {
    "thermal_blobs": 2,
    "thermal_class": "HUMAN",
    "seismic_class": "FOOTSTEP_RUNNING",
    "seismic_amplitude_g": 1.8,
    "gas_voc_ppb": 145,
    "pressure_hpa": 1013.2,
    "ambient_temp_c": 28.4,
    "ir_illumination": true,
    "proximity_mm": 450,
    "operator_sensitivity": "HIGH"
  },
  "timestamp": "2026-09-11T14:32:05Z",
  "station_id": "GUARDIAN-ALPHA-01"
}
```

---

## Sensor Confidence Voting Table (Defence Mode)

Each sensor casts a vote. Final decision is weighted majority:

| Sensor | Weight | CAUTION | WARNING | THREAT |
|---|---|---|---|---|
| MLX90640 Thermal CNN | 30% | Blob detected | Human class | Human class confident |
| BMI088 Seismic (Accel) | 20% | Vibration present | Footstep pattern | Running/assault pattern |
| BME680 Gas | 15% | VOC trace | VOC elevated | Exhaust + combustion |
| APDS-9960 Proximity | 15% | Object nearby | Person-distance | Very close |
| BLE IFF | 10% | N/A | UUID not found | UUID absent |
| Gesture IFF | 5% | N/A | Gesture failed | Gesture absent |
| BME680 Pressure | 5% | Stable | Slight change | Spike (explosion) |

Weighted score > 0.40 → CAUTION (yellow LED)
Weighted score > 0.65 → WARNING (orange LED + MQTT)
Weighted score > 0.80 → THREAT (red LED + buzzer + MQTT)

