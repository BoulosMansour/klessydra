# Create and map the work library
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
vcom -2008 modules/DSP_Adders_stg_1.vhd
vcom -2008 modules/DSP_Adders_stg_2.vhd
vcom -2008 modules/DSP_Adders_Sync.vhd
vcom -2008 modules/DSP_Adders.vhd
vcom -2008 modules/DSP_Multipliers_stg_1.vhd
vcom -2008 modules/DSP_Multipliers_stg_1_comb.vhd
vcom -2008 modules/DSP_Multipliers_stg_2.vhd
vcom -2008 modules/DSP_Multipliers.vhd
vcom -2008 modules/DSP_Shifters_comb.vhd
vcom -2008 modules/DSP_Shifters_stg_1.vhd
vcom -2008 modules/DSP_Shifters_stg_2.vhd
vcom -2008 modules/DSP_Shifters.vhd
vcom -2008 modules/DSP_Comparators_Unit.vhd
vcom -2008 modules/DSP_Comparators.vhd
vcom -2008 modules/DSP_Pipeline_Controller.vhd
vcom -2008 modules/DSP_Mapping_Multithread_Out_Mapper.vhd
vcom -2008 modules/DSP_Mapping_Multicore_Out_Mapper.vhd
vcom -2008 modules/DSP_Mapping_IN_Unit_Multithread.vhd
vcom -2008 modules/DSP_Mapping_IN_Unit_Multicore.vhd
vcom -2008 modules/DSP_Mapping.vhd
vcom -2008 modules/DSP_FU_Issue_Buffer_Sync.vhd
vcom -2008 modules/DSP_FU_Issue_Buffer_Comb.vhd
vcom -2008 modules/DSP_Busy_FU_Sync.vhd
vcom -2008 modules/DSP_FU_Handler_MT_pending_enabler_sync.vhd
vcom -2008 modules/DSP_FU_Handler_MT_fu_enabler_comb.vhd
vcom -2008 modules/DSP_FU_Handler_MT.vhd
vcom -2008 modules/DSP_FU_Handler_MC.vhd
vcom -2008 modules/DSP_FU_Handler.vhd
vcom -2008 modules/DSP_FU_Enabler_Sync.vhd
vcom -2008 modules/DSP_Exec_Unit_stage_init.vhd
vcom -2008 modules/DSP_Exec_Unit_stage_exec.vhd
vcom -2008 modules/DSP_Exec_Unit.vhd
vcom -2008 modules/DSP_Excpt_Cntrl_unit.vhd
vcom -2008 modules/RTL-Accumulator.vhd
vcom -2008 modules/RTL_DSP_TOP.vhd
vcom -2008 ../VCU/RTL-DSP_Unit.vhd
# Compile in dependency order (lowest-level modules first)

# ----------------------------
# Compile Testbench
# ----------------------------
vcom -2008 tb/tb_compare_DSP.vhd

# ----------------------------
# Load the simulation
# ----------------------------
vsim -voptargs=+acc work.tb_compare_DSP

# ----------------------------
# Add signals to waveform
# ----------------------------
# add wave sim:/tb_compare_DSP/DUT/*
# add wave sim:/tb_compare_DSP/REF/*
add wave sim:/tb_compare_DSP/*

# ----------------------------
# Run simulation
# ----------------------------
run 1 ms  ;# Change duration as needed

# Optionally leave GUI open
# or exit after simulation:
# quit -f
