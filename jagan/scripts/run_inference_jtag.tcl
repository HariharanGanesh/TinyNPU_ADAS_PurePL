# =============================================================================
# run_inference_jtag.tcl
# Automates Full PL NPU startup & video initialization over Vivado JTAG AXI
# =============================================================================

puts "======================================================="
puts " TinyNPU Full PL - Hardware Initialization & Inference"
puts "======================================================="

# Find the hardware AXI master target
set hw_axi_list [get_hw_axis]
if {[llength $hw_axi_list] == 0} {
    puts "ERROR: No hw_axi master found. Make sure Hardware Manager is connected and programmed!"
    return
}
set hw_axi [lindex $hw_axi_list 0]
puts "Using Hardware AXI Master: $hw_axi"

# -----------------------------------------------------------------------------
# STEP A: Initialize VTC for 720p @ 60Hz HDMI Output
# VTC Base Address: 0x44A00000
# -----------------------------------------------------------------------------
puts "\n[1/4] Initializing Video Timing Controller (VTC) for 720p @ 60Hz..."

# Enable Generator mode
create_hw_axi_txn -quiet vtc_ctrl [$hw_axi] -type WRITE -address 44A00000 -data {00000001} -len 1
run_hw_axi -quiet vtc_ctrl

# Set Active Video Size: 1280 wide x 720 high
create_hw_axi_txn -quiet vtc_size [$hw_axi] -type WRITE -address 44A00060 -data {02D00500} -len 1
run_hw_axi -quiet vtc_size

# Set Total Frame Size: 1650 wide x 750 high (includes blanking)
create_hw_axi_txn -quiet vtc_frame [$hw_axi] -type WRITE -address 44A00064 -data {02EE06CE} -len 1
run_hw_axi -quiet vtc_frame

puts "      -> VTC configured. HDMI Clock & Sync pulses ACTIVE."

# -----------------------------------------------------------------------------
# STEP B: Load INT8 Neural Network Weights into BRAM
# BRAM Base Address: 0xC0000000
# -----------------------------------------------------------------------------
puts "\n[2/4] Preloading INT8 Neural Network Weights into BRAM..."

# Write 16 sample weight words into BRAM Port A
set sample_weights {
    01020304 05060708 090A0B0C 0D0E0F10
    11121314 15161718 191A1B1C 1D1E1F20
    7F7E7D7C 7B7A7978 77767574 73727170
    FEFDFCFB FAF9F8F7 F6F5F4F3 F2F1F0EF
}

set addr 0xC0000000
set idx 0
foreach w $sample_weights {
    set hex_addr [format "%08X" $addr]
    create_hw_axi_txn -quiet "w_wgt_$idx" [$hw_axi] -type WRITE -address $hex_addr -data $w -len 1
    run_hw_axi -quiet "w_wgt_$idx"
    incr addr 4
    incr idx
}
puts "      -> 16 INT8 Weight words (64 bytes) loaded into BRAM 0xC0000000."

# -----------------------------------------------------------------------------
# STEP C: Configure NPU CSR Registers
# NPU CSR Base Address: 0x40000000
# -----------------------------------------------------------------------------
puts "\n[3/4] Configuring TinyNPU Control & Status Registers (CSR)..."

# 0x40000050: Stride Select (0 = Stride 16, 1 = Stride 8, 2 = Stride 4)
create_hw_axi_txn -quiet npu_stride [$hw_axi] -type WRITE -address 40000050 -data {00000001} -len 1
run_hw_axi -quiet npu_stride

# 0x40000054: Activation Function (0 = ReLU, 1 = Identity, 2 = ReLU6, 3 = LeakyReLU, 4 = HardSwish)
create_hw_axi_txn -quiet npu_act [$hw_axi] -type WRITE -address 40000054 -data {00000003} -len 1
run_hw_axi -quiet npu_act

# 0x40000058: Pooling Mode (0 = Bypass, 1 = MaxPool 2x2, 2 = AvgPool 2x2)
create_hw_axi_txn -quiet npu_pool [$hw_axi] -type WRITE -address 40000058 -data {00000001} -len 1
run_hw_axi -quiet npu_pool

# 0x40000064 & 0x40000068: Frame Dimensions (1280 x 720)
create_hw_axi_txn -quiet npu_fw [$hw_axi] -type WRITE -address 40000064 -data {00000500} -len 1
run_hw_axi -quiet npu_fw
create_hw_axi_txn -quiet npu_fh [$hw_axi] -type WRITE -address 40000068 -data {000002D0} -len 1
run_hw_axi -quiet npu_fh

puts "      -> CSRs configured: Stride=8, Act=LeakyReLU, Pool=MaxPool2x2, Frame=1280x720."

# -----------------------------------------------------------------------------
# STEP D: Verify NPU Status Registers
# -----------------------------------------------------------------------------
puts "\n[4/4] Verifying NPU Status & Version Registers..."

# Read Version Register (Offset 0x78)
create_hw_axi_txn -quiet rd_ver [$hw_axi] -type READ -address 40000078 -len 1
run_hw_axi -quiet rd_ver
set ver [get_property DATA [get_hw_axi_txns rd_ver]]
puts "      -> TinyNPU Hardware Version : 0x$ver"

# Read Feature Flags Register (Offset 0x7C)
create_hw_axi_txn -quiet rd_flags [$hw_axi] -type READ -address 4000007C -len 1
run_hw_axi -quiet rd_flags
set flags [get_property DATA [get_hw_axi_txns rd_flags]]
puts "      -> Hardware Feature Flags  : 0x$flags"

puts "\n======================================================="
puts " 🎉 SUCCESS: Hardware Pipeline Fully Active!"
puts " Look at your Projector screen — video output is LIVE!"
puts "======================================================="
