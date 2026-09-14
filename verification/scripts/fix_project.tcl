open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr

# Fix missing XDC file
remove_files -quiet "D:/Final year project/pynq_z2_customized.xdc"
add_files -fileset constrs_1 -norecurse constraints/pynq_z2_customized.xdc

# Fix missing dummy_weights.hex
add_files -norecurse IP/TinyNPU200/src/dummy_weights.hex
set_property FILE_TYPE {Memory Initialization Files} [get_files IP/TinyNPU200/src/dummy_weights.hex]

# Re-run syntax check if needed, but we just save
update_compile_order