read_verilog -sv main.sv
read_verilog -sv ../../rtl/dram_controller.sv


# Adiciona o IP clk_wiz_0
read_verilog ./ip/clk_wiz_0/clk_wiz_0_clk_wiz.v
read_verilog ./ip/clk_wiz_0/clk_wiz_0.v
read_xdc     ./ip/clk_wiz_0/clk_wiz_0.xdc

# Adiciona o IP clk_wiz_1
#read_verilog ./ip/clk_wiz_1/clk_wiz_1_clk_wiz.v
#read_verilog ./ip/clk_wiz_1/clk_wiz_1.v
#read_xdc     ./ip/clk_wiz_1/clk_wiz_1.xdc

# Adiciona o IP mig_7series_0
# RTL do MIG (user_design)
read_verilog -v [glob ./ip/mig_7series_0/mig_7series_0/user_design/rtl/*.v]
read_verilog -v [glob ./ip/mig_7series_0/mig_7series_0/user_design/rtl/**/*.v]

read_xdc ./ip/mig_7series_0/mig_7series_0/user_design/constraints/mig_7series_0.xdc
read_xdc ./ip/mig_7series_0/mig_7series_0/user_design/constraints/mig_7series_0_ooc.xdc
read_xdc ./ip/mig_7series_0/mig_7series_0/user_design/constraints/compatible_ucf/xc7k325tiffg676_pkg.xdc

read_xdc "pinout.xdc"

set_property PROCESSING_ORDER EARLY [get_files pinout.xdc]
set_property PROCESSING_ORDER EARLY [get_files ./ip/clk_wiz_0/clk_wiz_0.xdc]
#set_property PROCESSING_ORDER EARLY [get_files ./ip/clk_wiz_1/clk_wiz_1.xdc]
set_property PROCESSING_ORDER EARLY [get_files ./ip/mig_7series_0/mig_7series_0/user_design/constraints/mig_7series_0.xdc]

# synth
synth_design -top "top" -part "xc7k325tffg676-2"

# place and route
opt_design
place_design

report_utilization -hierarchical -file reports/utilization_hierarchical_place.rpt
report_utilization -file               reports/utilization_place.rpt
report_io -file                        reports/io.rpt
report_control_sets -verbose -file     reports/control_sets.rpt
report_clock_utilization -file         reports/clock_utilization.rpt

route_design

report_timing_summary -no_header -no_detailed_paths
report_route_status -file                            reports/route_status.rpt
report_drc -file                                     reports/drc.rpt
report_timing_summary -datasheet -max_paths 10 -file reports/timing.rpt
report_power -file                                   reports/power.rpt

# write bitstream
write_bitstream -force "./build/out.bit"

exit
