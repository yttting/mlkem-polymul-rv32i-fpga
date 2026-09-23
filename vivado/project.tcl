# Common Vivado 2024.2 project definition. Called by scripts/run.tcl.
# Source files use repository paths. Only XPR/XCI are tracked from the generated tree.
proc mlkem_create_project {root firmware} {
    if {[version -short] ne "2024.2"} {error "Use Vivado 2024.2 for this project"}
    set project_dir [file join $root vivado project]
    file mkdir $project_dir
    create_project -force mlkem_pynqz2 $project_dir -part xc7z020clg400-1
    set_property target_language Verilog [current_project]
    set_property simulator_language Mixed [current_project]
    set_property XPM_LIBRARIES {XPM_MEMORY} [current_project]
    foreach dir {rtl/accelerator rtl/axi} {
        add_files -norecurse [lsort [glob [file join $root $dir *.v]]]
    }
    add_files -norecurse [glob [file join $root rtl accelerator *.dat]]
    foreach f {rtl/cpu/picorv32.v rtl/system/mlkem_polymul_rv32i_profile_top.v rtl/board/mlkem_polymul_pynqz2_top.v} {
        add_files -norecurse [file join $root $f]
    }
    set image [file join $firmware transfer_both_unroll4.mem]
    if {![file exists $image]} {error "Missing firmware: $image"}
    add_files -norecurse $image
    set_property file_type {Memory Initialization Files} [get_files $image]
    foreach f {pynq_z2_board.xdc pynqz2_bram_reset.xdc} {
        add_files -fileset constrs_1 -norecurse [file join $root constraints $f]
    }
    set_property top mlkem_polymul_pynqz2_top [get_filesets sources_1]
    set_property generic {ENABLE_VIO=1} [get_filesets sources_1]
    set ip_dir [file join $project_dir mlkem_pynqz2.srcs sources_1 ip]
    file mkdir $ip_dir
    create_ip -force -dir $ip_dir \
        -name vio -vendor xilinx.com -library ip -version 3.0 -module_name mlkem_profile_vio
    set config [list CONFIG.C_NUM_PROBE_IN 13 CONFIG.C_NUM_PROBE_OUT 0 CONFIG.C_EN_PROBE_IN_ACTIVITY 0]
    for {set i 0} {$i < 12} {incr i} {lappend config CONFIG.C_PROBE_IN${i}_WIDTH 32}
    lappend config CONFIG.C_PROBE_IN12_WIDTH 2
    set_property -dict $config [get_ips mlkem_profile_vio]
    generate_target all [get_ips mlkem_profile_vio]

    # One GUI project with independent simulation source sets.
    foreach {suite files top} {
        vio {tb/board/tb_pynqz2_profile_vio.sv tb/monitors/mlkem_core_cycle_observer.sv} tb_pynqz2_profile_vio
        board {tb/board/tb_pynqz2_bram_board.sv} tb_pynqz2_bram_board
        protocol {tb/protocol/tb_bram_wrapper_protocol.sv} tb_bram_wrapper_protocol
        core {tb/core/tb_v39e_true_one_dsp.sv} tb_v39e_true_one_dsp
    } {
        set name [expr {$suite eq "vio" ? "sim_1" : "sim_$suite"}]
        if {$suite ne "vio"} {create_fileset -simset $name}
        foreach f $files {add_files -fileset $name -norecurse [file join $root $f]}
        set_property top $top [get_filesets $name]
        set_property xsim.simulate.runtime all [get_filesets $name]
        update_compile_order -fileset $name
    }
    current_fileset -simset [get_filesets sim_1]
    update_compile_order -fileset sources_1
    foreach f [get_files -all] {
        set full [file normalize $f]
        if {![string equal -nocase [string range $full 0 [expr {[string length $root]-1}]] $root] ||
            [string index $full [string length $root]] ne "/"} {
            error "Source outside repository: $full"
        }
    }
}

proc mlkem_simulate {suite} {
    set markers [dict create vio "BOARD VIO SIM PASS" board "PYNQZ2 BOARD SIM PASS" \
        protocol "BRAM PROTOCOL PASS" core "V39-E MANUAL RTL COSIM PASS"]
    set name [expr {$suite eq "vio" ? "sim_1" : "sim_$suite"}]
    current_fileset -simset [get_filesets $name]
    launch_simulation -simset $name
    close_sim
    set project_dir [get_property DIRECTORY [current_project]]
    set logpath [file join $project_dir mlkem_pynqz2.sim $name behav xsim simulate.log]
    set f [open $logpath r]
    set log [read $f]
    close $f
    if {[string first [dict get $markers $suite] $log] < 0 ||
        [regexp -nocase {fatal:|\$fatal|ERROR:} $log]} {
        error "Regression $suite failed; inspect $logpath"
    }
    puts "MLKEM_SIM_PASS suite=$suite"
    current_fileset -simset [get_filesets sim_1]
}
