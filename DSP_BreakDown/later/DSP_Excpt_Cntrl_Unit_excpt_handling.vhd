-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Excpt_Cntrl_Unit_excpt_handling is
    generic(
        THREAD_POOL_SIZE      : integer;
        Addr_Width            : natural;
        SPM_NUM               : natural;
        ---------------------------------
        SPM_ADDR_WID          : natural
    );
    port(
        -- Processing Pipeline Signals
        rs1_to_sc                  : in  std_logic_vector(SPM_ADDR_WID-1 downto 0);
        rs2_to_sc                  : in  std_logic_vector(SPM_ADDR_WID-1 downto 0);
        rd_to_sc                   : in  std_logic_vector(SPM_ADDR_WID-1 downto 0);
        -- CSR Signals
        MVSIZE                     : in  array_2d(THREAD_POOL_SIZE-1 downto 0)(Addr_Width downto 0);
        MVTYPE                     : in  array_2d(THREAD_POOL_SIZE-1 downto 0)(3 downto 0);
        -- Program Counter Signals
        dsp_except_condition       : out std_logic;
        dsp_taken_branch           : out std_logic;
        -- ID_Stage Signals
        harc_EXEC                  : in  integer range THREAD_POOL_SIZE-1 downto 0;
        RS1_Data_IE                : in  std_logic_vector(31 downto 0);
        RS2_Data_IE                : in  std_logic_vector(31 downto 0);
        RD_Data_IE                 : in  std_logic_vector(Addr_Width -1 downto 0);
        spm_rs1                    : in  std_logic;
        spm_rs2                    : in  std_logic;
        vec_read_rs1_ID            : in  std_logic;
        vec_read_rs2_ID            : in  std_logic;
        vec_write_rd_ID            : in  std_logic;
        -- input from FU access handler
        halt_hart                       : std_logic; -- halts the thread when the requested functional unit is in use

        --out
        dsp_except_data_wire       : out std_logic_vector(31 downto 0);
        -- Scratchpad Interface Signals
        dsp_sci_req                : out std_logic_vector(SPM_NUM-1 downto 0);
        dsp_sc_read_addr           : out array_2d(1 downto 0)(Addr_Width-1 downto 0);
        dsp_to_sc                  : out array_2d(SPM_NUM-1 downto 0)(1 downto 0);
        --common output signals
        nextstate_DSP              : out std_logic_vector(1 downto 0);

        --common signals
        busy_dsp_internal          : out std_logic
    );
end entity DSP_Excpt_Cntrl_Unit_excpt_handling;

architecture DSP_Excpt_Cntrl_Unit_excpt_handling_arch of DSP_Excpt_Cntrl_Unit_excpt_handling is
begin
EXCPT_HANDLING: process(all)
    variable overflow_rs1_sc                 : std_logic_vector(Addr_Width downto 0);
    variable overflow_rs2_sc                 : std_logic_vector(Addr_Width downto 0);
    variable overflow_rd_sc                  : std_logic_vector(Addr_Width downto 0);
begin
    ---------------------------------------------------------------------------------------------------------------------
    --  ███████╗██╗  ██╗ ██████╗██████╗ ████████╗    ██╗  ██╗ █████╗ ███╗   ██╗██████╗ ██╗     ██╗███╗   ██╗ ██████╗   --
    --  ██╔════╝╚██╗██╔╝██╔════╝██╔══██╗╚══██╔══╝    ██║  ██║██╔══██╗████╗  ██║██╔══██╗██║     ██║████╗  ██║██╔════╝   --
    --  █████╗   ╚███╔╝ ██║     ██████╔╝   ██║       ███████║███████║██╔██╗ ██║██║  ██║██║     ██║██╔██╗ ██║██║  ███╗  --
    --  ██╔══╝   ██╔██╗ ██║     ██╔═══╝    ██║       ██╔══██║██╔══██║██║╚██╗██║██║  ██║██║     ██║██║╚██╗██║██║   ██║  -- 
    --  ███████╗██╔╝ ██╗╚██████╗██║        ██║       ██║  ██║██║  ██║██║ ╚████║██████╔╝███████╗██║██║ ╚████║╚██████╔╝  --
    --  ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝        ╚═╝       ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝   --
    ---------------------------------------------------------------------------------------------------------------------

    overflow_rs1_sc := std_logic_vector('0' & unsigned(RS1_Data_IE(Addr_Width -1 downto 0)) + unsigned(MVSIZE(harc_EXEC)) -1);
    overflow_rs2_sc := std_logic_vector('0' & unsigned(RS2_Data_IE(Addr_Width -1 downto 0)) + unsigned(MVSIZE(harc_EXEC)) -1);
    overflow_rd_sc  := std_logic_vector('0' & unsigned(RD_Data_IE(Addr_Width  -1 downto 0)) + unsigned(MVSIZE(harc_EXEC)) -1);
    if MVSIZE(harc_EXEC) = (0 to Addr_Width => '0') then
        null;
    elsif MVSIZE(harc_EXEC)(1 downto 0) /= "00" and MVTYPE(harc_EXEC)(3 downto 2) = "10" then  -- Set exception if the number of bytes are not divisible by four
        dsp_except_condition := '1';
        dsp_taken_branch     := '1';    
        dsp_except_data_wire <= ILLEGAL_VECTOR_SIZE_EXCEPT_CODE;
    elsif MVSIZE(harc_EXEC)(0) /= '0' and MVTYPE(harc_EXEC)(3 downto 2) = "01" then            -- Set exception if the number of bytes are not divisible by two
        dsp_except_condition := '1';
        dsp_taken_branch     := '1';
        dsp_except_data_wire <= ILLEGAL_VECTOR_SIZE_EXCEPT_CODE;
    elsif (rs1_to_sc  = "100" and vec_read_rs1_ID = '1') or
        (rs2_to_sc  = "100" and vec_read_rs2_ID = '1') or
        rd_to_sc   = "100" then     -- Set exception for non scratchpad access
        dsp_except_condition := '1';
        dsp_taken_branch     := '1';    
        dsp_except_data_wire <= ILLEGAL_ADDRESS_EXCEPT_CODE;
    elsif rs1_to_sc = rs2_to_sc and vec_read_rs1_ID = '1' and vec_read_rs2_ID = '1' then               -- Set exception for same read access
        dsp_except_condition := '1';
        dsp_taken_branch     := '1';    
        dsp_except_data_wire <= READ_SAME_SCARTCHPAD_EXCEPT_CODE;    
    elsif (overflow_rs1_sc(Addr_Width) = '1' and vec_read_rs1_ID = '1') or (overflow_rs2_sc(Addr_Width) = '1' and  vec_read_rs2_ID = '1') then -- Set exception if reading overflows the scratchpad's address
        dsp_except_condition := '1';
        dsp_taken_branch     := '1';    
        dsp_except_data_wire <= SCRATCHPAD_OVERFLOW_EXCEPT_CODE;
    elsif overflow_rd_sc(Addr_Width) = '1'  and vec_write_rd_ID = '1' then           -- Set exception if reading overflows the scratchpad's address, scalar writes are excluded
        dsp_except_condition := '1';
        dsp_taken_branch     := '1';    
        dsp_except_data_wire <= SCRATCHPAD_OVERFLOW_EXCEPT_CODE;
    else
        if halt_hart = '0' then
            nextstate_DSP <= dsp_exec;
        else
            nextstate_DSP <= dsp_halt_hart;
        end if;
        busy_DSP_internal := '1';
    end if;

    if rs1_to_sc /= "100" and spm_rs1 = '1' and halt_hart = '0' then
        dsp_sci_req(to_integer(unsigned(rs1_to_sc))) <= '1';
        dsp_to_sc(to_integer(unsigned(rs1_to_sc)))(0) <= '1';
        dsp_sc_read_addr(0) <= RS1_Data_IE(Addr_Width-1 downto 0);
    end if;
    if rs2_to_sc /= "100" and spm_rs2 = '1' and rs1_to_Sc /= rs2_to_sc and halt_hart = '0' then   -- Do not send a read request if the second operand accesses the same spm as the first, 
        dsp_sci_req(to_integer(unsigned(rs2_to_sc))) <= '1';
        dsp_to_sc(to_integer(unsigned(rs2_to_sc)))(1) <= '1';
        dsp_sc_read_addr(1) <= RS2_Data_IE(Addr_Width-1 downto 0);
    end if;

end process EXCPT_HANDLING;
end architecture DSP_Excpt_Cntrl_Unit_excpt_handling_arch;
