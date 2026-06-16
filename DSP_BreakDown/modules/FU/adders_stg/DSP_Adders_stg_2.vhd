-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Adders_stg_2 is
  generic(
    SIMD            : natural;
    --------------------------
    SIMD_Width      :natural
  );
  port(
    -- inputs from DSP_pipeline_controller
    halt_dsp_lat                    : in std_logic;
    adder_stage_2_en                : in std_logic;
    -- inputs from DSP_Exec_Unit
    twos_complement                 : in std_logic_vector(31 downto 0);
    carry_pass                      : in std_logic_vector(2 downto 0);  -- carry enable signal, depending on it's configuration, we can do KADDV8, KADDV16, KADDV32
    -- inputs from DSP_Excpt_Unit
    recover_state_wires             : in std_logic;
    -- inputs from Adder
    dsp_in_adder_operands_lat       : in array_2d_dsp_in_adder_operands_lat(1 downto 0); -- data_Width devided by the number of pipeline stages
    carry_16                        : in std_logic_vector(SIMD-1 downto 0);  -- carry-out bit of the "dsp_add_16_8" signal

    --output for Adder
    dsp_add_24_16_wire              : out array_2d_dsp_add(SIMD-1 downto 0); -- 9-bits  contains the results of 8-bit adders
    dsp_add_32_24_wire              : out array_2d_dsp_add(SIMD-1 downto 0) -- 9-bits, this should be 8 if we choose to discard the overflow of the addition of the upper byte
  );
end entity DSP_Adders_stg_2;

architecture DSP_Adders_stg_2_arch of DSP_Adders_stg_2 is
begin
  ---------------------------------------------------------------------------------------------------
  --   █████╗ ██████╗ ██████╗ ███████╗██████╗ ███████╗    ███████╗████████╗ ██████╗       ██████╗  --
  --  ██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗██╔════╝    ██╔════╝╚══██╔══╝██╔════╝       ╚════██╗ --
  --  ███████║██║  ██║██║  ██║█████╗  ██████╔╝███████╗    ███████╗   ██║   ██║  ███╗█████╗ █████╔╝ --
  --  ██╔══██║██║  ██║██║  ██║██╔══╝  ██╔══██╗╚════██║    ╚════██║   ██║   ██║   ██║╚════╝██╔═══╝  --
  --  ██║  ██║██████╔╝██████╔╝███████╗██║  ██║███████║    ███████║   ██║   ╚██████╔╝      ███████╗ --
  -- -╚═╝  ╚═╝╚═════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝    ╚══════╝   ╚═╝    ╚═════╝       ╚══════╝ --
  ---------------------------------------------------------------------------------------------------

  fsm_DSP_adder_stage_2 : process(all)
  variable dsp_add_24_16_wire_var          : array_2d_dsp_add(SIMD-1 downto 0);
  variable carry_24_wire                   : std_logic_vector(SIMD-1 downto 0);  -- carry-out bit of the "dsp_add_24_16" signal
  begin
    carry_24_wire               := (others => '0');
    dsp_add_24_16_wire_var     := (others => (others => '0'));
    dsp_add_32_24_wire          <= (others => (others => '0'));
      -- Addition is here
      if halt_dsp_lat = '0' then
      --  Addition in SIMD Virtual Parallelism is executed here, if the carries are blocked, we will have a chain of 8-bit or 16-bit adders, else we have 32-bit adders
        for i in 0 to SIMD-1 loop
          if (adder_stage_2_en = '1' or recover_state_wires = '1') then
            dsp_add_24_16_wire_var(i) := std_logic_vector('0' & unsigned(dsp_in_adder_operands_lat(0)(7+8*(2*i) downto 8*(2*i))) + 
                                                               unsigned(dsp_in_adder_operands_lat(1)(7+8*(2*i) downto 8*(2*i))) + 
                                                                        ("0000000" & carry_16(i)) + ("0000000" & twos_complement(2+(4*i))));
            dsp_add_32_24_wire(i) <= std_logic_vector('0' & unsigned(dsp_in_adder_operands_lat(0)(15+8*(2*i) downto 8+8*(2*i))) + 
                                                               unsigned(dsp_in_adder_operands_lat(1)(15+8*(2*i) downto 8+8*(2*i))) + 
                                                                        ("0000000" & carry_24_wire(i)) + ("0000000" & twos_complement(3+(4*i))));
            -- All the 8-bit adders are lumped into one output write signal that will write to the scratchpads
            -- Carries are either passed or blocked for the 9-th, 17-th, and 25-th bits
            dsp_add_24_16_wire <= dsp_add_24_16_wire_var;
            carry_24_wire(i) := dsp_add_24_16_wire_var(i)(8) and carry_pass(2);
            
          end if;
        end loop;
      end if;
  end process;
end architecture DSP_Adders_stg_2_arch;