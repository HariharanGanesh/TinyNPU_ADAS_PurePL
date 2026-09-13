# =============================================================================
# package_ip.tcl — TinyNPU v2.0 IP Packager Script
# Target:  Vivado IP Catalog
#
# Usage:
#   vivado -mode batch -source package_ip.tcl
#
# Outputs:
#   ./ip_repo/tinynpu/  — Packaged IP Core ready for Block Design (BD)
# =============================================================================

set IP_DIR "./ip_repo/tinynpu"
set PART "xc7z020clg400-1"

# Clean up old IP directory if it exists
file delete -force $IP_DIR
file mkdir $IP_DIR

puts "INFO: Creating in-memory project for IP Packaging..."
create_project -in_memory -part $PART

# -----------------------------------------------
# Read all RTL source files
# -----------------------------------------------
set rtl_files [glob -nocomplain \
    rtl/activation/*.v   \
    rtl/axi/*.v          \
    rtl/buffers/*.v      \
    rtl/clocking/*.v     \
    rtl/control/*.v      \
    rtl/dma/*.v          \
    rtl/dw_engine/*.v    \
    rtl/pe/*.v           \
    rtl/pooling/*.v      \
    rtl/quantization/*.v \
    rtl/systolic_array/*.v \
    rtl/top/*.v          \
]
read_verilog -sv $rtl_files
puts "INFO: Read [llength $rtl_files] RTL files."

# Set the top module
set_property top tinynpu_top [current_fileset]
update_compile_order -fileset sources_1

# -----------------------------------------------
# Package the IP
# -----------------------------------------------
puts "INFO: Packaging IP..."
ipx::package_project -root_dir $IP_DIR -vendor "harih" -library "user" -taxonomy "/UserIP" -import_files

# Get the current core
set core [ipx::current_core]

# Set VLNV
set_property vendor harih [ipx::current_core]
set_property library user [ipx::current_core]
set_property name tinynpu_ip [ipx::current_core]
set_property version 2.1 [ipx::current_core]
set_property display_name "TinyNPU v2.1 Accelerator" [ipx::current_core]

# Ensure AXI interfaces are correctly mapped (Vivado auto-infers based on s_axi_ / m_axi_ naming)
# We just need to associate the clock with all the AXI interfaces
set clk_if [ipx::get_bus_interfaces clk -of_objects $core]

puts "INFO: Associating clock with AXI interfaces..."
set_property value "s_axi:m_axi:s_axis:m_axis" [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects $clk_if]

# Associate Reset
ipx::add_bus_parameter ASSOCIATED_RESET $clk_if
set_property value "rst_n" [ipx::get_bus_parameters ASSOCIATED_RESET -of_objects $clk_if]

# Save and close
ipx::update_checksums $core
ipx::save_core $core
close_project -delete

puts ""
puts "================================================================"
puts "  TinyNPU IP Packaging Complete!"
puts "  IP Location: $IP_DIR"
puts "  VLNV:        harih:user:tinynpu_top:2.0"
puts "  You can now add this IP repository to your Block Design."
puts "================================================================"
