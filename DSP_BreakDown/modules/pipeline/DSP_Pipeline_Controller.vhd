-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_pipeline_controller is
    port(
    -- Core Signals
    clk_i, rst_ni                   : in std_logic;
    -- Scratchpad Interface Signals
    dsp_data_gnt_i                  : in  std_logic;
    -- input from DSP_Exec_Unit
    nextstate_DSP                   : in std_logic_vector(1 downto 0);
    dotp                            : in std_logic;  -- indicator used in the pipeline handler to switch functional units
    dotpps                          : in std_logic;  -- indicator used in the pipeline handler to switch functional units
    slt                             : in std_logic;  -- indicator used in the pipeline handler to switch functional units
    -- input from mapping
    SIMD_RD_BYTES_wire              : in integer;
    --input from DSP_Excpt_Cntrl_Unit
    dsp_except_data_wire            : in std_logic_vector(31 downto 0);
    halt_dsp                        : in std_logic;
    busy_DSP_internal               : in std_logic;
    -- input from DSP_FU_Enabler_synchronizer
    cmp_en                          : in std_logic;  -- enables the use of the shifters
    shift_en                        : in std_logic;  -- enables the use of the shifters
    add_en                          : in std_logic;  -- enables the use of the adders
    mul_en                          : in std_logic;  -- enables the use of the multipliers
    accum_en                        : in std_logic;  -- enables the use of the accumulator

    --OUTPUTS
    dsp_data_gnt_i_lat              : out std_logic;
    adder_stage_1_en                : out std_logic;
    adder_stage_2_en                : out std_logic;
    adder_stage_3_en                : out std_logic;
    shifter_stage_1_en              : out std_logic;
    shifter_stage_2_en              : out std_logic;
    shifter_stage_3_en              : out std_logic;
    mul_stage_1_en                  : out std_logic;
    mul_stage_2_en                  : out std_logic;
    mul_stage_3_en                  : out std_logic;
    cmp_stage_1_en                  : out std_logic;
    cmp_stage_2_en                  : out std_logic;
    accum_stage_1_en                : out std_logic;
    accum_stage_2_en                : out std_logic;
    accum_stage_3_en                : out std_logic;
    halt_dsp_lat                    : out std_logic;
    busy_DSP_internal_lat           : out std_logic;
    SIMD_RD_BYTES                   : out integer;
    -- CSR Signals
    dsp_except_data                 : out std_logic_vector(31 downto 0);
    -- tracer signals
    state_DSP                       : out std_logic_vector(1 downto 0)
    );
end entity DSP_pipeline_controller;

architecture DSP_pipeline_controller_arch of DSP_pipeline_controller is
begin
  ---------------------------------------------------------------------------------------------------------------------------------------------------------
  --  ██████╗ ██╗██████╗ ███████╗██╗     ██╗███╗   ██╗███████╗     ██████╗ ██████╗ ███╗   ██╗████████╗██████╗  ██████╗ ██╗     ██╗     ███████╗██████╗   --
  --  ██╔══██╗██║██╔══██╗██╔════╝██║     ██║████╗  ██║██╔════╝    ██╔════╝██╔═══██╗████╗  ██║╚══██╔══╝██╔══██╗██╔═══██╗██║     ██║     ██╔════╝██╔══██╗  --
  --  ██████╔╝██║██████╔╝█████╗  ██║     ██║██╔██╗ ██║█████╗      ██║     ██║   ██║██╔██╗ ██║   ██║   ██████╔╝██║   ██║██║     ██║     █████╗  ██████╔╝  --
  --  ██╔═══╝ ██║██╔═══╝ ██╔══╝  ██║     ██║██║╚██╗██║██╔══╝      ██║     ██║   ██║██║╚██╗██║   ██║   ██╔══██╗██║   ██║██║     ██║     ██╔══╝  ██╔══██╗  --
  --  ██║     ██║██║     ███████╗███████╗██║██║ ╚████║███████╗    ╚██████╗╚██████╔╝██║ ╚████║   ██║   ██║  ██║╚██████╔╝███████╗███████╗███████╗██║  ██║  --
  --  ╚═╝     ╚═╝╚═╝     ╚══════╝╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝     ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝  --
  ---------------------------------------------------------------------------------------------------------------------------------------------------------

  fsm_DSP_pipeline_controller : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
      dsp_data_gnt_i_lat    <= '0';
      adder_stage_1_en      <= '0';
      adder_stage_2_en      <= '0';
      adder_stage_3_en      <= '0';
      shifter_stage_1_en    <= '0';
      shifter_stage_2_en    <= '0';
      mul_stage_1_en        <= '0';
      mul_stage_2_en        <= '0';
      mul_stage_3_en        <= '0';
      accum_stage_1_en      <= '0';
      accum_stage_2_en      <= '0';
      accum_stage_3_en      <= '0';
      cmp_stage_1_en        <= '0';
      cmp_stage_2_en        <= '0';
      busy_DSP_internal_lat <= '0';
      state_DSP             <= dsp_init;
    elsif rising_edge(clk_i) then
      dsp_data_gnt_i_lat   <= dsp_data_gnt_i;
      adder_stage_1_en     <= dsp_data_gnt_i_lat and add_en;
      adder_stage_2_en     <= adder_stage_1_en;
      adder_stage_3_en     <= adder_stage_2_en;
      mul_stage_1_en       <= dsp_data_gnt_i_lat and mul_en;
      mul_stage_2_en       <= mul_stage_1_en;
      mul_stage_3_en       <= mul_stage_2_en;
      accum_stage_2_en     <= accum_stage_1_en;
      accum_stage_3_en     <= accum_stage_2_en;
      shifter_stage_2_en   <= shifter_stage_1_en;
      shifter_stage_3_en   <= shifter_stage_2_en;
      cmp_stage_2_en       <= cmp_stage_1_en;
      if dotpps = '1' then
        shifter_stage_1_en <= mul_stage_2_en;
        accum_stage_1_en   <= shifter_stage_2_en;
      elsif dotp = '1' then
        accum_stage_1_en   <= mul_stage_2_en;
      elsif slt = '1' then
        cmp_stage_1_en     <= adder_stage_2_en;
      else
        shifter_stage_1_en <= dsp_data_gnt_i_lat and shift_en;
        accum_stage_1_en   <= dsp_data_gnt_i_lat and accum_en;
        cmp_stage_1_en     <= dsp_data_gnt_i_lat and cmp_en;
      end if;
      halt_dsp_lat          <= halt_dsp;
      state_DSP             <= nextstate_DSP;
      busy_DSP_internal_lat <= busy_DSP_internal;
      SIMD_RD_BYTES         <= SIMD_RD_BYTES_wire;
      dsp_except_data       <= dsp_except_data_wire;
    end if;
  end process;
end architecture DSP_pipeline_controller_arch;