-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Shifters is
  generic(
    multithreaded_accl_en : natural;
    SIMD                  : natural;
    --------------------------------
    ACCL_NUM              : natural;
    FU_NUM                : natural;
    SIMD_Width            : natural
  );
  port(
    -- Core Signals
    clk_i, rst_ni                   : in std_logic;
    -- inputs from DSP_pipeline_controller
    shifter_stage_1_en              : in std_logic_vector(ACCL_NUM - 1 downto 0);
    shifter_stage_2_en              : in std_logic_vector(ACCL_NUM - 1 downto 0);
    halt_dsp_lat                    : in std_logic_vector(ACCL_NUM - 1 downto 0);
    -- inputs from DSP_Exec_Unit
    MVTYPE_DSP                      : in array_2d(ACCL_NUM - 1 downto 0)(1 downto 0);
    decoded_instruction_DSP_lat     : in array_2d(ACCL_NUM - 1 downto 0)(DSP_UNIT_INSTR_SET_SIZE -1 downto 0);
    -- inputs from DSP_Excpt_Unit
    recover_state_wires             : in std_logic_vector(ACCL_NUM - 1 downto 0);
    -- inputs from DSP_FU_Handler
    shift_en                        : in std_logic_vector(ACCL_NUM - 1 downto 0);  -- enables the use of the shifters
    -- inputs from DSP_Mapping
    dsp_in_shifter_operand          : in array_2d(FU_NUM-1 downto 0)(SIMD_Width-1 downto 0);
    dsp_in_shift_amount             : in array_2d(ACCL_NUM - 1 downto 0)(4 downto 0);

    --outputs for DSP_Mapping
    dsp_out_shifter_results         : out array_2d(FU_NUM-1 downto 0)(SIMD_Width-1 downto 0)
  );
end entity DSP_Shifters;

architecture DSP_Shifters_arch of DSP_Shifters is

  subtype accl_range is integer range ACCL_NUM - 1 downto 0;
  subtype fu_range   is integer range FU_NUM - 1 downto 0;

  signal dsp_int_shifter_operand         : array_2d(fu_range)(SIMD_Width-1 downto 0);
  signal dsp_in_shifter_operand_lat      : array_2d(fu_range)(SIMD_Width-1 downto 0);  -- 15 bits because i only want to latch the signed bits
  signal dsp_in_shifter_operand_lat_wire : array_2d(fu_range)(SIMD_Width-1 downto 0);
  signal dsp_shift_enabler               : array_2d(accl_range)(15 downto 0);


  component DSP_Shifters_stg_1 is
    generic(
      SIMD                  : natural;
      --------------------------------
      SIMD_Width            : natural
    );
    port(
      -- Core Signals
      clk_i, rst_ni                   : in std_logic;
      -- inputs from DSP_pipeline_controller
      shifter_stage_1_en              : in std_logic;
      halt_dsp_lat                    : in std_logic;
      -- inputs from DSP_Exec_Unit
      MVTYPE_DSP                      : in std_logic_vector(1 downto 0);
      -- inputs from DSP_Excpt_Unit
      recover_state_wires             : in std_logic;
      -- inputs from DSP_FU_Handler
      shift_en                        : in std_logic;  -- enables the use of the shifters
      -- inputs from DSP_Mapping
      dsp_in_shifter_operand          : in std_logic_vector(SIMD_Width-1 downto 0);
      dsp_in_shift_amount             : in std_logic_vector(4 downto 0);

      -- outputs for shifter
      dsp_int_shifter_operand         : out std_logic_vector(SIMD_Width-1 downto 0);
      dsp_in_shifter_operand_lat      : out std_logic_vector(SIMD_Width-1 downto 0)  -- 15 bits because i only want to latch the signed bits
    );
  end component  DSP_Shifters_stg_1;

  component DSP_Shifters_stg_2 is
    generic(
      SIMD                  : natural;
      --------------------------------
      SIMD_Width            : natural
    );
    port(
      -- Core Signals
      clk_i, rst_ni                   : in std_logic;
      -- inputs from DSP_pipeline_controller
      shifter_stage_2_en              : in std_logic;
      halt_dsp_lat                    : in std_logic;
      -- inputs from DSP_Exec_Unit
      MVTYPE_DSP                      : in std_logic_vector(1 downto 0);
      decoded_instruction_DSP_lat     : in std_logic_vector(DSP_UNIT_INSTR_SET_SIZE -1 downto 0);
      -- inputs from DSP_Excpt_Unit
      recover_state_wires             : in std_logic;
      -- inputs from DSP_FU_Handler
      shift_en                        : in std_logic;  -- enables the use of the shifters
      -- inputs from Shifter
      dsp_in_shifter_operand_lat_wire : in std_logic_vector(SIMD_Width-1 downto 0);
      dsp_int_shifter_operand         : in std_logic_vector(SIMD_Width-1 downto 0);
      dsp_shift_enabler               : in std_logic_vector(15 downto 0);

      --outputs for DSP_Mapping
      dsp_out_shifter_results         : out std_logic_vector(SIMD_Width-1 downto 0)
    );
  end component DSP_Shifters_stg_2;

  component DSP_Shifters_comb is
    generic(
      SIMD                  : natural;
      --------------------------------
      SIMD_Width            : natural
    );
    port(
      -- inputs from DSP_FU_Handler
      shift_en                        : in std_logic;  -- enables the use of the shifters
      -- inputs from DSP_pipeline_controller
      halt_dsp_lat                    : in std_logic;
      -- inputs from DSP_Exec_Unit
      MVTYPE_DSP                      : in std_logic_vector(1 downto 0);
      decoded_instruction_DSP_lat     : in std_logic_vector(DSP_UNIT_INSTR_SET_SIZE -1 downto 0);
      -- inputs from DSP_Mapping
      dsp_in_shift_amount             : in std_logic_vector(4 downto 0);
      -- inputs from Shifter
      dsp_in_shifter_operand_lat      : in std_logic_vector(SIMD_Width-1 downto 0);

      -- outputs for shifter
      dsp_in_shifter_operand_lat_wire : out std_logic_vector(SIMD_Width-1 downto 0);
      dsp_shift_enabler               : out std_logic_vector(15 downto 0)
    );
  end component  DSP_Shifters_comb;

begin
  SHIFTER_MULTICORE: if multithreaded_accl_en = 0 generate
    DSP_SHIFTERS_replicated: for h in accl_range generate
      DSP_Shifters_stg_1_inst: DSP_Shifters_stg_1
        generic map(
          SIMD => SIMD,
          SIMD_Width => SIMD_Width
        )
        port map(
          clk_i => clk_i,
          rst_ni => rst_ni,
          shifter_stage_1_en => shifter_stage_1_en(h),
          halt_dsp_lat => halt_dsp_lat(h),
          MVTYPE_DSP => MVTYPE_DSP(h),
          recover_state_wires => recover_state_wires(h),
          shift_en => shift_en(h),
          dsp_in_shifter_operand => dsp_in_shifter_operand(h),
          dsp_in_shift_amount => dsp_in_shift_amount(h),
          dsp_int_shifter_operand => dsp_int_shifter_operand(h),
          dsp_in_shifter_operand_lat => dsp_in_shifter_operand_lat(h)
        );

      DSP_Shifters_stg_2_inst: DSP_Shifters_stg_2
        generic map(
          SIMD => SIMD,
          SIMD_Width => SIMD_Width
        )
        port map(
          clk_i => clk_i,
          rst_ni => rst_ni,
          shifter_stage_2_en => shifter_stage_2_en(h),
          halt_dsp_lat => halt_dsp_lat(h),
          MVTYPE_DSP => MVTYPE_DSP(h),
          decoded_instruction_DSP_lat => decoded_instruction_DSP_lat(h),
          recover_state_wires => recover_state_wires(h),
          shift_en => shift_en(h),
          dsp_in_shifter_operand_lat_wire => dsp_in_shifter_operand_lat_wire(h),
          dsp_int_shifter_operand => dsp_int_shifter_operand(h),
          dsp_shift_enabler => dsp_shift_enabler(h),
          dsp_out_shifter_results => dsp_out_shifter_results(h)
        );

      DSP_Shifters_comb_inst: DSP_Shifters_comb
        generic map(
          SIMD => SIMD,
          SIMD_Width => SIMD_Width
        )
        port map(
          shift_en => shift_en(h),
          halt_dsp_lat => halt_dsp_lat(h),
          MVTYPE_DSP => MVTYPE_DSP(h),
          decoded_instruction_DSP_lat => decoded_instruction_DSP_lat(h),
          dsp_in_shift_amount => dsp_in_shift_amount(h),
          dsp_in_shifter_operand_lat => dsp_in_shifter_operand_lat(h),
          dsp_in_shifter_operand_lat_wire => dsp_in_shifter_operand_lat_wire(h),
          dsp_shift_enabler => dsp_shift_enabler(h)
        );
    end generate DSP_SHIFTERS_replicated;
  end generate SHIFTER_MULTICORE;

  SHIFTER_MULTITHREAD: if multithreaded_accl_en = 1 generate
    DSP_SHIFTERS_replicated: for h in accl_range generate
      DSP_Shifters_stg_1_inst: DSP_Shifters_stg_1
        generic map(
          SIMD => SIMD,
          SIMD_Width => SIMD_Width
        )
        port map(
          clk_i => clk_i,
          rst_ni => rst_ni,
          shifter_stage_1_en => shifter_stage_1_en(h),
          halt_dsp_lat => halt_dsp_lat(h),
          MVTYPE_DSP => MVTYPE_DSP(h),
          recover_state_wires => recover_state_wires(h),
          shift_en => shift_en(h),
          dsp_in_shifter_operand => dsp_in_shifter_operand(0),
          dsp_in_shift_amount => dsp_in_shift_amount(0),
          dsp_int_shifter_operand => dsp_int_shifter_operand(0),
          dsp_in_shifter_operand_lat => dsp_in_shifter_operand_lat(0)
        );

      DSP_Shifters_stg_2_inst: DSP_Shifters_stg_2
        generic map(
          SIMD => SIMD,
          SIMD_Width => SIMD_Width
        )
        port map(
          clk_i => clk_i,
          rst_ni => rst_ni,
          shifter_stage_2_en => shifter_stage_2_en(h),
          halt_dsp_lat => halt_dsp_lat(h),
          MVTYPE_DSP => MVTYPE_DSP(h),
          decoded_instruction_DSP_lat => decoded_instruction_DSP_lat(h),
          recover_state_wires => recover_state_wires(h),
          shift_en => shift_en(h),
          dsp_in_shifter_operand_lat_wire => dsp_in_shifter_operand_lat_wire(0),
          dsp_int_shifter_operand => dsp_int_shifter_operand(0),
          dsp_shift_enabler => dsp_shift_enabler(h),
          dsp_out_shifter_results => dsp_out_shifter_results(0)
        );

      DSP_Shifters_comb_inst: DSP_Shifters_comb
        generic map(
          SIMD => SIMD,
          SIMD_Width => SIMD_Width
        )
        port map(
          shift_en => shift_en(h),
          halt_dsp_lat => halt_dsp_lat(h),
          MVTYPE_DSP => MVTYPE_DSP(h),
          decoded_instruction_DSP_lat => decoded_instruction_DSP_lat(h),
          dsp_in_shift_amount => dsp_in_shift_amount(h),
          dsp_in_shifter_operand_lat => dsp_in_shifter_operand_lat(0),
          dsp_in_shifter_operand_lat_wire => dsp_in_shifter_operand_lat_wire(0),
          dsp_shift_enabler => dsp_shift_enabler(h)
        );
      end generate DSP_SHIFTERS_replicated;
    end generate SHIFTER_MULTITHREAD;
end architecture DSP_Shifters_arch;