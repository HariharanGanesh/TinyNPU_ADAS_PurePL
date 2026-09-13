# =============================================================================
# firmware.s - PicoRV32 ADAS Firmware (Full ADAS Loop)
# Project: RISCV_ADAS_NPU300
#
# Memory Map:
#   0x00000000 : 4KB PicoRV32 BRAM (This firmware)
#   0x40000000 : TinyNPU CSRs
#       +0x00  : CTRL     - Write 1 to start, bit1=reset
#       +0x04  : STATUS   - bit0=Busy, bit1=Done, bit2=Error
#       +0x08  : WT_BASE  - Weight ROM base address
#       +0x0C  : ACT_BASE - Activation RAM base address
#       +0x10  : OUT_BASE - Output buffer base address
#   0x42000000 : Internal ADAS Registers (sensor_fusion inputs)
#       +0x00  : reg_detections - bit0=ped, bit1=obs, bit2=lane, bit3=sign
#       +0x04  : reg_configs    - bit0=ped_en, bit1=obs_en, bit2=lane_en
#       +0x08  : reg_wdt_pet    - Write anything to pet the watchdog
#   0x48000000 : NPU Weights ROM
#   0x4A000000 : NPU Activation RAM (input frame)
#   0x4C000000 : NPU Output RAM (16x16 heatmap = 256 bytes)
#
# Detection Threshold: 64 (0x40) - 25% of max INT8.
# After real model training, raise to ~180 for high-confidence only.
# =============================================================================

init:
    # Load all base addresses into dedicated registers
    li x3, 0x40000000      # x3 = NPU CSR base
    li x4, 0x42000000      # x4 = ADAS registers base
    li x5, 0x48000000      # x5 = Weights ROM base
    li x6, 0x4A000000      # x6 = Activation RAM base
    li x7, 0x4C000000      # x7 = NPU Output RAM base

    # Configure NPU - write base addresses into NPU CSRs
    sw x5, 8(x3)           # NPU_CSR[8]  = weight base
    sw x6, 12(x3)          # NPU_CSR[12] = activation base
    sw x7, 16(x3)          # NPU_CSR[16] = output base

    # Configure ADAS - enable all detection channels
    # reg_configs = 0x07 => ped_en=1, obs_en=1, lane_en=1
    li x8, 0x07
    sw x8, 4(x4)

adas_loop:
    # Pet the Watchdog (prevents safety_unit system_fault)
    li x8, 0x5A5A5A5A
    li x14, 0x42000008
    sw x8, 0(x14)

    # Reset NPU state machine (clear previous Done flag)
    li x8, 2
    sw x8, 0(x3)
    li x8, 0
    sw x8, 0(x3)

    # Start NPU inference
    li x8, 1
    sw x8, 0(x3)

wait_npu:
    # Poll STATUS register until Done (bit1) is set
    lw x8, 4(x3)
    li x9, 2
    bne x8, x9, wait_npu

    # Scan the 16x16 heatmap (64 words = 256 bytes)
    # Read word-by-word. If any word != 0, a car was detected.
    li x12, 0              # loop counter
    li x7, 0x4C000000      # reset output pointer to heatmap start

scan_loop:
    lw x13, 0(x7)          # load 4 bytes of heatmap
    bne x13, x0, car_found # if nonzero activation exists -> car detected
    addi x7, x7, 4         # advance to next word
    addi x12, x12, 1       # i++
    li x8, 64              # 64 words total (256 bytes)
    bne x12, x8, scan_loop # continue scanning

    # No car detected - clear detections register
    sw x0, 0(x4)
    j adas_loop

car_found:
    # Car (obstacle) detected!
    # Write obs_detected=1 to reg_detections (bit1)
    # sensor_fusion.v will raise emergency_trigger if hazard_score >= 3
    li x10, 0x0F
    sw x10, 0(x4)
    j adas_loop
