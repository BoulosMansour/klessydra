-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Shifters_DMR is
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
    MVTYPE_DSP                      : in array_2d_MVTYPE_DSP(ACCL_NUM - 1 downto 0);
    decoded_instruction_DSP_lat     : in array_2d_decoded_instruction_DSP_lat(ACCL_NUM - 1 downto 0);
    -- inputs from DSP_Excpt_Unit
    recover_state_wires             : in std_logic_vector(ACCL_NUM - 1 downto 0);
    -- inputs from DSP_FU_Handler
    shift_en                        : in std_logic_vector(ACCL_NUM - 1 downto 0);  -- enables the use of the shifters
    -- inputs from DSP_Mapping
    dsp_in_shifter_operand          : in array_2d_dsp_operands(FU_NUM-1 downto 0);
    dsp_in_shift_amount             : in array_2d_dsp_shift_amount(ACCL_NUM - 1 downto 0);

    --outputs for DSP_Mapping
    dsp_out_shifter_results         : out array_2d_dsp_operands(FU_NUM-1 downto 0)
  );
end entity DSP_Shifters_DMR;

architecture DSP_Shifters_DMR_arch of DSP_Shifters_DMR is
  type dmr_type_dsp_out_shifter_results is array (2 downto 0) of array_2d_dsp_operands(FU_NUM-1 downto 0);
  
  -- duplicated shifter signals
  signal dmr_dsp_out_shifter_results : dmr_type_dsp_out_shifter_results;
  
  component DMR is
    port(
      in1, in2 : in std_logic;
      err_flag : out std_logic;
      result : out std_logic
    );
  end component DMR;
  
  component DSP_Shifters is
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
    MVTYPE_DSP                      : in array_2d_MVTYPE_DSP(ACCL_NUM - 1 downto 0);
    decoded_instruction_DSP_lat     : in array_2d_decoded_instruction_DSP_lat(ACCL_NUM - 1 downto 0);
    -- inputs from DSP_Excpt_Unit
    recover_state_wires             : in std_logic_vector(ACCL_NUM - 1 downto 0);
    -- inputs from DSP_FU_Handler
    shift_en                        : in std_logic_vector(ACCL_NUM - 1 downto 0);  -- enables the use of the shifters
    -- inputs from DSP_Mapping
    dsp_in_shifter_operand          : in array_2d_dsp_operands(FU_NUM-1 downto 0);
    dsp_in_shift_amount             : in array_2d_dsp_shift_amount(ACCL_NUM - 1 downto 0);

    --outputs for DSP_Mapping
    dsp_out_shifter_results         : out array_2d_dsp_operands(FU_NUM-1 downto 0)
    );
  end component DSP_Shifters;

begin

  replicate_shifters: for i in 0 to 1 generate
    shifters_inst: DSP_Shifters
      generic map(
        multithreaded_accl_en => multithreaded_accl_en,
        SIMD                  => SIMD,
        --------------------------------
        ACCL_NUM              => ACCL_NUM,
        FU_NUM                => FU_NUM,
        SIMD_Width            => SIMD_Width
      )
      port map(
        -- Core Signals
        clk_i=> clk_i,
        rst_ni=> rst_ni,
        -- inputs from DSP_pipeline_controller
        shifter_stage_1_en=> shifter_stage_1_en,
        shifter_stage_2_en=> shifter_stage_2_en,
        halt_dsp_lat=> halt_dsp_lat,
        -- inputs from DSP_Exec_Unit
        MVTYPE_DSP=> MVTYPE_DSP,
        decoded_instruction_DSP_lat=> decoded_instruction_DSP_lat,
        -- inputs from DSP_Excpt_Unit
        recover_state_wires=> recover_state_wires,
        -- inputs from DSP_FU_Handler
        shift_en=> shift_en,
        -- inputs from DSP_Mapping
        dsp_in_shifter_operand=> dsp_in_shifter_operand,
        dsp_in_shift_amount=> dsp_in_shift_amount,

        -- outputs for DSP_Mapping
        dsp_out_shifter_results=> dmr_dsp_out_shifter_results(i)
      );
  end generate replicate_shifters;
  
  replicate_DMR_dsp_out_shifter_results_i: for i in 0 to FU_NUM-1 generate
    replicate_DMR_dsp_out_shifter_results_j: for j in 0 to SIMD_Width-1 generate
      dmr_dsp_out_shifter_results_inst: DMR
        port map (
          in1     => dmr_dsp_out_shifter_results(0)(i)(j),
          in2     => dmr_dsp_out_shifter_results(1)(i)(j),
          err_flag=> open,
          result  => dsp_out_shifter_results(i)(j)
        );
      end generate replicate_DMR_dsp_out_shifter_results_j;
  end generate replicate_DMR_dsp_out_shifter_results_i;

end architecture DSP_Shifters_DMR_arch;