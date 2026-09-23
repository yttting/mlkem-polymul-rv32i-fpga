# vivado -mode batch -source scripts/run.tcl -tclargs project|vio|board|protocol|core|implement ?firmware_dir?
set root [file normalize [file join [file dirname [info script]] ..]]
set mode [lindex $argv 0]
if {$mode eq ""} {set mode project}
if {$mode ni {project vio board protocol core implement}} {
    error "Expected project, vio, board, protocol, core or implement"
}
set firmware [file join $root firmware images]
if {[llength $argv] > 1} {set firmware [file normalize [lindex $argv 1]]}
source [file join $root vivado project.tcl]
mlkem_create_project $root $firmware
if {$mode eq "implement"} {
    foreach suite {core protocol board vio} {mlkem_simulate $suite}
    set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
    set_property strategy Performance_Explore [get_runs impl_1]
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation failed"}
    open_run impl_1
    set reports [file join $root build reports]
    file mkdir $reports
    report_utilization -file [file join $reports utilization_routed.rpt]
    report_timing_summary -report_unconstrained -file [file join $reports timing_routed.rpt]
    report_bus_skew -file [file join $reports bus_skew_routed.rpt]
    report_drc -file [file join $reports drc_routed.rpt]
    foreach kind {setup hold} {
        set paths [get_timing_paths -quiet -delay_type [expr {$kind eq "setup" ? "max" : "min"}] -max_paths 1]
        if {[llength $paths] == 0 || [get_property SLACK $paths] < 0} {
            error "Timing $kind check failed; inspect build/reports"
        }
    }
    set release [file join $root release]
    file mkdir $release
    write_debug_probes -force [file join $release mlkem_pynqz2.ltx]
    set bit [file join [get_property DIRECTORY [get_runs impl_1]] mlkem_polymul_pynqz2_top.bit]
    file copy -force $bit [file join $release mlkem_pynqz2.bit]
    puts "MLKEM_IMPLEMENT_PASS release=$release"
} elseif {$mode ne "project"} {
    mlkem_simulate $mode
}
puts "MLKEM_PROJECT=[get_property DIRECTORY [current_project]]/mlkem_pynqz2.xpr"
close_project
