# VEGATHON Project Abstract: Edge AI for Real-Time Decision Making

## Project Title
**VEGA-GUARDIAN: A Dual-Mode Adaptive Edge AI System for Defence & Industrial Safety**

---

## 1. The Problem
Two critical real-world domains — **Defence perimeter security** and **Industrial worker safety** — both demand the same core capability: a system that can perceive its environment, make an intelligent real-time decision, and act upon it, without relying on cloud connectivity or a high-power processor.

Existing solutions fail because they either:
1. Stream raw sensor data to a server, introducing latency and requiring constant connectivity.
2. Use cloud-based AI, making them vulnerable to communication jamming or failure.
3. Require expensive, power-hungry hardware.

There is no single platform that can serve **both domains** with a shared sensor stack, dynamically switching its intelligence role on demand.

---

## 2. The Solution
**VEGA-GUARDIAN** is a unified, dual-mode Edge AI device built entirely on the VEGA ARIES IoT v2.0 board. It runs two fully distinct AI inference pipelines that share the same sensor hardware. A single **physical toggle switch** on the board's GPIO pins selects the active mode at runtime.

### Mode A — DEFENCE Mode 🛡️ (SentryVision)
The device acts as an autonomous, intelligent perimeter tripwire.
- A low-resolution thermal camera (MLX90640, 32×24) streams thermal frames over I2C.
- A lightweight quantized CNN processes the 768-pixel thermal array directly on the VEGA RISC-V processor.
- The AI classifies the thermal signature in real-time as: **Intruder (Human) / Vehicle / Non-Threat / Background**.
- The onboard IMU (6-axis accelerometer + gyroscope) acts as a secondary **seismic sensor** to corroborate the detection via ground vibration signatures (footsteps vs. vehicle rumble).
- **Sensor Fusion Decision:** A threat is only confirmed when BOTH the thermal classification AND the seismic pattern agree. This eliminates false positives from animals or weather.
- Upon confirmed threat: Broadcasts a silent, encrypted MQTT alert with threat class over Wi-Fi to a Command Dashboard.

### Mode B — NORMAL (Industrial Safety) Mode 🏭 (MotionEdge)
The device acts as a wearable safety monitor for workers.
- The onboard IMU continuously streams accelerometer + gyroscope data.
- A separate quantized 1D-CNN inference pipeline processes the time-series motion data.
- The AI classifies the motion in real-time as: **Fall Detected / Emergency Stop Gesture / Safe Operation**.
- The thermal camera optionally monitors the ambient temperature of the workspace for heat hazard detection.
- Upon detection: Triggers an immediate local alarm (buzzer/LED) AND sends a safety alert over Wi-Fi/Bluetooth to a supervisor dashboard.

---

## 3. Shared Hardware Architecture (Why It's Elegant)
Both modes share the **exact same hardware**, making this a single, deployable unit:

| Hardware Component | Defence Mode Use | Industrial Safety Mode Use |
|---|---|---|
| VEGA ARIES IoT v2.0 (VEGA ET1031 RISC-V) | Runs thermal CNN + seismic classifier | Runs fall/gesture 1D-CNN |
| Onboard 6-axis IMU (Accel + Gyro) | Seismic ground vibration sensor | Primary motion/gesture/fall sensor |
| MLX90640 Thermal Camera (I2C) | Thermal threat classification | Workspace heat hazard monitoring |
| u-blox NINA-W10 (Wi-Fi + BT) | Silent encrypted MQTT threat alert | Worker safety alert to supervisor |
| GPIO Toggle Switch | — | — |
| Onboard LEDs + Buzzer | Threat indicator | Fall alarm |

**One switch. Two AI pipelines. One board.**

---

## 4. AI/TinyML Implementation Plan
*   **Models:** Two separate lightweight quantized INT8 neural networks.
    *   **Defence:** A 2D-CNN for thermal image classification (input: 32×24×1).
    *   **Industrial:** A 1D-CNN for time-series IMU classification (input: 50-sample window × 6 axes).
*   **Optimization:** Leveraging expertise in hardware NPU design (systolic arrays, INT8 requantization), we will manually write highly optimized, cache-friendly `im2col` and depthwise convolution routines in C/C++ for the RISC-V VEGA core to maximize inference speed and minimize SRAM footprint (target: < 200KB total for both models).
*   **Mode Switch:** A simple GPIO interrupt handler swaps the active inference pipeline pointer and reconfigures the sensor polling routine.

---

## 5. Prototype Plan (48-Hour Execution)

| Phase | Duration | Task |
|---|---|---|
| **Phase 1: Foundation** | Hours 1-8 | VEGA SDK setup, I2C thermal camera driver, IMU driver, GPIO switch interrupt handler |
| **Phase 2: Data & Train** | Hours 8-20 | Collect thermal data (3 threat classes) + IMU data (fall, gestures). Train and quantize both CNNs to INT8 using TensorFlow Lite. Convert to C byte arrays. |
| **Phase 3: Deploy & Optimize** | Hours 20-36 | Flash both models onto the VEGA board. Write and optimize the C-level convolution inference loops. Validate accuracy of both pipelines independently. |
| **Phase 4: Integrate & Demo** | Hours 36-48 | Wire up the mode switch GPIO, build the MQTT Wi-Fi dashboard, integrate local alerts, and run a live end-to-end demonstration for both modes. |

---

## 6. Innovation Summary
- **First dual-mode adaptive Edge AI system** running two distinct inference pipelines on a single indigenous VEGA RISC-V board.
- **Sensor fusion** between thermal and IMU data eliminates false positives in Defence Mode.
- **Hardware-level software optimization** of the inference engine, inspired by NPU dataflow design principles.
- **Fully offline operation** — no cloud dependency. Decisions are made in milliseconds on-device.
- **Immediately deployable** to two of India's most critical sectors: Defence and Industrial Safety.
