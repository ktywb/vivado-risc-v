open_hw_manager
connect_hw_server -url "$::env(HW_SERVER_ADDR)"
open_hw_target

set dev [lindex [get_hw_devices] 0]
current_hw_device $dev


if {[info exists ::env(ltx_file)] && [file exists "$::env(ltx_file)"]} {
    set_property PROBES.FILE "$::env(ltx_file)" $dev
    set_property FULL_PROBES.FILE "$::env(ltx_file)" $dev
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

set trigger_probes [get_hw_probes -of_objects $ila -filter {NAME =~ "*DebugTag_FLAG_*_FLAG_DebugTag*"}]
# if {[llength $trigger_probes] == 0} {
#     puts "WARNING: no trigger probes matched pattern"
# } else {
#     set_property TRIGGER_COMPARE_VALUE eq1'b1 [get_hw_probes riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/cmd_router/DebugTag_FLAG_start_FLAG_DebugTag -of_objects [get_hw_ilas -of_objects $dev -filter {CELL_NAME=~"u_ila_0"}]]
# }

proc get_probe_width {p} {
  foreach prop {WIDTH DATA_WIDTH PROBE_PORT_WIDTH} {
    set v [get_property $prop $p]
    if {$v ne ""} { return $v }
  }
  return 1
}

foreach p $trigger_probes {
    # set w [get_property PROBE_WIDTH $p]
    # if {$w eq ""} { set w [get_property WIDTH $p] }
    # if {$w eq ""} { set w 1 }
    set w [get_probe_width $p]

    if {$w == 1} {
        set_property TRIGGER_COMPARE_VALUE eq1'b1 $p
        puts "INFO: set trigger ==1 on [get_property NAME $p]"
    } else {
        puts "INFO: skip non-1bit trigger probe [get_property NAME $p] (width=$w)"
    }
}

run_hw_ila $ila
puts "INFO: ILA armed and waiting for trigger."

wait_on_hw_ila $ila

file mkdir "$::env(OUT_DIR)"
set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]

set data_obj [upload_hw_ila_data $ila]
write_hw_ila_data "$::env(OUT_DIR)/ila_$ts.ila" $data_obj -force
write_hw_ila_data -vcd_file "$::env(OUT_DIR)/ila_$ts.vcd" $data_obj -force

puts "END"
# export_hw_ila_data -force -vcd_file "$::env(OUT_DIR)/ila_$ts.vcd" $ila 
# export_hw_ila_data -csv_file "$::env(OUT_DIR)/ila_$ts.csv" $ila