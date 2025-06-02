-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Multipliers_stg_1_comb is
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
    mul_tmp_a                       : out array_2d(SIMD-1 downto 0)(Data_Width-1 downto 0);
    mul_tmp_b                       : out array_2d(SIMD-1 downto 0)(Data_Width-1 downto 0);
    mul_tmp_c                       : out array_2d(SIMD-1 downto 0)(Data_Width-1 downto 0);
    mul_tmp_d                       : out array_2d(SIMD-1 downto 0)(Data_Width-1 downto 0)
  );
end entity DSP_Multipliers_stg_1_comb;

architecture DSP_Multipliers_stg_1_comb_arch of DSP_Multipliers_stg_1_comb is
begin
  fsm_MUL_STAGE_1_COMB : process(all)
  begin
    mul_tmp_a <= (others => (others => '0'));
    mul_tmp_b <= (others => (others => '0'));
    mul_tmp_c <= (others => (others => '0'));
    mul_tmp_d <= (others => (others => '0'));
    -- KDOTP and KSVMUL instructions are handeled here
    -- this part right here shifts the intermidiate resutls appropriately, and then accumulates them in order to get the final mul result
    if mul_en = '1' and (mul_stage_2_en = '1' or recover_state_wires = '1') then
      for i in 0 to SIMD-1 loop
        if MVTYPE_DSP /= "10" then
          ------------------------------------------------------------------------------------
          mul_tmp_a(i) <= (dsp_mul_a(15+16*(2*i)  downto 16*(2*i)) & x"0000");
          mul_tmp_d(i) <= (x"0000" & dsp_mul_d(15+16*(2*i)  downto 16*(2*i)));
          ------------------------------------------------------------------------------------
        elsif MVTYPE_DSP = "10" then
          -- mul_tmp_a(i) <= (dsp_mul_a(31+32*(2*i)  downto 31*(2*i)) & x"0000");     -- The upper 32-bit results of the multiplication are discarded   (Ah*Bh)
          mul_tmp_b(i) <= (dsp_mul_b(15+16*(2*i) downto 16*(2*i)) & x"0000");         -- Modified to only add the partial result to the lower 32-bits   (Ah*Bl)
          mul_tmp_c(i) <= (dsp_mul_c(15+16*(2*i) downto 16*(2*i)) & x"0000");         -- Modified to only add the partial result to the lower 32-bits   (Al*Bh)
          mul_tmp_d(i) <= (dsp_mul_d(31+32*(i)   downto 32*(i)));                     -- This is the lower 32-bit result of the partial mmultiplication (Al*Bl)
        end if;
      end loop;
    end if;
  end process;
end architecture DSP_Multipliers_stg_1_comb_arch;
