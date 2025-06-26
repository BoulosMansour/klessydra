# Create and map the work library
cd ..
vlib work
vmap work work

# ----------------------------
# Compile VHDL-2008 packages
# ----------------------------
vcom -2008 packages/PKG_RiscV_Klessydra.vhd
vcom -2008 packages/PKG_tb_config.vhd
# Add more packages here

# ----------------------------
# Compile RTL design files
# ----------------------------
vcom -2008 modules/FU/adders_stg/DSP_Adders_stg_1.vhd
vcom -2008 modules/FU/adders_stg/DSP_Adders_stg_2.vhd
vcom -2008 modules/FU/adders_stg/DSP_Adders_Sync.vhd
vcom -2008 modules/FU/DSP_Adders.vhd
vcom -2008 modules/FU/multipliers_stg/DSP_Multipliers_stg_1.vhd
vcom -2008 modules/FU/multipliers_stg/DSP_Multipliers_stg_1_comb.vhd
vcom -2008 modules/FU/multipliers_stg/DSP_Multipliers_stg_2.vhd
vcom -2008 modules/FU/DSP_Multipliers.vhd
vcom -2008 modules/FU/shifters_stg/DSP_Shifters_comb.vhd
vcom -2008 modules/FU/shifters_stg/DSP_Shifters_stg_1.vhd
vcom -2008 modules/FU/shifters_stg/DSP_Shifters_stg_2.vhd
vcom -2008 modules/FU/DSP_Shifters.vhd
vcom -2008 modules/FU/comparators_stg/DSP_Comparators_Unit.vhd
vcom -2008 modules/FU/DSP_Comparators.vhd
vcom -2008 modules/pipeline/DSP_Pipeline_Controller.vhd
vcom -2008 modules/mapping/mapping_multithread/DSP_Mapping_Multithread_Out_Mapper.vhd
vcom -2008 modules/mapping/mapping_multicore/DSP_Mapping_Multicore_Out_Mapper.vhd
vcom -2008 modules/mapping/mapping_multithread/DSP_Mapping_IN_Unit_Multithread.vhd
vcom -2008 modules/mapping/mapping_multicore/DSP_Mapping_IN_Unit_Multicore.vhd
vcom -2008 modules/mapping/DSP_Mapping.vhd
vcom -2008 modules/FU_handler/MT/MT_comp/DSP_FU_Issue_Buffer_Sync.vhd
vcom -2008 modules/FU_handler/MT/MT_comp/DSP_FU_Issue_Buffer_Comb.vhd
vcom -2008 modules/FU_handler/MT/MT_comp/DSP_Busy_FU_Sync.vhd
vcom -2008 modules/FU_handler/MT/MT_comp/DSP_FU_Handler_MT_pending_enabler_sync.vhd
vcom -2008 modules/FU_handler/MT/MT_comp/DSP_FU_Handler_MT_fu_enabler_comb.vhd
vcom -2008 modules/FU_handler/MT/DSP_FU_Handler_MT.vhd
vcom -2008 modules/FU_handler/MC/DSP_FU_Handler_MC.vhd
vcom -2008 modules/FU_handler/DSP_FU_Handler.vhd
vcom -2008 modules/FU_handler/DSP_FU_Enabler_Sync.vhd
vcom -2008 modules/exec/DSP_Exec_Unit.vhd
vcom -2008 modules/excpt_cntrl/DSP_Excpt_Cntrl_unit.vhd
vcom -2008 modules/FU/RTL-Accumulator.vhd
vcom -2008 modules/RTL_DSP_TOP.vhd
# Compile in dependency order (lowest-level modules first)

# ----------------------------
# Compile Testbench
# ----------------------------
vcom -2008 tb/tb_RTL_DSP_TOP.vhd

# ----------------------------
# Load the simulation
# ----------------------------
vsim -voptargs=+acc work.tb_rtl_dsp_top

# ----------------------------
# Add signals to waveform
# ----------------------------
add wave sim:/tb_rtl_dsp_top/DUT/*

# ----------------------------
# Setup VCD dump
# ----------------------------
#vcd file test/conv_16_s0.vcd
#vcd add /tb_rtl_dsp_top/*

# ----------------------------
# Run simulation
# ----------------------------
run 1 ms  ;# Change duration as needed

# Optionally leave GUI open
# or exit after simulation:
# quit -f
