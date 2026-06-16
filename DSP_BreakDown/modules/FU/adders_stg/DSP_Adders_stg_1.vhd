-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Adders_stg_1 is
  generic (
    SIMD            : natural;  
    --------------------------
    SIMD_Width      : natural
  );  
  port(
    -- inputs from DSP_pipeline_controller
    adder_stage_1_en                : in std_logic;
    -- inputs from DSP_Exec_Unit
    carry_pass                      : in std_logic_vector(2 downto 0);  -- carry enable signal, depending on it's configuration, we can do KADDV8, KADDV16, KADDV32
    twos_complement                 : in std_logic_vector(31 downto 0);
    --inputs from DSP_Excpt_Unit
    recover_state_wires             : in std_logic;
    -- inputs from DSP_mapping
    dsp_in_adder_operands           : in array_2d_dsp_operands(1 downto 0);
    -- inputs for Adder
    dsp_add_8_0                     : in array_2d_dsp_add(SIMD-1 downto 0); -- 9-bits, contains the results of 8-bit adders
    dsp_add_16_8                    : in array_2d_dsp_add(SIMD-1 downto 0); -- 9-bits  contains the results of 8-bit adders

    -- outputs for Adder
    dsp_add_8_0_wire                : out array_2d_dsp_add(SIMD-1 downto 0); -- 9-bits, contains the results of 8-bit adders
    dsp_add_16_8_wire               : out array_2d_dsp_add(SIMD-1 downto 0); -- 9-bits  contains the results of 8-bit adders
    carry_16_wire                   : out std_logic_vector(SIMD-1 downto 0)  -- carry-out bit of the "dsp_add_16_8" signal
  );
end entity DSP_Adders_stg_1;

architecture DSP_Adders_stg_1_arch of DSP_Adders_stg_1 is
begin
  ------------------------------------------------------------------------------------------------
  --   █████╗ ██████╗ ██████╗ ███████╗██████╗ ███████╗    ███████╗████████╗ ██████╗        ██╗  --
  --  ██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗██╔════╝    ██╔════╝╚══██╔══╝██╔════╝       ███║  --
  --  ███████║██║  ██║██║  ██║█████╗  ██████╔╝███████╗    ███████╗   ██║   ██║  ███╗█████╗╚██║  --
  --  ██╔══██║██║  ██║██║  ██║██╔══╝  ██╔══██╗╚════██║    ╚════██║   ██║   ██║   ██║╚════╝ ██║  --
  --  ██║  ██║██████╔╝██████╔╝███████╗██║  ██║███████║    ███████║   ██║   ╚██████╔╝       ██║  --
  -- -╚═╝  ╚═╝╚═════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝    ╚══════╝   ╚═╝    ╚═════╝        ╚═╝  --
  ------------------------------------------------------------------------------------------------
    
  fsm_DSP_adder_stage_1 : process(all)
  variable dsp_add_8_0_wire_var, dsp_add_16_8_wire_var  : array_2d_dsp_add(SIMD-1 downto 0);
  variable carry_8_wire                         : std_logic_vector(SIMD-1 downto 0);  -- carry-out bit of the "dsp_add_8_0" signal
  begin
    dsp_add_8_0_wire_var  := dsp_add_8_0;
    dsp_add_16_8_wire_var := dsp_add_16_8;
    --  Addition in SIMD Virtual Parallelism is executed here, if the carries are blocked, we will have a chain of 8-bit or 16-bit adders, else we have 32-bit adders
    for i in 0 to SIMD-1 loop
      if (adder_stage_1_en = '1' or recover_state_wires = '1') then
        -- Unwinding the loop: 
        -- (1) the term "8*(4*i)" is used to jump between the 32-bit words, inside the 128-bit values read by the DSP
        -- (2) Each addition results in an 8-bit value, and the 9th bit being the carry, depending on the instruction (KADDV32, KADDV16, KADDV8) we either pass the or block the carries.
        -- (3) CARRIES:
          -- (a) If we pass all the carries in the 32-bit word, we will have executed KADDV32 (4*32-bit parallel additions)
          -- (b) If we pass the 9th and 25th carries we would have executed KADDV16 (8*16-bit parallel additions)
          -- (c) If we pass none of the carries then we would have executed KADDV8 (16*8-bit parallel additions)
        dsp_add_8_0_wire_var(i)   := std_logic_vector('0' & unsigned(dsp_in_adder_operands(0)(7+8*(4*i)  downto 8*(4*i)))   + unsigned(dsp_in_adder_operands(1)(7+8*(4*i)  downto 8*(4*i))) + ("0000000" & twos_complement(0+(4*i))));
        dsp_add_16_8_wire_var(i)  := std_logic_vector('0' & unsigned(dsp_in_adder_operands(0)(15+8*(4*i) downto 8+8*(4*i))) + unsigned(dsp_in_adder_operands(1)(15+8*(4*i) downto 8+8*(4*i))) + ("0000000" & carry_8_wire(i)) + ("0000000" & twos_complement(1+(4*i))));
        -- All the 8-bit adders are lumped into one output write signal that will write to the scratchpads
        -- Carries are either passed or blocked for the 9-th, 17-th, and 25-th bits
        dsp_add_8_0_wire(i)   <= dsp_add_8_0_wire_var(i);
        dsp_add_16_8_wire(i)  <= dsp_add_16_8_wire_var(i);
        carry_8_wire(i)  := dsp_add_8_0_wire_var(i)(8)   and carry_pass(0);
        carry_16_wire(i) <= dsp_add_16_8_wire_var(i)(8)  and carry_pass(1);

      end if;
    end loop;
  end process;
end architecture DSP_Adders_stg_1_arch;