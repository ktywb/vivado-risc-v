create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH        1024  [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER       true  [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL      true  [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU   true  [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 4   [get_debug_cores u_ila_0]

set ila_ [get_debug_cores u_ila_0]       ;
puts "INFO: Created ILA core: $ila_"
report_property $ila_                    ;

set sys_clk_net [get_nets -hier -filter {NAME =~ "*sys_clock*"}]

if {[llength $sys_clk_net] == 0} {
    puts "WARNING: no net matches *sys_clock*; skip clk binding."
} else {
    puts "INFO: got sys_clk_net: $sys_clk_net."
    # set_property PORT_WIDTH 1 [get_debug_ports u_ila_0/clk]
    # set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/clk]
    connect_debug_port u_ila_0/clk $sys_clk_net
}

set debug_nets [get_nets -hier -filter {NAME =~ "*DebugTag_*_DebugTag*"}]
if {[llength $debug_nets] == 0} {
    puts "WARNING: no *DebugTag_* nets found; ILA will have 0 probes."
} else {
    set len [llength $debug_nets]
    puts "INFO: got $len debug_nets."
    foreach n $debug_nets {
        set w [get_property WIDTH $n]
        set p [create_debug_port u_ila_0 probe]       ;
        if {$w eq ""} { set w 1 }                     ;
        if {$w > 1} { set_property PORT_WIDTH $w $p } ;
        connect_debug_port $p $n  ;
    }
}
delete_debug_port [get_debug_ports u_ila_0/probe0]

# foreach n $debug_nets {
#     connect_debug_port u_ila_0 [get_debug_ports u_ila_0/PROBE*] $n
# }

# report_debug_core             > debug_core.log

# implement_debug_core [get_debug_cores u_ila_0]
# write_debug_probes            debug_nets.ltx
# puts "INFO: inserted ILA u_ila_0 with [llength $debug_nets] probes."