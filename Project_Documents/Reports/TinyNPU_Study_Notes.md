# TinyNPU Hackathon Study Notes: A-Z Reference Guide

This document contains everything you need to know to defend the **TinyNPU** project during the DEEPSPRINT Hackathon. Study these concepts to confidently answer questions from technical judges, professors, and investors.

---

## 1. Core Architecture Concepts

### What is TinyNPU?
TinyNPU is a custom Neural Processing Unit (hardware accelerator) designed specifically for edge AI inference. 
*   **The Big Differentiator:** It is designed **100% in Programmable Logic (PL)**.
*   **Board-Agnostic:** Because it doesn't rely on a hard processor (like an ARM Cortex core inside a Zynq chip), the exact same IP block can be synthesized on a Xilinx FPGA, an Intel FPGA, or fabricated as an ASIC. 

### PS (Processing System) vs. PL (Programmable Logic)
*   **PS (Processing System):** The hard silicon CPU (usually ARM) inside an SoC FPGA. It runs operating systems (Linux), handles general-purpose tasks, but suffers from software overhead and latency jitter.
*   **PL (Programmable Logic):** The FPGA fabric itself (LUTs, FFs, DSPs, BRAM). TinyNPU runs entirely here. It executes instructions in parallel, deterministically, on every clock cycle.

---

## 2. Technical Deep Dive (VLSI & FPGA)

### Memory Management (Without a PS)
Since there is no PS to run Linux and manage DDR RAM natively, how does TinyNPU handle memory?
*   **Answer:** We utilize **Block RAM (BRAM)** and **UltraRAM (URAM)** inside the FPGA fabric to cache weights and activations locally. For external memory access, we use standard AXI-Stream interfaces or a PL-based memory controller.

### Quantization & Arithmetic
*   TinyNPU does not use Floating-Point (FP32) math because it requires too much power and area.
*   Instead, we use **INT8 Quantization**. We convert neural network weights from decimals to 8-bit integers. 
*   This allows us to utilize the FPGA's built-in **DSP Slices (Digital Signal Processors)** highly efficiently to perform thousands of MAC (Multiply-Accumulate) operations per clock cycle.

---

## 3. Defense & Space Applicability (Why it wins)

### SWaP-C (Size, Weight, Power, and Cost)
The military evaluates all edge hardware on SWaP. TinyNPU excels here because a custom PL architecture eliminates the power-hungry CPU/GPU overhead, drastically lowering power consumption while maintaining real-time inference.

### Determinism (Zero-Jitter)
*   **The Problem:** An AI drone running Linux on a GPU might take 10ms to detect a target, but sometimes an OS background task causes a "hiccup" making it take 50ms (latency jitter). At Mach 2, that jitter means missing a target.
*   **The Solution:** TinyNPU is purely hardware (PL). A clock cycle is exactly the same every single time. Inference takes the exact same number of nanoseconds, guaranteeing **deterministic execution**.

---

## 4. Expected Evaluator Questions & Answers

### A. Technical / Engineering Questions

**Q1: "Why not just use a Raspberry Pi or NVIDIA Jetson? It's much easier."**
> **A:** GPUs and general CPUs are power-hungry and suffer from OS-level latency jitter. In defense and critical robotics, we need strict deterministic execution and ultra-low SWaP (Size, Weight, and Power). TinyNPU provides bare-metal hardware acceleration without the bloat of an operating system.

**Q2: "Xilinx already has the DPU (Deep Learning Processor Unit). Why build your own NPU?"**
> **A:** The standard Xilinx DPU is heavily dependent on the Zynq Processing System (PS). It requires an ARM core running PetaLinux just to boot and schedule tasks. TinyNPU is 100% PL-based, meaning it is truly board-agnostic. It can be integrated into custom defense ASICs or cheaper, non-SoC FPGAs where standard DPUs cannot function.

**Q3: "How are you handling the hardware-software interface if everything is in the PL?"**
> **A:** We use standard AXI4 and AXI-Stream protocols. Data is streamed directly into the NPU pipeline via PL memory controllers or custom soft-cores, completely bypassing the need for a hard CPU to act as a middleman.

**Q4: "What happens if a neural network model is larger than the FPGA's internal BRAM?"**
> **A:** The architecture relies on tiling and data reuse. We buffer a specific "tile" (chunk) of the image and weights into BRAM, compute the partial results, and stream the next chunk in from external memory via AXI.

### B. Business / Investor Questions

**Q5: "If defense contractors want this, wouldn't they just buy a dedicated AI chip from a big vendor?"**
> **A:** Defense contractors often build highly classified, custom SoCs (System on Chips). They don't want to wire an external NVIDIA chip on their board; they want to buy the *IP block* (the RTL code) and embed it directly into their own silicon. Because TinyNPU is board-agnostic IP, we can license it directly to them for SoC integration.

**Q6: "What is your revenue model?"**
> **A:** B2B Semiconductor IP licensing. We sell the RTL/bitstream for an upfront license fee (e.g., $50,000), plus a small royalty fee per chip manufactured by the client, and charge NRE (Non-Recurring Engineering) fees for custom architectural tweaks.

**Q7: "What is your Technology Readiness Level (TRL)?"**
> **A:** We are currently at TRL 4 (Component validation in a lab environment). We have the RTL synthesized and validated on an FPGA board. Our next step is TRL 5, which involves integrating it into a full drone/target detection system environment.
