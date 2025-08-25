create_debug_core u_ila_0 ila
set_property C_DATA_DEPTH          8192  [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER         false [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL        false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU     true  [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1     [get_debug_cores u_ila_0]

set ila_ [get_debug_cores u_ila_0]       ;
set hub_ [get_debug_cores dbg_hub]       ;
puts "INFO: Created ILA core: $ila_"
report_property $ila_                    ;

set sys_clk_net [get_nets -hier -filter {NAME =~ "*AXI_clock*"}]

if {[llength $sys_clk_net] == 0} {
    puts "WARNING: no net matches *AXI_clock*; skip clk binding."
} else {
    puts "INFO: got sys_clk_net: $sys_clk_net."
    connect_debug_port u_ila_0/clk $sys_clk_net
    # connect_debug_port dbg_hub/clk $sys_clk_net
    # puts "Debug port connection: [get_property CLK [get_debug_cores u_ila_0]]"
}


# set debug_nets [get_nets -hier -filter {NAME =~ "*DebugTag_*_DebugTag*"}]
set debug_nets [get_nets -hier -filter {NAME =~ "*DebugTag_*_DebugTag*" && MARK_DEBUG == 1}]
if {[llength $debug_nets] == 0} {
    puts "WARNING: no DebugTag_* nets found; ILA will have 0 probes."
} else {
#======
    # set nets_raw [get_nets -hier -filter {NAME =~ "*DebugTag_*_DebugTag*"}]
    set nets_raw [get_nets -hier -filter {NAME =~ "*DebugTag_*_DebugTag*" && MARK_DEBUG == 1}]

    set filtered_nets {}
    foreach n $nets_raw {
        set name [get_property NAME $n]
        if {[regexp {(^|/)u_ila_} $name]} { continue }
        if {[regexp {(^|/)dbg_hub} $name]} { continue }
        lappend filtered_nets $n ;
    }

    array unset signal_map
    foreach n $filtered_nets {
        set name [get_property NAME $n]
        set leaf [lindex [split $name "/"] end]

        if {![info exists signal_map($leaf)]} {
            set signal_map($leaf) $n
        } else {
            set ex $signal_map($leaf)
            set ex_name [get_property NAME $ex]

            set score_n  [expr {![regexp {(^|/)u_ila_|(^|/)dbg_hub} $name] ? 2 : 0}]
            set score_ex [expr {![regexp {(^|/)u_ila_|(^|/)dbg_hub} $ex_name] ? 2 : 0}]
            set pick $ex
            if {$score_n > $score_ex} {
                set pick $n
            } elseif {$score_n == $score_ex} {
                set depth_n  [llength [split $name "/"]]
                set depth_ex [llength [split $ex_name "/"]]
                if {$depth_n < $depth_ex} {
                    set pick $n
                } elseif {$depth_n == $depth_ex} {
                    if {[string length $name] < [string length $ex_name]} {
                        set pick $n
                    }
                }
            }
            set signal_map($leaf) $pick
        }
    }

    set debug_nets {}
    foreach {leaf obj} [array get signal_map] {
        lappend debug_nets $obj  ;
    }

    set trigger_net debug_nets

#======

    set len [llength $debug_nets]
    puts "INFO: got $len debug_nets."
    # foreach n $debug_nets {
    #     set name [get_property NAME  $n]
    #     set w [get_property WIDTH $n]
    #     set p [create_debug_port u_ila_0 probe]       ;
    #     if {$w eq ""} { set w 1 }                     ;
    #     if {$w > 1} { set_property PORT_WIDTH $w $p } ;

    #     connect_debug_port $p $n  ;

    #     if {[regexp {DebugTag_FLAG_.*_FLAG_DebugTag} $name]} {
    #         set_property PROBE_TYPE DATA_AND_TRIGGER $p
    #         puts "INFO: trigger probe: $name"
    #     } else {
    #         set_property PROBE_TYPE DATA $p
    #     }
    # }

    array unset bus_bits
    foreach n $debug_nets {
        set name [get_property NAME $n]
        if {[regexp {^(.*)\[(\d+)\]$} $name -> base idx]} {
            lappend bus_bits($base) [list $idx $n]
        } else {
            lappend bus_bits($name) [list 0 $n]
        }
    }

    set total_probes 0
    set trigger_cnt  0
    foreach base [lsort [array names bus_bits]] {
    set pairs $bus_bits($base)
    set pairs [lsort -integer -index 0 $pairs]   ;# -decreasing

    set nets_ordered {}
    foreach pair $pairs {
        lappend nets_ordered [lindex $pair 1]
    }
    set width [llength $nets_ordered]

    set p [create_debug_port u_ila_0 probe]
    if {$width > 1} { set_property PORT_WIDTH $width $p }
    connect_debug_port $p $nets_ordered

    if {[regexp {DebugTag_FLAG_.*_FLAG_DebugTag} $base]} {
        set_property PROBE_TYPE DATA_AND_TRIGGER $p
        incr trigger_cnt
        puts "INFO: trigger probe: $base (width=$width)"
    } else {
        set_property PROBE_TYPE DATA $p
    }

    incr total_probes
    }
    puts "INFO: created $total_probes probes; triggers: $trigger_cnt; data-only: [expr {$total_probes - $trigger_cnt}]"
}
delete_debug_port [get_debug_ports u_ila_0/probe0]

puts "INFO: insert_ila.tcl END"

# foreach ip [get_ips -filter {STATUS =~ *STALE*}] {refresh_module_reference $ip}
# generate_target {all} [get_ips -filter {STATUS =~ *STALE*}]
# save_project_as [get_property NAME [current_project]] . -force

# foreach n $debug_nets {
#     connect_debug_port u_ila_0 [get_debug_ports u_ila_0/PROBE*] $n
# }

# report_debug_core             > debug_core.log

# implement_debug_core [get_debug_cores u_ila_0]
# write_debug_probes            debug_nets.ltx
# puts "INFO: inserted ILA u_ila_0 with [llength $debug_nets] probes."