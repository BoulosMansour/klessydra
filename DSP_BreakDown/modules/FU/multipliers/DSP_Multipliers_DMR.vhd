-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Multipliers_DMR is
  generic(
    SIMD                  : natural;
    multithreaded_accl_en : natural;
    --------------------------------
    ACCL_NUM              : natural;
    FU_NUM                : natural;
    SIMD_Width            : natural;
    Data_Width            : natural
  );
  port(
    -- Core Signals
    clk_i, rst_ni                   : in std_logic;
    -- inputs from DSP_Exec_Unit
    FUNCT_SELECT_MASK               : array_2d(ACCL_NUM-1 downto 0)(31 downto 0); -- when the mask is set to "FFFFFFFF" we enable KDOTP32 execution using the 16-bit muls
    MVTYPE_DSP                      : array_2d(ACCL_NUM-1 downto 0)(1 downto 0);
    -- inputs DSP_Excpt_Unit
    recover_state_wires             : std_logic_vector(ACCL_NUM - 1 downto 0);
    -- inputs from DSP_pipeline_controller
    halt_dsp_lat                    : std_logic_vector(ACCL_NUM - 1 downto 0);
    mul_stage_1_en                  : std_logic_vector(ACCL_NUM - 1 downto 0);
    mul_stage_2_en                  : std_logic_vector(ACCL_NUM - 1 downto 0);
    -- inputs from DSP_FU_Handler
    mul_en                          : std_logic_vector(ACCL_NUM - 1 downto 0);  -- enables the use of the multipliers
    -- inputs from DSP_Mapping
    dsp_in_mul_operands             : array_3d(FU_NUM-1 downto 0)(1 downto 0)(SIMD_Width-1 downto 0);
  
    --outputs for DSP_Mapping
    dsp_out_mul_results             : out array_2d(FU_NUM-1 downto 0)(SIMD_Width-1 downto 0)
  );
end entity DSP_Multipliers_DMR;

architecture DSP_Multipliers_DMR_arch of DSP_Multipliers_DMR is
signal dsp_out_mul_results_DMR : array_3d(1 downto 0)(FU_NUM-1 downto 0)(SIMD_Width-1 downto 0);
signal err_flag_DMR : array_2d(FU_NUM-1 downto 0)(SIMD_Width-1 downto 0);

component DMR is
	port(
		in1, in2 : in std_logic;
		err_flag : out std_logic;
		result : out std_logic
	);
end component DMR;

component DSP_Multipliers is
  generic(
    SIMD                  : natural;
    multithreaded_accl_en : natural;
    --------------------------------
    ACCL_NUM              : natural;
    FU_NUM                : natural;
    SIMD_Width            : natural;
    Data_Width            : natural
  );
  port(
    -- Core Signals
    clk_i, rst_ni                   : in std_logic;
    -- inputs from DSP_Exec_Unit
    FUNCT_SELECT_MASK               : array_2d(ACCL_NUM-1 downto 0)(31 downto 0); -- when the mask is set to "FFFFFFFF" we enable KDOTP32 execution using the 16-bit muls
    MVTYPE_DSP                      : array_2d(ACCL_NUM-1 downto 0)(1 downto 0);
    -- inputs DSP_Excpt_Unit
    recover_state_wires             : std_logic_vector(ACCL_NUM - 1 downto 0);
    -- inputs from DSP_pipeline_controller
    halt_dsp_lat                    : std_logic_vector(ACCL_NUM - 1 downto 0);
    mul_stage_1_en                  : std_logic_vector(ACCL_NUM - 1 downto 0);
    mul_stage_2_en                  : std_logic_vector(ACCL_NUM - 1 downto 0);
    -- inputs from DSP_FU_Handler
    mul_en                          : std_logic_vector(ACCL_NUM - 1 downto 0);  -- enables the use of the multipliers
    -- inputs from DSP_Mapping
    dsp_in_mul_operands             : array_3d(FU_NUM-1 downto 0)(1 downto 0)(SIMD_Width-1 downto 0);
  
    --outputs for DSP_Mapping
    dsp_out_mul_results             : out array_2d(FU_NUM-1 downto 0)(SIMD_Width-1 downto 0)
  );
end component DSP_Multipliers;
begin

	DSP_Multipliers_replicated_DMR: for h in 0 to 1 generate
		DSP_Multipliers_inst: DSP_Multipliers
			generic map(
					SIMD                  => SIMD,
					multithreaded_accl_en => multithreaded_accl_en,
					ACCL_NUM              => ACCL_NUM,
					FU_NUM                => FU_NUM,
					SIMD_Width            => SIMD_Width,
					Data_Width            => Data_Width
			)
			port map(
					clk_i                   => clk_i,
					rst_ni                  => rst_ni,
					FUNCT_SELECT_MASK       => FUNCT_SELECT_MASK,
					MVTYPE_DSP              => MVTYPE_DSP,
					recover_state_wires     => recover_state_wires,
					halt_dsp_lat            => halt_dsp_lat,
					mul_stage_1_en          => mul_stage_1_en,
					mul_stage_2_en          => mul_stage_2_en,
					mul_en                  => mul_en,
					dsp_in_mul_operands     => dsp_in_mul_operands,
					dsp_out_mul_results     => dsp_out_mul_results_DMR(h)
			);
	end generate DSP_Multipliers_replicated_DMR;

	DMR_multipliers_i: for i in 0 to FU_NUM-1 generate
		DMR_multipliers_j: for j in 0 to SIMD_Width-1 generate
			DMR_inst: DMR
				port map(
					in1      => dsp_out_mul_results_DMR(0)(i)(j),
					in2      => dsp_out_mul_results_DMR(1)(i)(j),
					err_flag => err_flag_DMR(i)(j),
					result   => dsp_out_mul_results(i)(j)
				);
		end generate DMR_multipliers_j;
	end generate DMR_multipliers_i;					
end architecture DSP_Multipliers_DMR_arch;