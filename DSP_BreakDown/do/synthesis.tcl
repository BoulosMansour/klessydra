#!/usr/bin/tclsh

# To use this script open design_vision from command line as design_vision& "for GUI" or dc_shell "for command line"
# in the folder of the script and only: source xxxx.tcl

# add desired deisgn parameters
set ENABLE_REPLICATE true
set SYNTHESIS_TECHNOLOGY 130
# available synthesis technologies 15, 45, 130

set GPGPU_GENERIC_ROOT "../"
set MODULES_ROOT "../modules/"
set PACKAGES_ROOT "../packages/"

if [expr {$SYNTHESIS_TECHNOLOGY eq 15}] {
	set SYNTHESIS_PATH "../synthesis/15nm/CCS/NanGate_15nm_OCL_typical_conditional_ccs.db"
} elseif [expr {$SYNTHESIS_TECHNOLOGY eq 45}] {
	set SYNTHESIS_PATH "../synthesis/45nm/NangateOpenCellLibrary_typical_ccs.db"
} elseif [expr {$SYNTHESIS_TECHNOLOGY eq 130}] {
	set SYNTHESIS_PATH "../synthesis/130nm/db/sg13g2_stdcell_typ_1p20V_25C.db"
}

set NCORES __NCORES__

# Enable VHDL-2008 parsing
set hdlin_vhdl_2008 true

set pkg_src [list \
	"$PACKAGES_ROOT/PKG_tb_config.vhd"\
	"$PACKAGES_ROOT/PKG_RiscV_Klessydra.vhd"\
]

set modules_src [list \
	"$MODULES_ROOT/hardening/DMR.vhd" \
	"$MODULES_ROOT/hardening/TMR.vhd" \
	"$MODULES_ROOT/FU/adders_stg/DSP_Adders_stg_1.vhd" \
	"$MODULES_ROOT/FU/adders_stg/DSP_Adders_stg_2.vhd" \
	"$MODULES_ROOT/FU/adders_stg/DSP_Adders_Sync.vhd" \
	"$MODULES_ROOT/FU/DSP_Adders.vhd" \
	"$MODULES_ROOT/FU/DMR/DSP_Adders_DMR.vhd" \
	"$MODULES_ROOT/FU/TMR/DSP_Adders_TMR.vhd" \
	"$MODULES_ROOT/FU/multipliers/multipliers_stg/DSP_Multipliers_stg_1.vhd" \
	"$MODULES_ROOT/FU/multipliers/multipliers_stg/DSP_Multipliers_stg_1_comb.vhd" \
	"$MODULES_ROOT/FU/multipliers/multipliers_stg/DSP_Multipliers_stg_2.vhd" \
	"$MODULES_ROOT/FU/multipliers/DSP_Multipliers.vhd" \
	"$MODULES_ROOT/FU/DMR/DSP_Multipliers_DMR.vhd" \
	"$MODULES_ROOT/FU/TMR/DSP_Multipliers_TMR.vhd" \
	"$MODULES_ROOT/FU/shifters_stg/DSP_Shifters_comb.vhd" \
	"$MODULES_ROOT/FU/shifters_stg/DSP_Shifters_stg_1.vhd" \
	"$MODULES_ROOT/FU/shifters_stg/DSP_Shifters_stg_2.vhd" \
	"$MODULES_ROOT/FU/DSP_Shifters.vhd" \
	"$MODULES_ROOT/FU/DMR/DSP_Shifters_DMR.vhd" \
	"$MODULES_ROOT/FU/TMR/DSP_Shifters_TMR.vhd" \
	"$MODULES_ROOT/FU/comparators_stg/DSP_Comparators_Unit.vhd" \
	"$MODULES_ROOT/FU/DSP_Comparators.vhd" \
	"$MODULES_ROOT/FU/DMR/DSP_Comparators_DMR.vhd" \
	"$MODULES_ROOT/FU/TMR/DSP_Comparators_TMR.vhd" \
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
	"$MODULES_ROOT/RTL_DSP_TOP_synth.vhd"\
]

# loading the libraries:
set synthetic_library $SYNTHESIS_PATH
set target_library $SYNTHESIS_PATH

set link_library [list $target_library $synthetic_library]

foreach src $pkg_src {
	if [expr {[string first # $src] eq 0}] {puts $src} else {
		#exec >@stdout 2>@stderr
		read_vhdl $src
		#analyze -format vhdl {$src}
	}
}

foreach src $modules_src {
	if [expr {[string first # $src] eq 0}] {puts $src} else {
		#exec >@stdout 2>@stderr
		#read_vhdl $src
		analyze -format vhdl $src
	}
}

## initialise generic parameters
set THREAD_POOL_SIZE 3
set accl_en 1
if {$ENABLE_REPLICATE} {
	set replicate_accl_en 1
} else {
	set replicate_accl_en 0
}
set multithreaded_accl_en 0
set SPM_NUM 4
set Addr_Width 14
set SIMD 2

set TPS_CEIL 2
set TPS_BUF_CEIL 1
set SPM_ADDR_WID 3 
set SIMD_BITS 1
set Data_Width 32
set SIMD_Width 64
if {$ENABLE_REPLICATE} {
	set ACCL_NUM 3 
	set FU_NUM 3
} else {
	set ACCL_NUM 1
	set FU_NUM 1
}
# elaborate DSP_Excpt_Cntrl_unit -parameters "THREAD_POOL_SIZE=$THREAD_POOL_SIZE, Addr_Width=$Addr_Width, SPM_NUM=$SPM_NUM, SIMD=$SIMD, SPM_ADDR_WID=$SPM_ADDR_WID, SIMD_BITS=$SIMD_BITS"
# elaborate DSP_Exec_Unit -parameters "THREAD_POOL_SIZE=$THREAD_POOL_SIZE, Addr_Width=$Addr_Width, SPM_ADDR_WID=$SPM_ADDR_WID, SIMD_Width=$SIMD_Width"
# elaborate DSP_Adders_stg_1 -parameters "SIMD=$SIMD, SIMD_Width=$SIMD_Width"
# elaborate DSP_Adders_stg_2 -parameters "SIMD=$SIMD, SIMD_Width=$SIMD_Width"
# elaborate DSP_Adders_Sync -parameters "SIMD=$SIMD, SIMD_Width=$SIMD_Width"
# elaborate DSP_Comparators_Unit -parameters "SIMD=$SIMD, SIMD_Width=$SIMD_Width"
# elaborate DSP_Adders_DMR -parameters "multithreaded_accl_en=$multithreaded_accl_en, SIMD=$SIMD, ACCL_NUM=$ACCL_NUM, FU_NUM=$FU_NUM, SIMD_Width=$SIMD_Width"
# elaborate DSP_Comparators_DMR -parameters "multithreaded_accl_en=$multithreaded_accl_en, SIMD=$SIMD, ACCL_NUM=$ACCL_NUM, FU_NUM=$FU_NUM, SIMD_Width=$SIMD_Width"
# elaborate DSP_Multipliers_DMR -parameters "multithreaded_accl_en=$multithreaded_accl_en, SIMD=$SIMD, ACCL_NUM=$ACCL_NUM, FU_NUM=$FU_NUM, SIMD_Width=$SIMD_Width, Data_Width=$Data_Width"
# elaborate DSP_Shifters_DMR -parameters "multithreaded_accl_en=$multithreaded_accl_en, SIMD=$SIMD, ACCL_NUM=$ACCL_NUM, FU_NUM=$FU_NUM, SIMD_Width=$SIMD_Width"
# elaborate DSP_Multipliers_stg_1_comb -parameters "SIMD=$SIMD, SIMD_Width=$SIMD_Width, Data_Width=$Data_Width"
# elaborate DSP_Multipliers_stg_1 -parameters "SIMD=$SIMD, SIMD_Width=$SIMD_Width"
# elaborate DSP_Multipliers_stg_2 -parameters "SIMD=$SIMD, SIMD_Width=$SIMD_Width, Data_Width=$Data_Width"
# elaborate DSP_Multipliers -parameters "SIMD=$SIMD, multithreaded_accl_en=$multithreaded_accl_en, ACCL_NUM=$ACCL_NUM, FU_NUM=$FU_NUM, SIMD_Width=$SIMD_Width, Data_Width=$Data_Width"
# elaborate DSP_Shifters_comb -parameters "SIMD=$SIMD, SIMD_Width=$SIMD_Width"
# elaborate DSP_Shifters_stg_1 -parameters "SIMD=$SIMD, SIMD_Width=$SIMD_Width"
# elaborate DSP_Shifters_stg_2 -parameters "SIMD=$SIMD, SIMD_Width=$SIMD_Width"
# elaborate DSP_Adders_TMR -parameters "multithreaded_accl_en=$multithreaded_accl_en, SIMD=$SIMD, ACCL_NUM=$ACCL_NUM, FU_NUM=$FU_NUM, SIMD_Width=$SIMD_Width"
# elaborate DSP_Comparators_TMR -parameters "multithreaded_accl_en=$multithreaded_accl_en, SIMD=$SIMD, ACCL_NUM=$ACCL_NUM, FU_NUM=$FU_NUM, SIMD_Width=$SIMD_Width"
# elaborate DSP_Multipliers_TMR -parameters "multithreaded_accl_en=$multithreaded_accl_en, SIMD=$SIMD, ACCL_NUM=$ACCL_NUM, FU_NUM=$FU_NUM, SIMD_Width=$SIMD_Width, Data_Width=$Data_Width"
# elaborate DSP_Shifters_TMR -parameters "multithreaded_accl_en=$multithreaded_accl_en, SIMD=$SIMD, ACCL_NUM=$ACCL_NUM, FU_NUM=$FU_NUM, SIMD_Width=$SIMD_Width"
# elaborate DSP_Adders -parameters "multithreaded_accl_en=$multithreaded_accl_en, SIMD=$SIMD, ACCL_NUM=$ACCL_NUM, FU_NUM=$FU_NUM, SIMD_Width=$SIMD_Width"
# elaborate DSP_Comparators -parameters "multithreaded_accl_en=$multithreaded_accl_en, SIMD=$SIMD, ACCL_NUM=$ACCL_NUM, FU_NUM=$FU_NUM, SIMD_Width=$SIMD_Width"
# elaborate DSP_Shifters -parameters "multithreaded_accl_en=$multithreaded_accl_en, SIMD=$SIMD, ACCL_NUM=$ACCL_NUM, FU_NUM=$FU_NUM, SIMD_Width=$SIMD_Width"
# elaborate ACCUMULATOR -parameters "multithreaded_accl_en=$multithreaded_accl_en, SIMD=$SIMD, ACCL_NUM=$ACCL_NUM, FU_NUM=$FU_NUM, SIMD_Width=$SIMD_Width, Data_Width=$Data_Width"
# elaborate DSP_FU_Issue_Buffer_Sync -parameters "THREAD_POOL_SIZE=$THREAD_POOL_SIZE, ACCL_NUM=$ACCL_NUM, TPS_CEIL=$TPS_CEIL, TPS_BUF_CEIL=$TPS_BUF_CEIL"
# elaborate DSP_FU_Handler_MT -parameters "THREAD_POOL_SIZE=$THREAD_POOL_SIZE, ACCL_NUM=$ACCL_NUM, TPS_CEIL=$TPS_CEIL, TPS_BUF_CEIL=$TPS_BUF_CEIL"
# elaborate DSP_FU_Handler -parameters "multithreaded_accl_en=$multithreaded_accl_en, THREAD_POOL_SIZE=$THREAD_POOL_SIZE, ACCL_NUM=$ACCL_NUM, TPS_CEIL=$TPS_CEIL, TPS_BUF_CEIL=$TPS_BUF_CEIL"
# elaborate DSP_Mapping_IN_Unit_Multicore -parameters "SIMD=$SIMD, SIMD_Width=$SIMD_Width"
# elaborate DSP_Mapping_Multicore_Out_Mapper -parameters "SIMD=$SIMD, SIMD_Width=$SIMD_Width, Data_Width=$Data_Width"
# elaborate DSP_Mapping_IN_Unit_Multithread -parameters "SIMD=$SIMD, SIMD_Width=$SIMD_Width"
# elaborate DSP_Mapping_Multithread_Out_Mapper -parameters "SIMD=$SIMD, SIMD_Width=$SIMD_Width, Data_Width=$Data_Width"
# elaborate DSP_Mapping -parameters "THREAD_POOL_SIZE=$THREAD_POOL_SIZE, SIMD=$SIMD, multithreaded_accl_en=$multithreaded_accl_en, ACCL_NUM=$ACCL_NUM, FU_NUM=$FU_NUM, Data_Width=$Data_Width, SIMD_Width=$SIMD_Width"
elaborate RTL_DSP_TOP -parameters "THREAD_POOL_SIZE=$THREAD_POOL_SIZE, accl_en=$accl_en, replicate_accl_en=$replicate_accl_en, multithreaded_accl_en=$multithreaded_accl_en, SPM_NUM=$SPM_NUM, Addr_Width=$Addr_Width, SIMD=$SIMD, TPS_CEIL=$TPS_CEIL, TPS_BUF_CEIL=$TPS_BUF_CEIL, SPM_ADDR_WID=$SPM_ADDR_WID, SIMD_BITS=$SIMD_BITS, Data_Width=$Data_Width, SIMD_Width=$SIMD_Width, ACCL_NUM=$ACCL_NUM, FU_NUM=$FU_NUM"


# Create black box for dp_reg to be replaced with behavioral
# set_dont_touch dp_regfile

# elaborate STREAMING_MULTIPROCESSOR -architecture ARCH -library DEFAULT -parameters "STREAMING_MULTIPROCESSOR_ID = 00000000, GMEM_ADDR_SIZE = 18, CMEM_ADDR_SIZE = 13, SYSMEM_ADDR_SIZE = 18" -update


# elaborate RTL_DSP_TOP

link

check_design


#Target clock frequency 500MHz. for 45nm tech lib (timeunit in ns)
create_clock -name clk -period 2 clk 

# Target clock frequency 500MHz. for 15nm tech lib (timeunit in ps)
#create_clock -name clk_i -period 2000 clk_i


		# ###########COMPILE
# ungroup -all -flatten

		# compile
	
		#compile -map_effort high
		#compile_ultra -inc -retime
#compile_ultra -retime
compile

write -f verilog -hierarchy -output FP_add_15.v

report_timing -transition_time -nets -attributes -nosplit > report/Report_time_transition_15.txt
report_timing -delay max -nosplit > report/Report_time_delay_max_15.txt
report_timing -path full -nosplit > report/Report_time_path_full_15.txt

report_area -nosplit -hierarchy > report/Report_Area_15.txt
report_power -nosplit -hierarchy > report/Report_Power_15.txt
report_reference -nosplit -hierarchy > report/Report_References_15.txt
report_resources -nosplit -hierarchy > report/Report_Resources_15.txt
report_cell > report/Report_Cells_15.txt

exit
		#quit
