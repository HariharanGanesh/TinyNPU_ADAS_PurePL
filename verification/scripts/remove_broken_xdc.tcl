open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
set cset [current_fileset -constr]
set file_objs [get_files -of_objects [get_filesets $cset]]
foreach f $file_objs {
    if {[string match "*D:/Final year project/pynq_z2_customized.xdc*" $f]} {
        remove_files $f
        puts "Removed $f"
    }
}