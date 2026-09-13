open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"

# Open the parent block design first - required before touching nested IPs
open_bd_design [get_files npu_system.bd]

# Reset both conflicting HDMI IPs from within their parent BD context
reset_target all [get_ips npu_system_dvi2rgb_0_0]
reset_target all [get_ips npu_system_rgb2dvi_0_0]

# Regenerate cleanly
generate_target all [get_ips npu_system_dvi2rgb_0_0]
generate_target all [get_ips npu_system_rgb2dvi_0_0]

# Sync the IP user files
export_ip_user_files -of_objects [get_ips npu_system_dvi2rgb_0_0] -no_script -sync -force -quiet
export_ip_user_files -of_objects [get_ips npu_system_rgb2dvi_0_0] -no_script -sync -force -quiet

puts "--- HDMI IP Regeneration Complete ---"
