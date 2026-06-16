-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Multipliers is
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
    FUNCT_SELECT_MASK               : array_2d_FUNCT_SELECT_MASK(ACCL_NUM-1 downto 0); -- when the mask is set to "FFFFFFFF" we enable KDOTP32 execution using the 16-bit muls
    MVTYPE_DSP                      : array_2d_MVTYPE_DSP(ACCL_NUM-1 downto 0);
    -- inputs DSP_Excpt_Unit
    recover_state_wires             : std_logic_vector(ACCL_NUM - 1 downto 0);
    -- inputs from DSP_pipeline_controller
    halt_dsp_lat                    : std_logic_vector(ACCL_NUM - 1 downto 0);
    mul_stage_1_en                  : std_logic_vector(ACCL_NUM - 1 downto 0);
    mul_stage_2_en                  : std_logic_vector(ACCL_NUM - 1 downto 0);
    -- inputs from DSP_FU_Handler
    mul_en                          : std_logic_vector(ACCL_NUM - 1 downto 0);  -- enables the use of the multipliers
    -- inputs from DSP_Mapping
    dsp_in_mul_operands             : array_3d_dsp_operands(FU_NUM-1 downto 0);
  
    --outputs for DSP_Mapping
    dsp_out_mul_results             : out array_2d_dsp_operands(FU_NUM-1 downto 0)
  );
end entity DSP_Multipliers;

architecture DSP_Multipliers_arch of DSP_Multipliers is

  subtype accl_range is integer range ACCL_NUM - 1 downto 0;
  subtype fu_range   is integer range FU_NUM - 1 downto 0;

  signal dsp_mul_a                       : array_2d_dsp_operands(fu_range); --  Contains the results of the 16-bit multipliers
  signal dsp_mul_b                       : array_2d_dsp_operands(fu_range); --  Contains the results of the 16-bit multipliers
  signal dsp_mul_c                       : array_2d_dsp_operands(fu_range); --  Contains the results of the 16-bit multipliers
  signal dsp_mul_d                       : array_2d_dsp_operands(fu_range); --  Contains the results of the 16-bit multipliers
  signal mul_tmp_a                       : array_3d_mul_tmp(fu_range);
  signal mul_tmp_b                       : array_3d_mul_tmp(fu_range);
  signal mul_tmp_c                       : array_3d_mul_tmp(fu_range);
  signal mul_tmp_d                       : array_3d_mul_tmp(fu_range);

  component DSP_Multipliers_stg_1 is
    generic (
      SIMD                  : natural;
      --------------------------------
      SIMD_Width            : natural
    );
    port(
      -- Core Signals
      clk_i, rst_ni                   : in std_logic;
      -- inputs from DSP_Exec_Unit
      FUNCT_SELECT_MASK               : in std_logic_vector(31 downto 0); -- when the mask is set to "FFFFFFFF" we enable KDOTP32 execution using the 16-bit muls
      -- inputs DSP_Excpt_Unit
      recover_state_wires             : in std_logic;
      -- inputs from DSP_pipeline_controller
      halt_dsp_lat                    : in std_logic;
      mul_stage_1_en                  : in std_logic;
      -- inputs from DSP_FU_Handler
      mul_en                          : in std_logic;  -- enables the use of the multipliers
      -- inputs from DSP_Mapping
      dsp_in_mul_operands             : in array_2d_dsp_operands(1 downto 0);
    
      -- outputs for multipliers
      dsp_mul_a                       : out std_logic_vector(SIMD_Width -1 downto 0); --  Contains the results of the 16-bit multipliers
      dsp_mul_b                       : out std_logic_vector(SIMD_Width -1 downto 0); --  Contains the results of the 16-bit multipliers
      dsp_mul_c                       : out std_logic_vector(SIMD_Width -1 downto 0); --  Contains the results of the 16-bit multipliers
      dsp_mul_d                       : out std_logic_vector(SIMD_Width -1 downto 0) --  Contains the results of the 16-bit multipliers
    );
  end component DSP_Multipliers_stg_1;

  component DSP_Multipliers_stg_1_comb is
    generic(
      SIMD                  : natural;
      --------------------------------
      Data_Width            : natural;
      SIMD_Width            : natural
    );
    port(
      -- inputs from DSP_Exec_Unit
      MVTYPE_DSP                      : in std_logic_vector(1 downto 0);
      -- inputs from DSP_pipeline_controller
      mul_stage_2_en                  : in std_logic;
      -- inputs form DSP_Excpt_Unit
      recover_state_wires             : in std_logic;
      -- inputs from DSP_FU_Handler
      mul_en                          : in  std_logic;  -- enables the use of the multipliers
      -- inputs from multipliers
      dsp_mul_a                       : in std_logic_vector(SIMD_Width -1 downto 0); --  Contains the results of the 16-bit multipliers
      dsp_mul_b                       : in std_logic_vector(SIMD_Width -1 downto 0); --  Contains the results of the 16-bit multipliers
      dsp_mul_c                       : in std_logic_vector(SIMD_Width -1 downto 0); --  Contains the results of the 16-bit multipliers
      dsp_mul_d                       : in std_logic_vector(SIMD_Width -1 downto 0); --  Contains the results of the 16-bit multipliers

      -- outputs for multipliers
      mul_tmp_a                       : out array_2d_mul_tmp(SIMD-1 downto 0);
      mul_tmp_b                       : out array_2d_mul_tmp(SIMD-1 downto 0);
      mul_tmp_c                       : out array_2d_mul_tmp(SIMD-1 downto 0);
      mul_tmp_d                       : out array_2d_mul_tmp(SIMD-1 downto 0)
    );
  end component DSP_Multipliers_stg_1_comb;

  component DSP_Multipliers_stg_2 is
    generic(
      SIMD                  : natural;
      --------------------------------
      Data_Width            : natural;
      SIMD_Width            : natural
    );
    port(
      -- Core Signals
      clk_i, rst_ni                   : in std_logic;
      -- inputs from DSP_Excpt_Unit
      recover_state_wires             : in std_logic;
      -- inputs from DSP_pipeline_controller
      mul_stage_2_en                  : in std_logic;
      halt_dsp_lat                    : in std_logic;
      -- inputs from DSP_FU_Handler
      mul_en                          : in std_logic;  -- enables the use of the multipliers
      -- inputs from multipliers
      mul_tmp_a                       : in array_2d_mul_tmp(SIMD-1 downto 0);
      mul_tmp_b                       : in array_2d_mul_tmp(SIMD-1 downto 0);
      mul_tmp_c                       : in array_2d_mul_tmp(SIMD-1 downto 0);
      mul_tmp_d                       : in array_2d_mul_tmp(SIMD-1 downto 0);

      --outputs for DSP_Mapping
      dsp_out_mul_results             : out std_logic_vector(SIMD_Width-1 downto 0)
    );
  end component DSP_Multipliers_stg_2;
begin 
  MULTIPLIER_MULTICORE: if multithreaded_accl_en = 0 generate
    DSP_Multipliers_stg_1_replicated: for h in accl_range generate
      DSP_Multipliers_stg_1_inst: DSP_Multipliers_stg_1
        generic map (
          SIMD                  => SIMD,
          SIMD_Width            => SIMD_Width
        )
        port map (
          clk_i                 => clk_i,
          rst_ni                => rst_ni,
          FUNCT_SELECT_MASK     => FUNCT_SELECT_MASK(h),
          recover_state_wires   => recover_state_wires(h),
          halt_dsp_lat          => halt_dsp_lat(h),
          mul_stage_1_en        => mul_stage_1_en(h),
          mul_en                => mul_en(h),
          dsp_in_mul_operands   => dsp_in_mul_operands(h),
          dsp_mul_a             => dsp_mul_a(h),
          dsp_mul_b             => dsp_mul_b(h),
          dsp_mul_c             => dsp_mul_c(h),
          dsp_mul_d             => dsp_mul_d(h)
        );

      DSP_Multipliers_stg_1_comb_inst: DSP_Multipliers_stg_1_comb
        generic map (
          SIMD                  => SIMD,
          Data_Width            => Data_Width,
          SIMD_Width            => SIMD_Width
        )
        port map (
          MVTYPE_DSP            => MVTYPE_DSP(h),
          mul_stage_2_en        => mul_stage_2_en(h),
          recover_state_wires   => recover_state_wires(h),
          mul_en                => mul_en(h),
          dsp_mul_a             => dsp_mul_a(h),
          dsp_mul_b             => dsp_mul_b(h),
          dsp_mul_c             => dsp_mul_c(h),
          dsp_mul_d             => dsp_mul_d(h),
          mul_tmp_a             => mul_tmp_a(h),
          mul_tmp_b             => mul_tmp_b(h),
          mul_tmp_c             => mul_tmp_c(h),
          mul_tmp_d             => mul_tmp_d(h)
        );

      DSP_Multipliers_stg_2_inst: DSP_Multipliers_stg_2
        generic map (
          SIMD                  => SIMD,
          Data_Width            => Data_Width,
          SIMD_Width            => SIMD_Width
        )
        port map (
          clk_i                 => clk_i,
          rst_ni                => rst_ni,
          recover_state_wires   => recover_state_wires(h),
          mul_stage_2_en        => mul_stage_2_en(h),
          halt_dsp_lat          => halt_dsp_lat(h),
          mul_en                => mul_en(h),
          mul_tmp_a             => mul_tmp_a(h),
          mul_tmp_b             => mul_tmp_b(h),
          mul_tmp_c             => mul_tmp_c(h),
          mul_tmp_d             => mul_tmp_d(h),
          dsp_out_mul_results   => dsp_out_mul_results(h)
        );
    end generate DSP_Multipliers_stg_1_replicated;
  end generate MULTIPLIER_MULTICORE;

  MULTIPLIER_MULTITHREAD: if multithreaded_accl_en = 1 generate
    DSP_Multipliers_stg_1_replicated: for h in accl_range generate
      DSP_Multipliers_stg_1_inst: DSP_Multipliers_stg_1
        generic map (
          SIMD                  => SIMD,
          SIMD_Width            => SIMD_Width
        )
        port map (
          clk_i                 => clk_i,
          rst_ni                => rst_ni,
          FUNCT_SELECT_MASK     => FUNCT_SELECT_MASK(h),
          recover_state_wires   => recover_state_wires(h),
          halt_dsp_lat          => halt_dsp_lat(h),
          mul_stage_1_en        => mul_stage_1_en(h),
          mul_en                => mul_en(h),
          dsp_in_mul_operands   => dsp_in_mul_operands(0),
          dsp_mul_a             => dsp_mul_a(0),
          dsp_mul_b             => dsp_mul_b(0),
          dsp_mul_c             => dsp_mul_c(0),
          dsp_mul_d             => dsp_mul_d(0)
        );

      DSP_Multipliers_stg_1_comb_inst: DSP_Multipliers_stg_1_comb
        generic map (
          SIMD                  => SIMD,
          Data_Width            => Data_Width,
          SIMD_Width            => SIMD_Width
        )
        port map (
          MVTYPE_DSP            => MVTYPE_DSP(h),
          mul_stage_2_en        => mul_stage_2_en(h),
          recover_state_wires   => recover_state_wires(h),
          mul_en                => mul_en(h),
          dsp_mul_a             => dsp_mul_a(0),
          dsp_mul_b             => dsp_mul_b(0),
          dsp_mul_c             => dsp_mul_c(0),
          dsp_mul_d             => dsp_mul_d(0),
          mul_tmp_a             => mul_tmp_a(0),
          mul_tmp_b             => mul_tmp_b(0),
          mul_tmp_c             => mul_tmp_c(0),
          mul_tmp_d             => mul_tmp_d(0)
        );

      DSP_Multipliers_stg_2_inst: DSP_Multipliers_stg_2
        generic map (
          SIMD                  => SIMD,
          Data_Width            => Data_Width,
          SIMD_Width            => SIMD_Width
        )
        port map (
          clk_i                 => clk_i,
          rst_ni                => rst_ni,
          recover_state_wires   => recover_state_wires(h),
          mul_stage_2_en        => mul_stage_2_en(h),
          halt_dsp_lat          => halt_dsp_lat(h),
          mul_en                => mul_en(h),
          mul_tmp_a             => mul_tmp_a(0),
          mul_tmp_b             => mul_tmp_b(0),
          mul_tmp_c             => mul_tmp_c(0),
          mul_tmp_d             => mul_tmp_d(0),
          dsp_out_mul_results   => dsp_out_mul_results(0)
        );
    end generate DSP_Multipliers_stg_1_replicated;
  end generate MULTIPLIER_MULTITHREAD;
end architecture DSP_Multipliers_arch;