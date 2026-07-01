set_context dft -rtl -design_id activity_sensor_icl

set_tsdb_output_directory /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/3sensor/icl_tsdb

set_tool_options -allow_vhdl_2008 on

read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/ijtag-sensor-tool/sensors/activity_sensor.vhd

set_current_design activity_sensor

set_design_level chip

add_icl_ports ijtag_tck -type tck
add_icl_ports ijtag_reset -type reset
add_icl_ports ijtag_sel -type select
add_icl_ports ijtag_ce -type capture_en
add_icl_ports ijtag_se -type shift_en
add_icl_ports ijtag_si -type scan_in
add_icl_ports ijtag_so -type scan_out

check_design_rules

extract_icl

file mkdir /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/3sensor/icl
write_icl /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/3sensor/icl/activity_sensor.icl -replace

puts "ICL extraction for activity_sensor completed: /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/3sensor/icl/activity_sensor.icl"
