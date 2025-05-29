-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Excpt_Cntrl_Unit_excpt_handling_KBCAST is
    generic(
        Addr_Width            : natural;
        SPM_NUM               : natural;
        -----------------------------------
        SPM_ADDR_WID          : natural
    );
    port(
        enable_i                    : in std_logic;
        dsp_rd_to_sc                : in std_logic_vector(SPM_ADDR_WID-1 downto 0);
        RD_Data_IE_lat              : in std_logic_vector(Addr_Width -1 downto 0);
        MVSIZE_WRITE                : in std_logic_vector(Addr_Width downto 0);  -- Bytes remaining to write

        --output signals
        nextstate_DSP               : out std_logic_vector(1 downto 0);
        busy_dsp_internal           : out std_logic;
        wb_ready                    : out std_logic;
        dsp_sci_we                  : out std_logic_vector(SPM_NUM-1 downto 0);
        dsp_sc_write_addr           : out std_logic_vector(Addr_Width-1 downto 0)    
    );
end entity DSP_Excpt_Cntrl_Unit_excpt_handling_KBCAST;

architecture DSP_Excpt_Cntrl_Unit_excpt_handling_KBCAST_arch of DSP_Excpt_Cntrl_Unit_excpt_handling_KBCAST is
begin
KBCAST_signals_handler: process(all)
begin
    if enable_i then
        -- KBCAST signals are handeled here
        if MVSIZE_WRITE > (0 to Addr_Width => '0') then
            nextstate_DSP <= dsp_exec;
            busy_dsp_internal <= '1';
        end if;
            wb_ready <= '1';
            dsp_sci_we(to_integer(unsigned(dsp_rd_to_sc))) <= '1';
            dsp_sc_write_addr <= RD_Data_IE_lat;
    end if;
end process KBCAST_signals_handler;
end architecture DSP_Excpt_Cntrl_Unit_excpt_handling_KBCAST_arch;