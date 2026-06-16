-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Adders_TMR is
  generic (
    multithreaded_accl_en : natural;
    SIMD                  : natural;  
    --------------------------------
    ACCL_NUM              : natural;
    FU_NUM                : natural;
    SIMD_Width            : natural
  );
  port(
    -- Core Signals
    clk_i, rst_ni                 : in std_logic;
    -- inputs from DSP_pipeline_controller
    halt_dsp_lat                    : in std_logic_vector(ACCL_NUM-1 downto 0);
    adder_stage_1_en                : in std_logic_vector(ACCL_NUM-1 downto 0); -- enables the use of the adders in stage 1
    adder_stage_2_en                : in std_logic_vector(ACCL_NUM-1 downto 0); -- enables the use of the adders in stage 2
    -- inputs from DSP_Exec_Unit
    carry_pass                      : in array_2d_carry_pass(ACCL_NUM-1 downto 0);  -- carry enable signal, depending on it's configuration, we can do KADDV8, KADDV16, KADDV32
    twos_complement                 : in array_2d_twos_complement(ACCL_NUM-1 downto 0);
    -- inputs from DSP_Excpt_Unit
    recover_state_wires             : in std_logic_vector(ACCL_NUM-1 downto 0); -- used to recover the state of the DSP, in case of an exception
    -- inputs from DSP_FU_Handler
    add_en                          : in std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the adders
    -- inputs from DSP_Mapping
    MSB_stage_1                     : in array_3d_MSB_stage(ACCL_NUM-1 downto 0);
    dsp_in_adder_operands           : in array_3d_dsp_operands(FU_NUM-1 downto 0);
   
    -- outputs for DSP_Mapping
    dsp_out_adder_results           : out array_2d_dsp_operands(FU_NUM-1 downto 0);
    -- outputs for comparator
    MSB_stage_2                     : out array_3d_MSB_stage(ACCL_NUM-1 downto 0)
    );
end entity DSP_Adders_TMR;

architecture DSP_Adders_TMR_arch of DSP_Adders_TMR is

  type tmr_type_dsp_out_adder_results is array (2 downto 0) of array_2d_dsp_operands(FU_NUM-1 downto 0);
  type tmr_type_MSB_stage is array (2 downto 0) of array_3d_MSB_stage(ACCL_NUM -1 downto 0);
  
  -- duplicated adder signals
  signal tmr_dsp_out_adder_results : tmr_type_dsp_out_adder_results;
  signal tmr_MSB_stage_2: tmr_type_MSB_stage;

  component TMR is
	port(
		in1, in2, in3 : in std_logic;
		result : out std_logic
	);
end component TMR;

  component DSP_Adders is
    generic (
      multithreaded_accl_en : natural;
      SIMD                  : natural;  
      --------------------------------
      ACCL_NUM              : natural;
      FU_NUM                : natural;
      SIMD_Width            : natural
    );
    port(
      -- Core Signals
      clk_i, rst_ni                 : in std_logic;
      -- inputs from DSP_pipeline_controller
      halt_dsp_lat                    : in std_logic_vector(ACCL_NUM-1 downto 0);
      adder_stage_1_en                : in std_logic_vector(ACCL_NUM-1 downto 0); -- enables the use of the adders in stage 1
      adder_stage_2_en                : in std_logic_vector(ACCL_NUM-1 downto 0); -- enables the use of the adders in stage 2
      -- inputs from DSP_Exec_Unit
      carry_pass                      : in array_2d_carry_pass(ACCL_NUM-1 downto 0);  -- carry enable signal, depending on it's configuration, we can do KADDV8, KADDV16, KADDV32
      twos_complement                 : in array_2d_twos_complement(ACCL_NUM-1 downto 0);
      -- inputs from DSP_Excpt_Unit
      recover_state_wires             : in std_logic_vector(ACCL_NUM-1 downto 0); -- used to recover the state of the DSP, in case of an exception
      -- inputs from DSP_FU_Handler
      add_en                          : in std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the adders
      -- inputs from DSP_Mapping
      MSB_stage_1                     : in array_3d_MSB_stage(ACCL_NUM-1 downto 0);
      dsp_in_adder_operands           : in array_3d_dsp_operands(FU_NUM-1 downto 0);
    
      -- outputs for DSP_Mapping
      dsp_out_adder_results           : out array_2d_dsp_operands(FU_NUM-1 downto 0);
      -- outputs for comparator
      MSB_stage_2                     : out array_3d_MSB_stage(ACCL_NUM-1 downto 0)
      );
  end component DSP_Adders;

begin

  replicate_adders: for i in 0 to 2 generate
    adders_inst: DSP_Adders
      generic map (
        multithreaded_accl_en => multithreaded_accl_en,
        SIMD                  => SIMD,  
        --------------------------------
        ACCL_NUM              => ACCL_NUM,
        FU_NUM                => FU_NUM,
        SIMD_Width            => SIMD_Width
      )
      port map (
        -- Core Signals
        clk_i                 => clk_i,
        rst_ni                => rst_ni,
        -- inputs from DSP_pipeline_controller
        halt_dsp_lat          => halt_dsp_lat,
        adder_stage_1_en     => adder_stage_1_en, -- enables the use of the adders in stage 1
        adder_stage_2_en     => adder_stage_2_en, -- enables the use of the adders in stage 2
        -- inputs from DSP_Exec_Unit
        carry_pass           => carry_pass,  -- carry enable signal, depending on it's configuration, we can do KADDV8, KADDV16, KADDV32
        twos_complement      => twos_complement,
        -- inputs from DSP_Excpt_Unit
        recover_state_wires  => recover_state_wires, -- used to recover the state of the DSP, in case of an exception
        -- inputs from DSP_FU_Handler
        add_en               => add_en,  -- enables the use of the adders
        -- inputs from DSP_Mapping
        MSB_stage_1          => MSB_stage_1,
        dsp_in_adder_operands=> dsp_in_adder_operands,
      
        -- outputs for DSP_Mapping
        dsp_out_adder_results=> tmr_dsp_out_adder_results(i),
        -- outputs for comparator
        MSB_stage_2          => tmr_MSB_stage_2(i)
      );
  end generate replicate_adders;

  replicate_TMR_dsp_out_adder_results_i: for i in 0 to FU_NUM-1 generate
    replicate_TMR_dsp_out_adder_results_j: for j in 0 to SIMD-1 generate
      tmr_dsp_out_adder_results_inst: TMR
        port map (
          in1     => tmr_dsp_out_adder_results(0)(i)(j),
          in2     => tmr_dsp_out_adder_results(1)(i)(j),
          in3     => tmr_dsp_out_adder_results(2)(i)(j),
          result  => dsp_out_adder_results(i)(j)
        );
      end generate replicate_TMR_dsp_out_adder_results_j;
  end generate replicate_TMR_dsp_out_adder_results_i;

  replicate_TMR_MSB_stage_2_i: for i in 0 to ACCL_NUM-1 generate
    replicate_TMR_MSB_stage_2_j: for j in 0 to 1 generate
      replicate_TMR_MSB_stage_2_k: for k in 0 to 4*SIMD-1 generate
        tmr_MSB_stage_2_inst: TMR
          port map (
            in1     => tmr_MSB_stage_2(0)(i)(j)(k),
            in2     => tmr_MSB_stage_2(1)(i)(j)(k),
            in3     => tmr_MSB_stage_2(2)(i)(j)(k),
            result  => MSB_stage_2(i)(j)(k)
          );
        end generate replicate_TMR_MSB_stage_2_k; 
      end generate replicate_TMR_MSB_stage_2_j;
  end generate replicate_TMR_MSB_stage_2_i;

end architecture DSP_Adders_TMR_arch;

