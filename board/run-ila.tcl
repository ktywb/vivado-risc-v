open_hw_manager
connect_hw_server -url "$::env(HW_SERVER_ADDR)"
open_hw_target

set dev [lindex [get_hw_devices] 0]
current_hw_device $dev


if {[info exists ::env(ltx_file)] && [file exists "$::env(ltx_file)"]} {
    set_property PROBES.FILE "$::env(ltx_file)" $dev
    refresh_hw_device -update_hw_probes true $dev
} else {
    puts "WARNING: ltx_file not set or not found; probes mapping will be missing."
}

set ila [lindex [get_hw_ilas] 0]
if {$ila eq ""} {
  puts "ERROR: No hw_ila cores found. Check that your design has ILA and LTX matches."
  return -code error
}


if {[info exists ::env(wcfg_file)] && [file exists "$::env(wcfg_file)"]} {
    open_wave_config "$::env(wcfg_file)"
} else {
    puts "WARNING: wcfg_file not set or not found; probes mapping will be missing."
}

run_hw_ila $ila
puts "INFO: ILA armed and waiting for trigger."

wait_on_hw_ila $ila

file mkdir "$::env(OUT_DIR)"
set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
export_hw_ila_data -force -vcd_file "$::env(OUT_DIR)/ila_$ts.vcd" $ila 
# export_hw_ila_data -csv_file "$::env(OUT_DIR)/ila_$ts.csv" $ila