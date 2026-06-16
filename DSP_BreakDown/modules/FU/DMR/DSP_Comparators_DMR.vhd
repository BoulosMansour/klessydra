-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Comparators_DMR is
  generic(
    SIMD                  : natural;
    multithreaded_accl_en : natural;
    --------------------------------
    ACCL_NUM              : natural;
    FU_NUM                : natural;
    SIMD_Width            : natural
  );
  port(
    -- Core Signals
    clk_i, rst_ni                   : in std_logic;
    -- inputs from DSP_Exec_Unit
    MVTYPE_DSP                      : in array_2d_MVTYPE_DSP(ACCL_NUM-1 downto 0);
    relu_instr                      : in std_logic_vector(ACCL_NUM-1 downto 0);
    -- inputs from DSP_pipeline_controller
    halt_dsp_lat                    : in std_logic_vector(ACCL_NUM-1 downto 0);
    cmp_stage_1_en                  : in std_logic_vector(ACCL_NUM-1 downto 0);
    -- inputs from DSP_Excpt_Unit
    recover_state_wires             : in std_logic_vector(ACCL_NUM-1 downto 0);
    -- inputs from DSP_FU_Handler
    cmp_en                          : in std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the shifters
    -- inputs from DSP_Mapping
    dsp_in_cmp_operands             : in array_2d_dsp_operands(FU_NUM-1 downto 0);
    -- inputs from adders
    MSB_stage_2                     : in array_3d_MSB_stage(ACCL_NUM-1 downto 0);
  
    -- outputs for DSP_Mapping
    dsp_out_cmp_results             : out array_2d_dsp_operands(FU_NUM-1 downto 0)
  );
end entity DSP_Comparators_DMR;

architecture DSP_Comparators_DMR_arch of DSP_Comparators_DMR is

  type dmr_type_dsp_out_cmp_results is array (1 downto 0) of array_2d_dsp_operands(FU_NUM-1 downto 0);

  signal dmr_dsp_out_cmp_results : dmr_type_dsp_out_cmp_results;

  component DMR is
    port(
      in1, in2 : in std_logic;
      err_flag : out std_logic;
      result : out std_logic
    );
  end component DMR;

  component DSP_Comparators is
    generic(
      SIMD                  : natural;
      multithreaded_accl_en : natural;
      --------------------------------
      ACCL_NUM              : natural;
      FU_NUM                : natural;
      SIMD_Width            : natural
    );
    port(
      -- Core Signals
      clk_i, rst_ni                   : in std_logic;
      -- inputs from DSP_Exec_Unit
      MVTYPE_DSP                      : in array_2d_MVTYPE_DSP(ACCL_NUM-1 downto 0);
      relu_instr                      : in std_logic_vector(ACCL_NUM-1 downto 0);
      -- inputs from DSP_pipeline_controller
      halt_dsp_lat                    : in std_logic_vector(ACCL_NUM-1 downto 0);
      cmp_stage_1_en                  : in std_logic_vector(ACCL_NUM-1 downto 0);
      -- inputs from DSP_Excpt_Unit
      recover_state_wires             : in std_logic_vector(ACCL_NUM-1 downto 0);
      -- inputs from DSP_FU_Handler
      cmp_en                          : in std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the shifters
      -- inputs from DSP_Mapping
      dsp_in_cmp_operands             : in array_2d_dsp_operands(FU_NUM-1 downto 0);
      -- inputs from adders
      MSB_stage_2                     : in array_3d_MSB_stage(ACCL_NUM-1 downto 0);
    
      -- outputs for DSP_Mapping
      dsp_out_cmp_results             : out array_2d_dsp_operands(FU_NUM-1 downto 0)
    );
  end component DSP_Comparators;

begin

  replicate_comparators: for i in 0 to 1 generate
    dsp_comparators_inst: DSP_Comparators
      generic map(
        SIMD                  => SIMD,
        multithreaded_accl_en => multithreaded_accl_en,
        ACCL_NUM              => ACCL_NUM,
        FU_NUM                => FU_NUM,
        SIMD_Width            => SIMD_Width
      )
      port map(
        clk_i                   => clk_i,
        rst_ni                  => rst_ni,
        MVTYPE_DSP              => MVTYPE_DSP,
        relu_instr              => relu_instr,
        halt_dsp_lat            => halt_dsp_lat,
        cmp_stage_1_en          => cmp_stage_1_en,
        recover_state_wires     => recover_state_wires,
        cmp_en                  => cmp_en,
        dsp_in_cmp_operands     => dsp_in_cmp_operands,
        MSB_stage_2             => MSB_stage_2,
        dsp_out_cmp_results     => dmr_dsp_out_cmp_results(i)
      );
  end generate replicate_comparators;

  replicate_DMR_dsp_out_cmp_results_i: for i in 0 to FU_NUM-1 generate
    replicate_DMR_dsp_out_cmp_results_j: for j in 0 to SIMD_Width-1 generate
      dmr_dsp_out_cmp_results_inst: DMR
        port map (
          in1     => dmr_dsp_out_cmp_results(0)(i)(j),
          in2     => dmr_dsp_out_cmp_results(1)(i)(j),
          err_flag => open,
          result  => dsp_out_cmp_results(i)(j)
        );
      end generate replicate_DMR_dsp_out_cmp_results_j;
  end generate replicate_DMR_dsp_out_cmp_results_i;
        

end architecture DSP_Comparators_DMR_arch;