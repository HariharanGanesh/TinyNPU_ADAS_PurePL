open_project "vivado_project/tinynpu_v3.xpr"
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]
puts "Successfully configured synth_1 for Out-Of-Context mode."
