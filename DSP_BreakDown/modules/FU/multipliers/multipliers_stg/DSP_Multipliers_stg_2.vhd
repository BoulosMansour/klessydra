-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Multipliers_stg_2 is
  generic(
    SIMD                  : natural;
    --------------------------------
    Data_Width            : natural;
    SIMD_Width            : natural
  );
  port(
    -- Core Signals
    clk_i, rst_ni                   : in std_logic;
    -- inputs from DSP_Excpt_Unit
    recover_state_wires             : in std_logic;
    -- inputs from DSP_pipeline_controller
    mul_stage_2_en                  : in std_logic;
    halt_dsp_lat                    : in std_logic;
    -- inputs from DSP_FU_Handler
    mul_en                          : in std_logic;  -- enables the use of the multipliers
    -- inputs from multipliers
    mul_tmp_a                       : in array_2d_mul_tmp(SIMD-1 downto 0);
    mul_tmp_b                       : in array_2d_mul_tmp(SIMD-1 downto 0);
    mul_tmp_c                       : in array_2d_mul_tmp(SIMD-1 downto 0);
    mul_tmp_d                       : in array_2d_mul_tmp(SIMD-1 downto 0);

    --outputs for DSP_Mapping
    dsp_out_mul_results             : out std_logic_vector(SIMD_Width-1 downto 0)
  );
end entity DSP_Multipliers_stg_2;

architecture DSP_Multipliers_stg_2_arch of DSP_Multipliers_stg_2 is
begin
  ------------------------------------------------------------------------------------------------------------------------------------
  --  ███╗   ███╗██╗   ██╗██╗  ████████╗██╗██████╗ ██╗     ██╗███████╗██████╗ ███████╗    ███████╗████████╗ ██████╗       ██████╗   --
  --  ████╗ ████║██║   ██║██║  ╚══██╔══╝██║██╔══██╗██║     ██║██╔════╝██╔══██╗██╔════╝    ██╔════╝╚══██╔══╝██╔════╝       ╚════██╗  --
  --  ██╔████╔██║██║   ██║██║     ██║   ██║██████╔╝██║     ██║█████╗  ██████╔╝███████╗    ███████╗   ██║   ██║  ███╗█████╗ █████╔╝  --
  --  ██║╚██╔╝██║██║   ██║██║     ██║   ██║██╔═══╝ ██║     ██║██╔══╝  ██╔══██╗╚════██║    ╚════██║   ██║   ██║   ██║╚════╝██╔═══╝   --
  --  ██║ ╚═╝ ██║╚██████╔╝███████╗██║   ██║██║     ███████╗██║███████╗██║  ██║███████║    ███████║   ██║   ╚██████╔╝      ███████╗  --
  --  ╚═╝     ╚═╝ ╚═════╝ ╚══════╝╚═╝   ╚═╝╚═╝     ╚══════╝╚═╝╚══════╝╚═╝  ╚═╝╚══════╝    ╚══════╝   ╚═╝    ╚═════╝       ╚══════╝  --
  ------------------------------------------------------------------------------------------------------------------------------------

  -- STAGE 2 --
  fsm_MUL_STAGE_2 : process(clk_i, rst_ni)
  begin
  if rst_ni = '0' then
    elsif rising_edge(clk_i) then
      -- Accumulate the partial multiplications to make up bigger multiplications
      if mul_en = '1' and (mul_stage_2_en = '1' or recover_state_wires = '1') and halt_dsp_lat = '0' then
        for i in 0 to SIMD-1 loop
          dsp_out_mul_results((Data_Width-1)+Data_Width*(i) downto Data_Width*(i))  <= (std_logic_vector(unsigned(mul_tmp_a(i)) + unsigned(mul_tmp_b(i)) + unsigned(mul_tmp_c(i)) + unsigned(mul_tmp_d(i))));
        end loop;
      end if;
    end if;
  end process;
end architecture DSP_Multipliers_stg_2_arch;