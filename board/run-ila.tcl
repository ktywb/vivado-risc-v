open_hw_manager
connect_hw_server -url "$::env(HW_SERVER_ADDR)"
open_hw_target

set dev [lindex [get_hw_devices] 0]
current_hw_device $dev

set trigger_position 7168

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

set_property CONTROL.TRIGGER_POSITION $trigger_position $ila


if {[info exists ::env(wcfg_file)] && [file exists "$::env(wcfg_file)"]} {
    open_wave_config "$::env(wcfg_file)"
} else {
    puts "WARNING: wcfg_file not set or not found; probes mapping will be missing."
}

# 从环境变量读取触发信号编号，默认为1
if {[info exists ::env(TRIGGER_NUM)]} {
    set trigger_num $::env(TRIGGER_NUM)
} else {
    set trigger_num "1"
}
puts "INFO: Using trigger pattern: *DebugTag_${trigger_num}FLAG_*_FLAG${trigger_num}_DebugTag*"

set trigger_probes [get_hw_probes -of_objects $ila -filter "NAME =~ \"*DebugTag_${trigger_num}FLAG_*_FLAG${trigger_num}_DebugTag*\""]
if {[llength $trigger_probes] == 0} {
    puts "WARNING: no trigger probes matched pattern for TRIGGER_NUM=$trigger_num"
}

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
puts "Write ila file to : "
puts "        $::env(OUT_DIR)/ila_$ts.ila"

write_hw_ila_data -vcd_file "$::env(OUT_DIR)/ila_$ts.vcd" $data_obj -force
puts "Write vcd file to : "
puts "        $::env(OUT_DIR)/ila_$ts.vcd"

puts "END"
# export_hw_ila_data -force -vcd_file "$::env(OUT_DIR)/ila_$ts.vcd" $ila 
# export_hw_ila_data -csv_file "$::env(OUT_DIR)/ila_$ts.csv" $ila
# 在生成 VCD 文件后进行后处理
set vcd_file "$::env(OUT_DIR)/ila_$ts.vcd"
puts "INFO: Post-processing VCD file to remove debug tags and long paths..."

# 读取 VCD 文件内容
set fp [open $vcd_file r]
set content [read $fp]
close $fp

# 使用 string map 删除指定字符串
set content [string map {
    "_DebugTag" ""
    "DebugTag_" ""
    "riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/" ""
} $content]

# 将处理后的内容写回文件
set fp [open $vcd_file w]
puts -nonewline $fp $content
close $fp

puts "INFO: VCD file cleaned: removed debug tags and simplified paths"