open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
puts "Resetting synthesis run..."
reset_run synth_1
puts "Launching synthesis..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1
puts "Synthesis completed!"