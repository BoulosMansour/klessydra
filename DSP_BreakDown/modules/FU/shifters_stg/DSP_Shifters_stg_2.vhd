-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Shifters_stg_2 is
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

    -- outputs for DSP_Mapping
    dsp_out_shifter_results         : out std_logic_vector(SIMD_Width-1 downto 0)
  );
end entity DSP_Shifters_stg_2;

architecture DSP_Shifters_stg_2_arch of DSP_Shifters_stg_2 is
begin
  ----------------------------------------------------------------------------------------------------------------
  --  ███████╗██╗  ██╗██╗███████╗████████╗███████╗██████╗ ███████╗    ███████╗████████╗ ██████╗       ██████╗   --
  --  ██╔════╝██║  ██║██║██╔════╝╚══██╔══╝██╔════╝██╔══██╗██╔════╝    ██╔════╝╚══██╔══╝██╔════╝       ╚════██╗  --
  --  ███████╗███████║██║█████╗     ██║   █████╗  ██████╔╝███████╗    ███████╗   ██║   ██║  ███╗█████╗ █████╔╝  --
  --  ╚════██║██╔══██║██║██╔══╝     ██║   ██╔══╝  ██╔══██╗╚════██║    ╚════██║   ██║   ██║   ██║╚════╝██╔═══╝   --
  --  ███████║██║  ██║██║██║        ██║   ███████╗██║  ██║███████║    ███████║   ██║   ╚██████╔╝      ███████╗  --
  --  ╚══════╝╚═╝  ╚═╝╚═╝╚═╝        ╚═╝   ╚══════╝╚═╝  ╚═╝╚══════╝    ╚══════╝   ╚═╝    ╚═════╝       ╚══════╝  --
  ----------------------------------------------------------------------------------------------------------------

  fsm_DSP_shifter_stg_2 : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
    elsif rising_edge(clk_i) then
      if shift_en = '1' and (shifter_stage_2_en = '1' or recover_state_wires = '1') and halt_dsp_lat = '0' then
        if    MVTYPE_DSP = "10" then
          for i in 0 to SIMD-1 loop
            dsp_out_shifter_results(31+32*(i) downto 32*(i)) <= dsp_in_shifter_operand_lat_wire(31 +32*(i) downto 32*(i)) or dsp_int_shifter_operand(31+32*(i) downto 32*(i));
          end loop;
        elsif MVTYPE_DSP = "01" or (decoded_instruction_DSP_lat(KDOTPPS_bit_position) = '1' and MVTYPE_DSP = "00") then -- KDOTPPS8 has been added here because the number of elements loaded for mul operations is equal for 8-bit and 16-bits instr
          for i in 0 to 2*SIMD-1 loop
            dsp_out_shifter_results(15+16*(i) downto 16*(i)) <=  dsp_in_shifter_operand_lat_wire(15 +16*(i) downto 16*(i)) or (dsp_int_shifter_operand(15+16*(i) downto 16*(i)) and dsp_shift_enabler(15 downto 0));
          end loop;
        elsif MVTYPE_DSP = "00" then
          for i in 0 to 4*SIMD-1 loop
            dsp_out_shifter_results(7+8*(i) downto 8*(i)) <=  dsp_in_shifter_operand_lat_wire(7 +8*(i) downto 8*(i)) or  (dsp_int_shifter_operand(7+8*(i) downto 8*(i)) and dsp_shift_enabler(7 downto 0));
          end loop;
        end if;
      end if;
    end if;
  end process;
end architecture DSP_Shifters_stg_2_arch;