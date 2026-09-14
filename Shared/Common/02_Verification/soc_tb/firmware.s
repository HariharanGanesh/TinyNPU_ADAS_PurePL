# firmware.s - PicoRV32 ADAS Safety Controller Firmware
# Memory Map:
# 0x00000000 : PicoRV32 BRAM
# 0x40000000 : NPU CSRs
# 0x42000000 : Hardware Watchdog
# 0x48000000 : NPU Weights ROM
# 0x4A000000 : NPU Activation RAM
# 0x4C000000 : NPU Output RAM

init:
    # Set up NPU CSR pointers
    li x1, 0x40000000      # NPU CSR Base Address
    
    # Configure Layer parameters (like tb_redteam_top)
    # ADDR_LAYER_CFG0 (0x14) = {2'd0, padding(6), stride(8), kernel_size(8), act_sel(2), soft_reset(1), start(1)}
    # Let's set padding=0, stride=1, kernel_size=8, act_sel=0 (Relu), soft_reset=0, start=0
    # 0x14: 0x0000_0108 -> actually 0x00000108? 
    li x2, 0x00000108
    sw x2, 20(x1)          # 0x14 = 20
    
    # ADDR_LAYER_CFG1 (0x18) = {out_channels(16), in_channels(16)}
    # Let's set out=1, in=1 -> 0x00010001
    li x2, 0x00010001
    sw x2, 24(x1)          # 0x18 = 24
    
    # ADDR_LAYER_CFG2 (0x1C) = {input_height(16), input_width(16)}
    # Let's set H=8, W=8 -> 0x00080008
    li x2, 0x00080008
    sw x2, 28(x1)          # 0x1C = 28
    
    # ADDR_CONF_THRESHOLD (0x48)
    li x2, 0
    sw x2, 72(x1)          # 0x48 = 72
    
    # Write Weight Base Address
    li x2, 0x48000000
    sw x2, 8(x1)
    
    # Write Activation Base Address
    li x2, 0x4A000000
    sw x2, 12(x1)
    
    # Write Output Base Address
    li x2, 0x4C000000
    sw x2, 16(x1)
    
    # Trigger NPU Start (Ctrl reg, bit 0=1)
    li x2, 1
    sw x2, 0(x1)

    # Watchdog configuration
    li x3, 0x42000000      # Watchdog Base Address
    li x4, 0x5A5A5A5A      # Watchdog Magic Word

safety_loop:
    # Pet the watchdog to prevent hardware brake lock
    sw x4, 0(x3)
    
    # Wait for NPU Done
    # Read status from 0x04
    lw x5, 4(x1)
    andi x5, x5, 2         # Check bit 1 (done)
    beqz x5, safety_loop   # If not done, loop and pet watchdog
    
    # NPU is done! Wait forever.
done_loop:
    sw x4, 0(x3)
    j done_loop
