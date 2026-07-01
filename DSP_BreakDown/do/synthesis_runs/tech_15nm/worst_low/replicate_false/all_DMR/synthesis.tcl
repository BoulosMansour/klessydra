#!/usr/bin/tclsh

# =============================================================================
# Synthesis TEMPLATE driven by run_synthesis_sweep.py
# This is a copy of synthesis.tcl with placeholders the sweep script fills in.
# DO NOT run this directly — the original synthesis.tcl is kept untouched.
# Placeholders:
#   false     -> true | false
#   15 -> 15 | 45 | 130   (informational)
#   worst_low     -> corner name (e.g. typical, fast, slow, ...)
#   ../synthesis/15nm/CCS/NanGate_15nm_OCL_worst_low_conditional_ccs.db       -> path to the .db library for this technology+corner
#   2000         -> clock period (ps for 15nm, ns for 45/130nm)
#   1               -> integer core count
#   /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/do/synthesis_runs/tech_15nm/worst_low/replicate_false/all_DMR           -> absolute path to this iteration's output directory
# =============================================================================

# add desired design parameters
set ENABLE_REPLICATE false
set SYNTHESIS_TECHNOLOGY 15
set SYNTHESIS_CORNER "worst_low"
# available synthesis technologies 15, 45, 130 -- the specific library .db for the
# chosen technology AND PVT corner is selected by run_synthesis_sweep.py and
# substituted below.

set GPGPU_GENERIC_ROOT "../"
set MODULES_ROOT "../modules/"
set PACKAGES_ROOT "../packages/"

set SYNTHESIS_PATH "../synthesis/15nm/CCS/NanGate_15nm_OCL_worst_low_conditional_ccs.db"

set NCORES 1

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
		read_vhdl $src
	}
}

foreach src $modules_src {
	if [expr {[string first # $src] eq 0}] {puts $src} else {
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

elaborate RTL_DSP_TOP -parameters "THREAD_POOL_SIZE=$THREAD_POOL_SIZE, accl_en=$accl_en, replicate_accl_en=$replicate_accl_en, multithreaded_accl_en=$multithreaded_accl_en, SPM_NUM=$SPM_NUM, Addr_Width=$Addr_Width, SIMD=$SIMD, TPS_CEIL=$TPS_CEIL, TPS_BUF_CEIL=$TPS_BUF_CEIL, SPM_ADDR_WID=$SPM_ADDR_WID, SIMD_BITS=$SIMD_BITS, Data_Width=$Data_Width, SIMD_Width=$SIMD_Width, ACCL_NUM=$ACCL_NUM, FU_NUM=$FU_NUM"

link

check_design

# Target clock frequency 500MHz. Period units follow the tech lib timeunit
# (ns for 45/130nm, ps for 15nm) -- the value is set per-technology by the sweep.
create_clock -name clk_i -period 2000 clk_i

compile

# ---------------------------------------------------------------------------
# Per-iteration outputs (filled in by run_synthesis_sweep.py)
# ---------------------------------------------------------------------------
file mkdir /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/do/synthesis_runs/tech_15nm/worst_low/replicate_false/all_DMR

write -f verilog -hierarchy -output /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/do/synthesis_runs/tech_15nm/worst_low/replicate_false/all_DMR/netlist.v

report_timing -transition_time -nets -attributes -nosplit > /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/do/synthesis_runs/tech_15nm/worst_low/replicate_false/all_DMR/Report_time_transition.txt
report_timing -delay max -nosplit                         > /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/do/synthesis_runs/tech_15nm/worst_low/replicate_false/all_DMR/Report_time_delay_max.txt
report_timing -path full -nosplit                         > /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/do/synthesis_runs/tech_15nm/worst_low/replicate_false/all_DMR/Report_time_path_full.txt
report_area      -nosplit -hierarchy > /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/do/synthesis_runs/tech_15nm/worst_low/replicate_false/all_DMR/Report_Area.txt
report_power     -nosplit -hierarchy > /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/do/synthesis_runs/tech_15nm/worst_low/replicate_false/all_DMR/Report_Power.txt
report_reference -nosplit -hierarchy > /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/do/synthesis_runs/tech_15nm/worst_low/replicate_false/all_DMR/Report_References.txt
report_resources -nosplit -hierarchy > /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/do/synthesis_runs/tech_15nm/worst_low/replicate_false/all_DMR/Report_Resources.txt
report_cell                          > /home/b.mansour/Desktop/klessydra_git/DSP_BreakDown/do/synthesis_runs/tech_15nm/worst_low/replicate_false/all_DMR/Report_Cells.txt

exit
