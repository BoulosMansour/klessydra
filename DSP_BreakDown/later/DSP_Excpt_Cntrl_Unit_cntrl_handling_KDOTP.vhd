-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Excpt_Cntrl_Unit_cntrl_handling_KDOTP is
    generic(
        Addr_Width            : natural;
        SPM_NUM               : natural;
        -----------------------------------
        SPM_ADDR_WID          : natural
    );
    port(
        --INPUTS
        enable_i                        : in std_logic;
        -- input from DSP_Exec_Unit
        vec_read_rs2_DSP                : in std_logic;  -- Indicates whether the operand being read is a vector or a scalar
        recover_state                   : in std_logic;
        dsp_rs1_to_sc                   : in std_logic_vector(SPM_ADDR_WID-1 downto 0);
        dsp_rs2_to_sc                   : in std_logic_vector(SPM_ADDR_WID-1 downto 0);
        dsp_rd_to_sc                    : in std_logic_vector(SPM_ADDR_WID-1 downto 0);
        RS1_Data_IE_lat                 : in std_logic_vector(31 downto 0);
        RS2_Data_IE_lat                 : in std_logic_vector(31 downto 0);
        RD_Data_IE_lat                  : in std_logic_vector(Addr_Width -1 downto 0);
        MVSIZE_WRITE                    : in std_logic_vector(Addr_Width downto 0);  -- Bytes remaining to write
        MVSIZE_READ                     : in std_logic_vector(Addr_Width downto 0);  -- Bytes remaining to read
        -- input from pipeline controller
        accum_stage_3_en                : in std_logic;
        
        --OUTPUTS
        nextstate_DSP                   : out std_logic_vector(1 downto 0);
        wb_ready                        : out std_logic;
        dsp_sc_read_addr                : out array_2d(1 downto 0)(Addr_Width-1 downto 0);
        dsp_sci_req                     : out std_logic_vector(SPM_NUM-1 downto 0);
        dsp_to_sc                       : out array_2d(SPM_NUM-1 downto 0)(1 downto 0);
        busy_dsp_internal               : out std_logic;
        dsp_sc_write_addr               : out std_logic_vector(Addr_Width-1 downto 0);
        dsp_sci_we                      : out std_logic_vector(SPM_NUM-1 downto 0)
    );
end entity DSP_Excpt_Cntrl_Unit_cntrl_handling_KDOTP;

architecture DSP_Excpt_Cntrl_Unit_cntrl_handling_KDOTP_arch of DSP_Excpt_Cntrl_Unit_cntrl_handling_KDOTP is
begin
KDOTP_signals_handling: process(all)
begin
    if enable_i = '1' then
        -- KDOTP signals are handeled here
        if accum_stage_3_en = '1' then
            wb_ready <= '1';
        elsif recover_state = '1' then
            wb_ready <= '1';  
        end if;
        if MVSIZE_READ > (0 to Addr_Width => '0') then
            if vec_read_rs2_DSP = '1' then
                dsp_sci_req(to_integer(unsigned(dsp_rs2_to_sc))) <= '1';
                dsp_to_sc(to_integer(unsigned(dsp_rs2_to_sc)))(1) <= '1';
                dsp_sc_read_addr(1)  <= RS2_Data_IE_lat(Addr_Width - 1 downto 0);
            end if;
            dsp_sci_req(to_integer(unsigned(dsp_rs1_to_sc))) <= '1';
            dsp_to_sc(to_integer(unsigned(dsp_rs1_to_sc)))(0) <= '1';
            dsp_sc_read_addr(0)  <= RS1_Data_IE_lat(Addr_Width - 1 downto 0);
            nextstate_DSP <= dsp_exec;
            busy_dsp_internal := '1';
        elsif MVSIZE_WRITE = (0 to Addr_Width => '0') then
            nextstate_DSP <= dsp_init;
        else
            nextstate_DSP <= dsp_exec;
            busy_dsp_internal := '1';
        end if;
        if wb_ready = '1' then
            dsp_sci_we(to_integer(unsigned(dsp_rd_to_sc)))    <= '1';
            dsp_sc_write_addr <= RD_Data_IE_lat;
        end if;
    end if;
end process KDOTP_signals_handling;
end architecture DSP_Excpt_Cntrl_Unit_cntrl_handling_KDOTP_arch;