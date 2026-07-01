set_context dft -rtl -design_id rtl1_2sensor

set_tsdb_output_directory /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/tsdb_outdir

read_cell_library /home/b.mansour/Desktop/klessydra_git/tech/tessent/ihp-sg13g2_stdcell.tcelllib
read_cell_library /home/b.mansour/Desktop/klessydra_git/tech/tessent/ihp-sg13g2_io.tcelllib

set_tool_options -allow_vhdl_2008 on

read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/packages/PKG_tb_config.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/packages/PKG_RiscV_Klessydra.vhd

read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/ijtag-sensor-tool/sensors/activity_sensor.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DMR.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Adders.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Adders_DMR.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Adders_Sync.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Adders_TMR.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Adders_stg_1.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Adders_stg_2.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Busy_FU_Sync.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Comparators.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Comparators_DMR.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Comparators_TMR.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Comparators_Unit.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Excpt_Cntrl_unit.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Exec_Unit.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_FU_Enabler_Sync.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_FU_Handler.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_FU_Handler_MC.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_FU_Handler_MT.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_FU_Handler_MT_fu_enabler_comb.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_FU_Handler_MT_pending_enabler_sync.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_FU_Issue_Buffer_Comb.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_FU_Issue_Buffer_Sync.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Mapping.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Mapping_IN_Unit_Multicore.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Mapping_IN_Unit_Multithread.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Mapping_Multicore_Out_Mapper.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Mapping_Multithread_Out_Mapper.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Multipliers.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Multipliers_DMR.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Multipliers_TMR.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Multipliers_stg_1.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Multipliers_stg_1_comb.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Multipliers_stg_2.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Pipeline_Controller.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Shifters.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Shifters_DMR.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Shifters_TMR.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Shifters_comb.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Shifters_stg_1.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_DSP_Shifters_stg_2.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_RTL-Accumulator.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_RTL_DSP_TOP.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_RTL_DSP_TOP_synth.vhd
read_vhdl -format 2008 /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/modified/modified_TMR.vhd

set_current_design RTL_DSP_TOP

read_icl /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/icl/activity_sensor.icl -force
set_current_design RTL_DSP_TOP

set_design_level physical_block

add_black_boxes -Modules {activity_sensor}

set_attribute_value ijtag_tck -name function -value tck
set_attribute_value ijtag_tdi -name function -value tdi
set_attribute_value ijtag_tms -name function -value tms
set_attribute_value ijtag_tdo -name function -value tdo

add_clocks 0 clk_i -period 10ns

check_design_rules

set spec [create_dft_specification]
report_config_data $spec
process_dft_specification

extract_icl

file mkdir /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/dft_inserted
write_design -output_directory /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/dft_inserted
write_icl    /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/modules/out/2sensor/dft_inserted/RTL_DSP_TOP.icl

puts "Sensor injection completed successfully!"
