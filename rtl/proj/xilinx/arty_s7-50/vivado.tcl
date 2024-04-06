
proc syn {path jobs device design xdc src} {
    read_vhdl ${src}
    read_xdc ${xdc}
    synth_design -top ${design} -part ${device}
    write_checkpoint -force ${path}/${design}/syn.dcp
    report_timing_summary -max_paths 10 -nworst 10 -input_pins -file ${path}/${design}/syn_timing.rpt
    report_utilization -hierarchical -file ${path}/${design}/syn_utilization.rpt
}

proc opt {path jobs design} {
    read_checkpoint ${path}/${design}/syn.dcp
    link_design
    opt_design
    write_checkpoint -force ${path}/${design}/opt.dcp
    report_utilization -hierarchical -file ${path}/${design}/opt_utilization.rpt
    report_timing_summary -max_paths 10 -nworst 10 -input_pins -file ${path}/${design}/opt_timing.rpt
    report_io -file ${path}/${design}/opt_io.rpt
    report_clock_interaction -file ${path}/${design}/opt_clock_interaction.rpt
}

proc place_and_route {path jobs design} {
    read_checkpoint ${path}/${design}/opt.dcp
    link_design
    place_design
    write_checkpoint -force ${path}/${design}/place.dcp
    route_design
    write_checkpoint -force ${path}/${design}/route.dcp
    report_timing_summary -max_paths 10 -nworst 10 -input_pins -file ${path}/${design}/route_timing.rpt
    report_utilization -hierarchical -file ${path}/${design}/route_utilization.rpt
    report_drc -file ${path}/${design}/route_drc.rpt
}

proc bitstream {path jobs design} {
    read_checkpoint ${path}/${design}/route.dcp
    link_design
    write_bitstream -force ${path}/${design}/bitstream.bit
}

proc get_device_list {} {
    open_hw_manager
    connect_hw_server -url localhost:3121
    puts [get_hw_targets *]
}

proc program_device {device file} {
    open_hw_manager
    connect_hw_server -url localhost:3121
    current_hw_target ${device}
    open_hw_target
    current_hw_device [lindex [get_hw_devices] 0]
    set_property PROGRAM.FILE [list ${file}] [lindex [get_hw_devices] 0]
    program_hw_devices [lindex [get_hw_devices] 0]
    refresh_hw_device [lindex [get_hw_devices] 0]
}

proc project_create {path name device design xcf src} {
    create_project -force ${name} ${path}/${design} -part ${device}
    add_files ${src}
    add_files ${xcf}
    close_project
}

proc project_open {path name design} {
    open_project ${path}/${design}/${name}.xpr
}

proc project_syn {path name design} {
    project_open ${path} ${name} ${design}
}

proc project_impl {path name design} {
    project_open ${path} ${name} ${design}
}

proc project_bitstream {path name design} {
    project_open ${path} ${name} ${design}
}

if {[llength $::argv] == 0} {
    exit
}

switch [lindex $argv 0] {
    "syn"             {syn             [lindex $argv 1] [lindex $argv 2] [lindex $argv 3] [lindex $argv 4] [lindex $argv 5] [lrange $::argv 6 [expr [llength $::argv] - 1]]}
    "opt"             {opt             [lindex $argv 1] [lindex $argv 2] [lindex $argv 3]}
    "place_and_route" {place_and_route [lindex $argv 1] [lindex $argv 2] [lindex $argv 3]}
    "bitstream"       {bitstream       [lindex $argv 1] [lindex $argv 2] [lindex $argv 3]}
    "project_create"  {project_create  [lindex $argv 1] [lindex $argv 2] [lindex $argv 3] [lindex $argv 4] [lindex $argv 5] [lrange $::argv 6 [expr [llength $::argv] - 1]]}
    "project_open"    {project_open    [lindex $argv 1] [lindex $argv 2] [lindex $argv 3]; start_gui}
    "get_device_list" {get_device_list}
    "program_device"  {program_device  [lindex $argv 1] [lindex $argv 2]}
    default           {puts "Invalid command"}
}
