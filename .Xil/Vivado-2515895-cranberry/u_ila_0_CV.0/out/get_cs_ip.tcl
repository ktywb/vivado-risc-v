#
#Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
#
set_param general.maxThreads 6
set_param chipscope.flow 0
set part xc7vx485tffg1761-2
set board_part_repo_paths {}
set board_part xilinx.com:vc707:part0:1.4
set board_connections {}
set tool_flow Vivado
set ip_vlnv xilinx.com:ip:ila:6.2
set ip_module_name u_ila_0
set params {{{PARAM_VALUE.ALL_PROBE_SAME_MU} {true} {PARAM_VALUE.ALL_PROBE_SAME_MU_CNT} {1} {PARAM_VALUE.C_ADV_TRIGGER} {false} {PARAM_VALUE.C_DATA_DEPTH} {8192} {PARAM_VALUE.C_EN_STRG_QUAL} {false} {PARAM_VALUE.C_INPUT_PIPE_STAGES} {0} {PARAM_VALUE.C_NUM_OF_PROBES} {12} {PARAM_VALUE.C_PROBE0_TYPE} {1} {PARAM_VALUE.C_PROBE0_WIDTH} {8} {PARAM_VALUE.C_PROBE10_TYPE} {1} {PARAM_VALUE.C_PROBE10_WIDTH} {1} {PARAM_VALUE.C_PROBE11_TYPE} {1} {PARAM_VALUE.C_PROBE11_WIDTH} {8} {PARAM_VALUE.C_PROBE1_TYPE} {1} {PARAM_VALUE.C_PROBE1_WIDTH} {16} {PARAM_VALUE.C_PROBE2_TYPE} {1} {PARAM_VALUE.C_PROBE2_WIDTH} {16} {PARAM_VALUE.C_PROBE3_TYPE} {1} {PARAM_VALUE.C_PROBE3_WIDTH} {1} {PARAM_VALUE.C_PROBE4_TYPE} {1} {PARAM_VALUE.C_PROBE4_WIDTH} {1} {PARAM_VALUE.C_PROBE5_TYPE} {1} {PARAM_VALUE.C_PROBE5_WIDTH} {16} {PARAM_VALUE.C_PROBE6_TYPE} {1} {PARAM_VALUE.C_PROBE6_WIDTH} {16} {PARAM_VALUE.C_PROBE7_TYPE} {1} {PARAM_VALUE.C_PROBE7_WIDTH} {1} {PARAM_VALUE.C_PROBE8_TYPE} {0} {PARAM_VALUE.C_PROBE8_WIDTH} {1} {PARAM_VALUE.C_PROBE9_TYPE} {1} {PARAM_VALUE.C_PROBE9_WIDTH} {7} {PARAM_VALUE.C_TRIGIN_EN} {0} {PARAM_VALUE.C_TRIGOUT_EN} {0}}}
set intf_params {}
set connectivity {}
set output_xci /home/name/vivado_prj/vivado-risc-v/.Xil/Vivado-2515895-cranberry/u_ila_0_CV.0/out/result.xci
set output_dcp /home/name/vivado_prj/vivado-risc-v/.Xil/Vivado-2515895-cranberry/u_ila_0_CV.0/out/result.dcp
set output_dir /home/name/vivado_prj/vivado-risc-v/.Xil/Vivado-2515895-cranberry/u_ila_0_CV.0/out
set ip_repo_paths {}
set ip_output_repo /home/name/vivado_prj/vivado-risc-v/workspace/rocket64b1_partition_debug/vivado-vc707-riscv/vc707-riscv.cache/ip
set ip_cache_permissions {read write}

set oopbus_ip_repo_paths [get_param chipscope.oopbus_ip_repo_paths]

set synth_opts {}
set xdc_files {}
