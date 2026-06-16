-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Shifters_stg_1 is
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
end entity DSP_Shifters_stg_1;

architecture DSP_Shifters_stg_1_arch of DSP_Shifters_stg_1 is
begin
  ------------------------------------------------------------------------------------------------------------
  --  ███████╗██╗  ██╗██╗███████╗████████╗███████╗██████╗ ███████╗    ███████╗████████╗ ██████╗        ██╗  --
  --  ██╔════╝██║  ██║██║██╔════╝╚══██╔══╝██╔════╝██╔══██╗██╔════╝    ██╔════╝╚══██╔══╝██╔════╝       ███║  --
  --  ███████╗███████║██║█████╗     ██║   █████╗  ██████╔╝███████╗    ███████╗   ██║   ██║  ███╗█████╗╚██║  --
  --  ╚════██║██╔══██║██║██╔══╝     ██║   ██╔══╝  ██╔══██╗╚════██║    ╚════██║   ██║   ██║   ██║╚════╝ ██║  --
  --  ███████║██║  ██║██║██║        ██║   ███████╗██║  ██║███████║    ███████║   ██║   ╚██████╔╝       ██║  --
  --  ╚══════╝╚═╝  ╚═╝╚═╝╚═╝        ╚═╝   ╚══════╝╚═╝  ╚═╝╚══════╝    ╚══════╝   ╚═╝    ╚═════╝        ╚═╝  --
  ------------------------------------------------------------------------------------------------------------

  fsm_DSP_shifter_stg_1 : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
    elsif rising_edge(clk_i) then
      if shift_en = '1' and (shifter_stage_1_en = '1' or recover_state_wires = '1') and halt_dsp_lat = '0' then
        for i in 0 to SIMD-1 loop
          dsp_int_shifter_operand(31+32*(i) downto 32*(i)) <= to_stdlogicvector(to_bitvector(dsp_in_shifter_operand(31+32*(i) downto 32*(i))) srl to_integer(unsigned(dsp_in_shift_amount)));
        end loop;
        --for i in 0 to 4*SIMD-1 loop -- latch the sign bits
          --dsp_in_sign_bits(i) <= dsp_in_shifter_operand(7+8*(i));
        --end loop;
        if MVTYPE_DSP = "00" then
          for i in 0 to 4*SIMD-1 loop -- latch the sign bits
            dsp_in_shifter_operand_lat(7+8*i downto 8*i) <= (others => dsp_in_shifter_operand(7+8*i));
          end loop;
        elsif MVTYPE_DSP = "01" then
          for i in 0 to 2*SIMD-1 loop -- latch the sign bits
            dsp_in_shifter_operand_lat(15+16*i downto 16*i) <= (others => dsp_in_shifter_operand(15+16*i));
          end loop;
        elsif MVTYPE_DSP = "10" then
          for i in 0 to SIMD-1 loop -- latch the sign bits
            dsp_in_shifter_operand_lat(31+32*i downto 32*i) <= (others => dsp_in_shifter_operand(31+32*i));
          end loop;
        end if;
      end if;
    end if;
  end process;
end architecture DSP_Shifters_stg_1_arch;