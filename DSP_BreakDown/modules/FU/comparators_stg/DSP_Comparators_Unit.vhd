-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Comparators_Unit is
  generic(
    SIMD                  : natural;
    --------------------------------
    SIMD_Width            : natural
  );
  port(
    -- Core Signals
    clk_i, rst_ni                   : in std_logic;
    -- inputs from DSP_Exec_Unit
    MVTYPE_DSP                      : in std_logic_vector(1 downto 0);
    relu_instr                      : in std_logic;
    -- inputs from DSP_pipeline_controller
    halt_dsp_lat                    : in std_logic;
    cmp_stage_1_en                  : in std_logic;
    -- inputs from DSP_Excpt_Unit
    recover_state_wires             : in std_logic;
    -- inputs from DSP_FU_Handler
    cmp_en                          : in std_logic;  -- enables the use of the shifters
    -- inputs from DSP_Mapping
    dsp_in_cmp_operands             : in std_logic_vector(SIMD_Width-1 downto 0);
    -- inputs from adders
    MSB_stage_2                     : in array_2d_MSB_stage(1 downto 0);
  
    -- outputs for DSP_Mapping
    dsp_out_cmp_results             : out std_logic_vector(SIMD_Width-1 downto 0)
  );
end entity DSP_Comparators_Unit;

architecture DSP_Comparators_Unit_arch of DSP_Comparators_Unit is
begin
  ----------------------------------------------------------------------------------------------------
  -- ██████╗ ██████╗ ███╗   ███╗██████╗  █████╗ ██████╗  █████╗ ████████╗ ██████╗ ██████╗ ███████╗  --
  --██╔════╝██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔═══██╗██╔══██╗██╔════╝  --
  --██║     ██║   ██║██╔████╔██║██████╔╝███████║██████╔╝███████║   ██║   ██║   ██║██████╔╝███████╗  --
  --██║     ██║   ██║██║╚██╔╝██║██╔═══╝ ██╔══██║██╔══██╗██╔══██║   ██║   ██║   ██║██╔══██╗╚════██║  --
  --╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     ██║  ██║██║  ██║██║  ██║   ██║   ╚██████╔╝██║  ██║███████║  --
  -- ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝  --
  ----------------------------------------------------------------------------------------------------

  fsm_RELU : process(clk_i, rst_ni)
  variable MSB_stage_3                     : array_2d_MSB_stage(1 downto 0);
  begin
    if rst_ni = '0' then
    elsif rising_edge(clk_i) then
      if cmp_en = '1' and halt_dsp_lat = '0' then
        MSB_stage_3  := MSB_stage_2;
        if cmp_stage_1_en = '1' or recover_state_wires = '1' then
          if MVTYPE_DSP = "10" then
            for i in 0 to SIMD-1 loop
              if relu_instr = '1' then
                if dsp_in_cmp_operands(31+32*(i)) = '1' then
                  dsp_out_cmp_results(31+32*(i) downto 32*(i)) <= (others => '0');
                else
                  dsp_out_cmp_results(31+32*(i) downto 32*(i)) <= dsp_in_cmp_operands(31+32*(i) downto 32*(i));
                end if;
              else
                if MSB_stage_3(1)(4*(i)+3) = MSB_stage_3(0)(4*(i)+3) then -- if both signs are equal, than read the MSB from the subtractor
                  if dsp_in_cmp_operands(31+32*(i)) = '1' then
                    dsp_out_cmp_results(31+32*(i) downto 32*(i)) <= (31+32*(i) downto 32*(i)+1 => '0') & '1';
                  else
                    dsp_out_cmp_results(31+32*(i) downto 32*(i)) <= (others => '0');
                  end if;
                elsif MSB_stage_3(1)(4*(i)+3) /= MSB_stage_3(0)(4*(i)+3) and MSB_stage_3(0)(4*(i)+3) = '1' then
                  dsp_out_cmp_results(31+32*(i) downto 32*(i)) <= (31+32*(i) downto 32*(i)+1 => '0') & '1';
                else
                  dsp_out_cmp_results(31+32*(i) downto 32*(i)) <= (others => '0');
                end if;
              end if;
            end loop;
          elsif MVTYPE_DSP = "01" then
            for i in 0 to 2*SIMD-1 loop
              if relu_instr = '1' then
                if dsp_in_cmp_operands(15+16*(i)) = '1' then
                    dsp_out_cmp_results(15+16*(i) downto 16*(i)) <= (others => '0');
                else
                    dsp_out_cmp_results(15+16*(i) downto 16*(i)) <= dsp_in_cmp_operands(15+16*(i) downto 16*(i));
                end if;
              else
                if MSB_stage_3(1)(2*(i)+1) = MSB_stage_3(0)(2*(i)+1) then -- if both signs are equal, than read the MSB from the subtractor
                  if dsp_in_cmp_operands(15+16*(i)) = '1' then
                    dsp_out_cmp_results(15+16*(i) downto 16*(i)) <= (15+16*(i) downto 16*(i)+1 => '0') & '1';
                  else
                    dsp_out_cmp_results(15+16*(i) downto 16*(i)) <= (others => '0');
                  end if;
                elsif MSB_stage_3(1)(2*(i)+1) /= MSB_stage_3(0)(2*(i)+1) and MSB_stage_3(0)(2*(i)+1) = '1' then
                  dsp_out_cmp_results(15+16*(i) downto 16*(i)) <= (15+16*(i) downto 16*(i)+1 => '0') & '1';
                else
                  dsp_out_cmp_results(15+16*(i) downto 16*(i)) <= (others => '0');
                end if;
              end if;
            end loop;
          elsif MVTYPE_DSP = "00" then
            for i in 0 to 4*SIMD-1 loop
              if relu_instr = '1' then
                if dsp_in_cmp_operands(7+8*(i)) = '1' then
                    dsp_out_cmp_results(7+8*(i) downto 8*(i)) <= (others => '0');
                else
                  dsp_out_cmp_results(7+8*(i) downto 8*(i)) <= dsp_in_cmp_operands(7+8*(i) downto 8*(i));
                end if;
              else
                if MSB_stage_3(1)(i) = MSB_stage_3(0)(i) then -- if both signs are equal, than read the MSB from the subtractor
                  if dsp_in_cmp_operands(7+8*(i)) = '1' then
                    dsp_out_cmp_results(7+8*(i) downto 8*(i)) <= (7+8*(i) downto 8*(i)+1 => '0') & '1';
                  else
                    dsp_out_cmp_results(7+8*(i) downto 8*(i)) <= (others => '0');
                  end if;
                elsif MSB_stage_3(1)(i) /= MSB_stage_3(0)(i) and MSB_stage_3(0)(i) = '1' then
                  dsp_out_cmp_results(7+8*(i) downto 8*(i)) <= (7+8*(i) downto 8*(i)+1 => '0') & '1';
                else
                  dsp_out_cmp_results(7+8*(i) downto 8*(i)) <= (others => '0');
                end if;
              end if;
            end loop;  -- SIMD LOOP
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture DSP_Comparators_Unit_arch;