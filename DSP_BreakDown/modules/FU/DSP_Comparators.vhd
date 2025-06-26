-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Comparators is
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
    MVTYPE_DSP                      : in array_2d(ACCL_NUM-1 downto 0)(1 downto 0);
    relu_instr                      : in std_logic_vector(ACCL_NUM-1 downto 0);
    -- inputs from DSP_pipeline_controller
    halt_dsp_lat                    : in std_logic_vector(ACCL_NUM-1 downto 0);
    cmp_stage_1_en                  : in std_logic_vector(ACCL_NUM-1 downto 0);
    -- inputs from DSP_Excpt_Unit
    recover_state_wires             : in std_logic_vector(ACCL_NUM-1 downto 0);
    -- inputs from DSP_FU_Handler
    cmp_en                          : in std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the shifters
    -- inputs from DSP_Mapping
    dsp_in_cmp_operands             : in array_2d(FU_NUM-1 downto 0)(SIMD_Width-1 downto 0);
    -- inputs from adders
    MSB_stage_2                     : in array_3d(ACCL_NUM-1 downto 0)(1 downto 0)(4*SIMD-1 downto 0);
  
    -- outputs for DSP_Mapping
    dsp_out_cmp_results             : out array_2d(FU_NUM-1 downto 0)(SIMD_Width-1 downto 0)
  );
end entity DSP_Comparators;

architecture DSP_Comparators_arch of DSP_Comparators is

  subtype accl_range is integer range ACCL_NUM - 1 downto 0;
  subtype fu_range   is integer range FU_NUM - 1 downto 0;

  component DSP_Comparators_Unit is
    generic(
      SIMD                  : natural;
      --------------------------------
      SIMD_Width            : natural
    );
    port(
      -- Core Signals
      clk_i, rst_ni                   : in std_logic;
      -- inputs from DSP_Exec_Unit
      MVTYPE_DSP                      : in std_logic_vector(1 downto 0);
      relu_instr                      : in std_logic;
      -- inputs from DSP_pipeline_controller
      halt_dsp_lat                    : in std_logic;
      cmp_stage_1_en                  : in std_logic;
      -- inputs from DSP_Excpt_Unit
      recover_state_wires             : in std_logic;
      -- inputs from DSP_FU_Handler
      cmp_en                          : in std_logic;  -- enables the use of the shifters
      -- inputs from DSP_Mapping
      dsp_in_cmp_operands             : in std_logic_vector(SIMD_Width-1 downto 0);
      -- inputs from adders
      MSB_stage_2                     : in array_2d(1 downto 0)(4*SIMD-1 downto 0);
    
      -- outputs for DSP_Mapping
      dsp_out_cmp_results             : out std_logic_vector(SIMD_Width-1 downto 0)
    );
  end component DSP_Comparators_Unit;
begin
  COMPARATOR_MULTICORE: if multithreaded_accl_en = 0 generate
    DSP_Comparators_replicated: for h in accl_range generate
      DSP_Comparators_Unit_inst: DSP_Comparators_Unit
        generic map(
          SIMD                  => SIMD,
          --------------------------------
          SIMD_Width            => SIMD_Width
        )
        port map(
          clk_i                 => clk_i,
          rst_ni                => rst_ni,
          MVTYPE_DSP            => MVTYPE_DSP(h),
          relu_instr            => relu_instr(h),
          halt_dsp_lat          => halt_dsp_lat(h),
          cmp_stage_1_en        => cmp_stage_1_en(h),
          recover_state_wires   => recover_state_wires(h),
          cmp_en                => cmp_en(h),
          dsp_in_cmp_operands   => dsp_in_cmp_operands(h),
          MSB_stage_2           => MSB_stage_2(h),
          dsp_out_cmp_results   => dsp_out_cmp_results(h)
        );
    end generate DSP_Comparators_replicated;
  end generate COMPARATOR_MULTICORE;

  COMPARATOR_MULTITHREAD: if multithreaded_accl_en = 1 generate
    DSP_Comparators_replicated: for h in accl_range generate
      DSP_Comparators_Unit_inst: DSP_Comparators_Unit
        generic map(
          SIMD                  => SIMD,
          --------------------------------
          SIMD_Width            => SIMD_Width
        )
        port map(
          clk_i                 => clk_i,
          rst_ni                => rst_ni,
          MVTYPE_DSP            => MVTYPE_DSP(h),
          relu_instr            => relu_instr(h),
          halt_dsp_lat          => halt_dsp_lat(h),
          cmp_stage_1_en        => cmp_stage_1_en(h),
          recover_state_wires   => recover_state_wires(h),
          cmp_en                => cmp_en(h),
          dsp_in_cmp_operands   => dsp_in_cmp_operands(0),
          MSB_stage_2           => MSB_stage_2(0),
          dsp_out_cmp_results   => dsp_out_cmp_results(0)
        );
    end generate DSP_Comparators_replicated;
  end generate COMPARATOR_MULTITHREAD;
end architecture DSP_Comparators_arch;