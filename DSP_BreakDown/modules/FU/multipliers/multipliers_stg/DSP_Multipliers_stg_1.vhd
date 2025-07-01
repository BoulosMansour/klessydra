-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Multipliers_stg_1 is
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
    dsp_in_mul_operands             : in array_2d(1 downto 0)(SIMD_Width-1 downto 0);
  
    -- outputs for multipliers
    dsp_mul_a                       : out std_logic_vector(SIMD_Width -1 downto 0); --  Contains the results of the 16-bit multipliers
    dsp_mul_b                       : out std_logic_vector(SIMD_Width -1 downto 0); --  Contains the results of the 16-bit multipliers
    dsp_mul_c                       : out std_logic_vector(SIMD_Width -1 downto 0); --  Contains the results of the 16-bit multipliers
    dsp_mul_d                       : out std_logic_vector(SIMD_Width -1 downto 0) --  Contains the results of the 16-bit multipliers
  );
end entity DSP_Multipliers_stg_1;

architecture DSP_Multipliers_stg_1_arch of DSP_Multipliers_stg_1 is
begin
  --------------------------------------------------------------------------------------------------------------------------------
  --  ███╗   ███╗██╗   ██╗██╗  ████████╗██╗██████╗ ██╗     ██╗███████╗██████╗ ███████╗    ███████╗████████╗ ██████╗        ██╗  --
  --  ████╗ ████║██║   ██║██║  ╚══██╔══╝██║██╔══██╗██║     ██║██╔════╝██╔══██╗██╔════╝    ██╔════╝╚══██╔══╝██╔════╝       ███║  --
  --  ██╔████╔██║██║   ██║██║     ██║   ██║██████╔╝██║     ██║█████╗  ██████╔╝███████╗    ███████╗   ██║   ██║  ███╗█████╗╚██║  --
  --  ██║╚██╔╝██║██║   ██║██║     ██║   ██║██╔═══╝ ██║     ██║██╔══╝  ██╔══██╗╚════██║    ╚════██║   ██║   ██║   ██║╚════╝ ██║  --
  --  ██║ ╚═╝ ██║╚██████╔╝███████╗██║   ██║██║     ███████╗██║███████╗██║  ██║███████║    ███████║   ██║   ╚██████╔╝       ██║  --
  --  ╚═╝     ╚═╝ ╚═════╝ ╚══════╝╚═╝   ╚═╝╚═╝     ╚══════╝╚═╝╚══════╝╚═╝  ╚═╝╚══════╝    ╚══════╝   ╚═╝    ╚═════╝        ╚═╝  --
  --------------------------------------------------------------------------------------------------------------------------------
  -- STAGE 1 --
  fsm_MUL_STAGE_1 : process(clk_i,rst_ni)
  begin
    if rst_ni = '0' then
    elsif rising_edge(clk_i) then
      if halt_dsp_lat = '0' then
        if mul_en = '1' and (mul_stage_1_en = '1' or recover_state_wires = '1') then
        for i in 0 to SIMD-1 loop
            -- Unwinding the loop: 
            -- (1) The impelemtation in the loop does multiplication for KDOTP32, and KDOTP16 using only 16-bit multipliers. "A*B" = [Ahigh*(2^16) + Alow]*[Bhigh*(2^16) + Blow]
            -- (2) Expanding this equation "[Ahigh*(2^16) + Alow]*[Bhigh*(2^16) + Blow]"  gives: "Ahigh*Bhigh*(2^32) + Ahigh*Blow*(2^16) + Alow*Bhigh*(2^16) + Alow*Blow" which are the terms being stored in dsp_out_mul_results
            -- (3) Partial Multiplication 
                -- (a) "dsp_mul_a" <= Ahigh*Bhigh 
                -- (b) "dsp_mul_b" <= Ahigh*Blow
                -- (c) "dsp_mul_c" <= Alow*Bhigh
                -- (d) "dsp_mul_d" <= Alow*Blow
            -- (4) "dsp_mul_a" is shifted by 32 bits to the left, "dsp_mul_b" and "dsp_mul_c" are shifted by 16-bits to the left, "dsp_mul_d" is not shifted
            -- (5) For 16-bit and 8-bit muls, the FUNCT_SELECT_MASK is set to x"00000000" blocking the terms in "dsp_mul_b" and "dsp_mul_c". For executing 32-bit muls , we set the mask to x"FFFFFFFF"
            dsp_mul_a(31+32*(i)  downto 32*(i)) <= std_logic_vector(unsigned(dsp_in_mul_operands(0)(15+16*(2*i+1)    downto 16*(2*i+1))) * unsigned(dsp_in_mul_operands(1)(15+16*(2*i+1)  downto 16*(2*i+1))));
            dsp_mul_b(31+32*(i)  downto 32*(i)) <= std_logic_vector((unsigned(dsp_in_mul_operands(0)(16*(2*i+1) - 1  downto 16*(2*i)))   * unsigned(dsp_in_mul_operands(1)(15+16*(2*i+1)  downto 16*(2*i+1)))) and unsigned(FUNCT_SELECT_MASK));
            dsp_mul_c(31+32*(i)  downto 32*(i)) <= std_logic_vector((unsigned(dsp_in_mul_operands(0)(15+16*(2*i+1)   downto 16*(2*i+1))) * unsigned(dsp_in_mul_operands(1)(16*(2*i+1) - 1 downto 16*(2*i))))   and unsigned(FUNCT_SELECT_MASK));
            dsp_mul_d(31+32*(i)  downto 32*(i)) <= std_logic_vector(unsigned(dsp_in_mul_operands(0)(16*(2*i+1)  - 1  downto 16*(2*i)))   * unsigned(dsp_in_mul_operands(1)(16*(2*i+1) - 1 downto 16*(2*i))));
          end loop;
        end if;
      end if;
    end if;
  end process;
end architecture DSP_Multipliers_stg_1_arch;