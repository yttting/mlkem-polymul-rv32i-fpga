# Explicit JTAG programming entrypoint; never called by the build scripts.
# vivado -mode batch -source scripts/program_board.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
set bit [file join $root release mlkem_pynqz2.bit]
set ltx [file join $root release mlkem_pynqz2.ltx]
foreach f [list $bit $ltx] {
    if {![file exists $f]} {error "Missing release artifact: $f"}
}
open_hw_manager
connect_hw_server
set targets [get_hw_targets -quiet]
if {[llength $targets] != 1} {
    error "Expected one JTAG target. Use Hardware Manager to select the intended board."
}
current_hw_target [lindex $targets 0]
open_hw_target
set devices [get_hw_devices -quiet xc7z020*]
if {[llength $devices] != 1} {error "Expected one xc7z020 device on the selected target"}
set device [lindex $devices 0]
current_hw_device $device
set_property PROGRAM.FILE $bit $device
set_property PROBES.FILE $ltx $device
set_property FULL_PROBES.FILE $ltx $device
program_hw_devices $device
refresh_hw_device $device
source [file join $root scripts read_board_vio.tcl]
close_hw_manager
