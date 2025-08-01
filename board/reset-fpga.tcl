open_hw_manager
connect_hw_server -url "$::env(HW_SERVER_ADDR)"
open_hw_target
current_hw_device [lindex [get_hw_devices] 0]
refresh_hw_device -update_hw_probes false [current_hw_device]
boot_hw_device [current_hw_device]
# # Reset the FPGA
# reset_hw_device [current_hw_device]

# # Optional: Boot the device after reset
# # boot_hw_device [current_hw_device]

# close_hw_target
# close_hw_manager