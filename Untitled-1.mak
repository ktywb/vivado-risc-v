




riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_FLAG_start_FLAG_DebugTag riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[0] riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[1] riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[2] riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[3] riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[4] riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[5] riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[6] riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_partition_io_finish_DebugTag riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/streamer/DebugTag_busyReg_DebugTag riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/streamer/DebugTag_io_partition_ctrl_DebugTag riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/streamer/DebugTag_onebit_DebugTag riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/streamer/DebugTag_partition_io_finish_DebugTag riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/streamer/partition/DebugTag_started_r_DebugTag


set debug_nets "test/u_ila_0_test test/dbg_hub_test riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_FLAG_start_FLAG_DebugTag riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[0] riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[1] riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[2] riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[3] riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[4] riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[5] riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[6] riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_partition_io_finish_DebugTag riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/streamer/DebugTag_busyReg_DebugTag riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/streamer/DebugTag_io_partition_ctrl_DebugTag riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/streamer/DebugTag_onebit_DebugTag riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/streamer/DebugTag_partition_io_finish_DebugTag riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/streamer/partition/DebugTag_started_r_DebugTag"


set filtered_nets {}
foreach n $debug_nets {
    if {[regexp {(^|/)u_ila_} $n]} {continue}
    if {[regexp {(^|/)dbg_hub} $n]} {continue}
    lappend filtered_nets $n
}
set debug_nets $filtered_nets

# 2) 按叶子名去重（同名只留一个）
array set signal_map {}

foreach n $debug_nets {
    # 叶子名（最后一段），例如 .../DebugTag_func_DebugTag[0]
    set leaf [lindex [split $n "/"] end]

    if {![info exists signal_map($leaf)]} {
        set signal_map($leaf) $n
    } else {
        set existing $signal_map($leaf)

        # 优先级 1：非 ILA/Hub 胜出
        set n_is_ila   [regexp {(^|/)u_ila_} $n]
        set ex_is_ila  [regexp {(^|/)u_ila_} $existing]
        set n_is_hub   [regexp {(^|/)dbg_hub} $n]
        set ex_is_hub  [regexp {(^|/)dbg_hub} $existing]

        # 打分（分越高越好）：非 ILA/Hub=2，只有一个=1，同时有/都没有=0
        set score_n  [expr {( ! $n_is_ila && ! $n_is_hub ) ? 2 : ( ($n_is_ila || $n_is_hub) ? 0 : 1 )}]
        set score_ex [expr {( ! $ex_is_ila && ! $ex_is_hub) ? 2 : ( ($ex_is_ila|| $ex_is_hub) ? 0 : 1 )}]

        set pick $existing
        if {$score_n > $score_ex} {
            set pick $n
        } elseif {$score_n == $score_ex} {
            # 优先级 2：层级更浅的胜（路径段数更少）
            set depth_n  [llength [split $n "/"]]
            set depth_ex [llength [split $existing "/"]]
            if {$depth_n < $depth_ex} {
                set pick $n
            } elseif {$depth_n == $depth_ex} {
                # 优先级 3：字符串更短的胜
                if {[string length $n] < [string length $existing]} {
                    set pick $n
                }
            }
        }

        if {$pick ne $existing} {
            puts "INFO: Replaced $existing with $pick"
            set signal_map($leaf) $pick
        } else {
            puts "INFO: Kept $existing over $n"
        }
    }
}

# 3) 回写 debug_nets（顺序非确定）
set debug_nets {}
foreach {leaf net} [array get signal_map] {
    lappend debug_nets $net
}
ERROR: [Common 17-161] Invalid option value 'riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[0]' specified for 'object'.

{riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[0]} {riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[2]} riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/streamer/partition/DebugTag_started_r_DebugTag {riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[4]} {riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[6]} {riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[1]} riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/streamer/DebugTag_io_partition_ctrl_DebugTag {riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[3]} riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_FLAG_start_FLAG_DebugTag riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/streamer/DebugTag_onebit_DebugTag {riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_func_DebugTag[5]} riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/DebugTag_partition_io_finish_DebugTag riscv_i/RocketChip/inst/rocket_system/tile_prci_domain/tile_reset_domain_tile/acc/streamer/DebugTag_busyReg_DebugTag

ERROR: [DRC RTRES-1] Backbone resources: 1 net(s) have CLOCK_DEDICATED_ROUTE set to BACKBONE but do not use backbone resources. The problem net(s) are riscv_i/sys_diff_clock_buf/U0/IBUF_OUT[0].




# 1) 拿到对象集合
set nets_raw [get_nets -hier -filter {NAME =~ "*DebugTag_*_DebugTag*"}]

# 2) 先过滤掉 ILA/hub（按名字过滤，但保留对象）
set filtered_nets {}
foreach n $nets_raw {
    set name [get_property NAME $n]
    if {[regexp {(^|/)u_ila_} $name]} { continue }
    if {[regexp {(^|/)dbg_hub} $name]} { continue }
    lappend filtered_nets $n ;# 注意：这里存的是对象 $n，不是 $name
}

# 3) 去重选择（按叶名比对，但 map 的 value 仍然放“对象”）
array unset signal_map
foreach n $filtered_nets {
    set name [get_property NAME $n]
    set leaf [lindex [split $name "/"] end]

    if {![info exists signal_map($leaf)]} {
        set signal_map($leaf) $n
    } else {
        set ex $signal_map($leaf)
        set ex_name [get_property NAME $ex]

        # 打分逻辑仍按“名字”来判断就行
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

# 4) 从 map 里取回“对象列表”
set debug_nets {}
foreach {leaf obj} [array get signal_map] {
    lappend debug_nets $obj  ;# 仍是对象
}
systemctl --user status gnome-remote-desktop.service

set_property INCREMENTAL_CHECKPOINT /home/name/vivado_prj/vivado-risc-v/workspace/rocket64b1_partition_debug/vivado-vc707-riscv/synth_dbg.dcp [get_runs impl_1]
WARNING: [Runs 36-537] File /home/name/vivado_prj/vivado-risc-v/workspace/rocket64b1_partition_debug/vivado-vc707-riscv/synth_dbg.dcp is not part of fileset utils_1, but has specified as a incremental checkpoint for run(s) impl_1. This file will not be handled as part of the project for archive and other project based functionality.
