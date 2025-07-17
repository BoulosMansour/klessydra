#!/usr/bin/tclsh

# To use this script open design_vision from command line as design_vision& "for GUI" or dc_shell "for command line"
# in the folder of the script and only: source xxxx.tcl

set GPGPU_GENERIC_ROOT "../"
set MODULES_ROOT "../modules/"
set SYNTHESIS_PATH "../synthesis/15nm/CCS/NanGate_15nm_OCL_typical_conditional_ccs.db"

set NCORES __NCORES__

# Enable VHDL-2008 parsing
set hdlin_vhdl_2008 true

set modules_src [list \
	"$MODULES_ROOT/hardening/DMR.vhd" \
	"$MODULES_ROOT/hardening/TMR.vhd" \
	"$MODULES_ROOT/FU/adders_stg/DSP_Adders_stg_1.vhd" \
	"$MODULES_ROOT/FU/adders_stg/DSP_Adders_stg_2.vhd" \
	"$MODULES_ROOT/FU/adders_stg/DSP_Adders_Sync.vhd" \
	"$MODULES_ROOT/FU/DSP_Adders.vhd" \
	"$MODULES_ROOT/FU/multipliers/multipliers_stg/DSP_Multipliers_stg_1.vhd" \
	"$MODULES_ROOT/FU/multipliers/multipliers_stg/DSP_Multipliers_stg_1_comb.vhd" \
	"$MODULES_ROOT/FU/multipliers/multipliers_stg/DSP_Multipliers_stg_2.vhd" \
	"$MODULES_ROOT/FU/multipliers/DSP_Multipliers_TMR.vhd" \
	"$MODULES_ROOT/FU/shifters_stg/DSP_Shifters_comb.vhd" \
	"$MODULES_ROOT/FU/shifters_stg/DSP_Shifters_stg_1.vhd" \
	"$MODULES_ROOT/FU/shifters_stg/DSP_Shifters_stg_2.vhd" \
	"$MODULES_ROOT/FU/DSP_Shifters.vhd" \
	"$MODULES_ROOT/FU/comparators_stg/DSP_Comparators_Unit.vhd" \
	"$MODULES_ROOT/FU/DSP_Comparators.vhd" \
	"$MODULES_ROOT/pipeline/DSP_Pipeline_Controller.vhd" \
	"$MODULES_ROOT/mapping/mapping_multithread/DSP_Mapping_Multithread_Out_Mapper.vhd" \
	"$MODULES_ROOT/mapping/mapping_multicore/DSP_Mapping_Multicore_Out_Mapper.vhd" \
	"$MODULES_ROOT/mapping/mapping_multithread/DSP_Mapping_IN_Unit_Multithread.vhd" \
	"$MODULES_ROOT/mapping/mapping_multicore/DSP_Mapping_IN_Unit_Multicore.vhd" \
	"$MODULES_ROOT/mapping/DSP_Mapping.vhd" \
	"$MODULES_ROOT/FU_handler/MT/MT_comp/DSP_FU_Issue_Buffer_Sync.vhd" \
	"$MODULES_ROOT/FU_handler/MT/MT_comp/DSP_FU_Issue_Buffer_Comb.vhd" \
	"$MODULES_ROOT/FU_handler/MT/MT_comp/DSP_Busy_FU_Sync.vhd" \
	"$MODULES_ROOT/FU_handler/MT/MT_comp/DSP_FU_Handler_MT_pending_enabler_sync.vhd" \
	"$MODULES_ROOT/FU_handler/MT/MT_comp/DSP_FU_Handler_MT_fu_enabler_comb.vhd" \
	"$MODULES_ROOT/FU_handler/MT/DSP_FU_Handler_MT.vhd" \
	"$MODULES_ROOT/FU_handler/MC/DSP_FU_Handler_MC.vhd" \
	"$MODULES_ROOT/FU_handler/DSP_FU_Handler.vhd" \
	"$MODULES_ROOT/FU_handler/DSP_FU_Enabler_Sync.vhd" \
	"$MODULES_ROOT/exec/DSP_Exec_Unit.vhd" \
	"$MODULES_ROOT/excpt_cntrl/DSP_Excpt_Cntrl_unit.vhd" \
	"$MODULES_ROOT/FU/RTL-Accumulator.vhd" \
	"$MODULES_ROOT/RTL_DSP_TOP.vhd"
]

# loading the libraries:
set synthetic_library $SYNTHESIS_PATH
set target_library $SYNTHESIS_PATH

set link_library [list $target_library $synthetic_library]


foreach src $modules_src {
	if [expr {[string first # $src] eq 0}] {puts $src} else {
		#exec >@stdout 2>@stderr
		vcom -2008 $src
	}
}


# Create black box for dp_reg to be replaced with behavioral
#set_dont_touch dp_regfile

# elaborate STREAMING_MULTIPROCESSOR -architecture ARCH -library DEFAULT -parameters "STREAMING_MULTIPROCESSOR_ID = 00000000, GMEM_ADDR_SIZE = 18, CMEM_ADDR_SIZE = 13, SYSMEM_ADDR_SIZE = 18" -update


elaborate multiplier_FP

link

check_design


#Target clock frequency 500MHz. for 45nm tech lib (timeunit in ns)
create_clock -name clk -period 2 clk 

# Target clock frequency 500MHz. for 15nm tech lib (timeunit in ps)
#create_clock -name clk_i -period 2000 clk_i


		# ###########COMPILE
# ungroup -all -flatten

ungroup -start_level 3 -all

		# compile
	
		#compile -map_effort high
		#compile_ultra -inc -retime
compile_ultra -retime

write -f verilog -hierarchy -output FP_add_15.v

report_timing -transition_time -nets -attributes -nosplit > Report_time_transition_15.txt
report_timing -delay max -nosplit > Report_time_delay_max_15.txt
report_timing -path full -nosplit > Report_time_path_full_15.txt

report_area -nosplit -hierarchy > Report_Area_15.txt
report_power -nosplit -hierarchy > Report_Power_15.txt
report_reference -nosplit -hierarchy > Report_References_15.txt
report_resources -nosplit -hierarchy > Report_Resources_15.txt
report_cell > Report_Cells_15.txt

exit
		#quit
