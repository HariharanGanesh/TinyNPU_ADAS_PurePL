cd {D:/Final year project/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system}
open_project tinynpu_pynq_system.xpr
cd {D:/Final year project/Versions/tinynpu_pynq_system/constraints}
add_files -fileset constrs_1 -norecurse pynq_z2_pins.xdc
set_property target_constrs_file [file normalize pynq_z2_pins.xdc] [current_fileset -constrset]
cd {D:/Final year project/Vivado/tinynpu_pynq_system_project/tinynpu_pynq_system}
save_project_as -force tinynpu_pynq_system .
close_project
