-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Exec_Unit_stage_exec is
    generic (
        Addr_Width            : natural;
        --------------------------------
        SIMD_Width            : natural
    );
    port(
        --INPUTS
        clk_i, rst_ni, enable_i         : in std_logic;
        -- input from DSP_Excpt_Cntrl_Unit_comb
        recover_state_wires             : in std_logic;
        halt_dsp                        : in std_logic;
        wb_ready                        : in std_logic;
        -- input from fsm_DSP_pipeline_controller
        halt_dsp_lat                    : in std_logic;
        SIMD_RD_BYTES                   : in integer;
        -- input from MAPPING_OUT_UNIT_comb
        dsp_sc_data_write_wire_int      : in std_logic_vector(SIMD_Width-1 downto 0);
        SIMD_RD_BYTES_wire              : in integer;
        dsp_data_gnt_i_lat              : in std_logic;
         -- Scratchpad Interface Signals
        dsp_data_gnt_i             : in  std_logic;
        
        -- OUTPUTS
        recover_state                   : out std_logic;
        dsp_sc_data_write_int           : out std_logic_vector(SIMD_Width-1 downto 0);
        dsp_sc_data_read_mask           : out std_logic_vector(SIMD_Width-1 downto 0);

        --Common signals with stage init
        RD_Data_IE_lat_i                : in std_logic_vector(Addr_Width -1 downto 0);  -- from DSP_Exec_Unit_stage_init
        RD_Data_IE_lat_o                : out std_logic_vector(Addr_Width -1 downto 0);
        MVSIZE_WRITE_i                  : in std_logic_vector(Addr_Width downto 0);  -- Bytes remaining to write
        MVSIZE_WRITE_o                  : out std_logic_vector(Addr_Width downto 0);  -- Bytes remaining to write
        MVSIZE_READ_i                   : in std_logic_vector(Addr_Width downto 0);  -- Bytes remaining to read
        MVSIZE_READ_o                   : out std_logic_vector(Addr_Width downto 0);   -- Bytes remaining to read
        RS1_Data_IE_lat_i               : in std_logic_vector(31 downto 0);
        RS1_Data_IE_lat_o               : out std_logic_vector(31 downto 0);
        RS2_Data_IE_lat_i               : in std_logic_vector(31 downto 0);
        RS2_Data_IE_lat_o               : out std_logic_vector(31 downto 0);
        MVSIZE_READ_MASK_i              : in std_logic_vector(Addr_Width downto 0);  -- Bytes remaining to read
        vec_write_rd_DSP                : in std_logic;  -- Indicates whether the result being written is a vector or a scalar
        vec_read_rs1_DSP                : in std_logic;  -- Indicates whether the operand being read is a vector or a scalar
        vec_read_rs2_DSP                : in std_logic  -- Indicates whether the operand being read is a vector or a scalar
        );
end entity DSP_Exec_Unit_stage_exec;

architecture DSP_Exec_Unit_stage_exec_arch of DSP_Exec_Unit_stage_exec is
    signal MVSIZE_READ_MASK_s           : std_logic_vector(Addr_Width downto 0);  -- Bytes remaining to read

    begin
        exec_stage: process(clk_i, rst_ni)
        begin
            if rst_ni = '0' then
                recover_state <= '0';  --out
            elsif rising_edge(clk_i) and enable_i = '1' then
                recover_state <= recover_state_wires;
                if halt_dsp = '1' and halt_dsp_lat = '0' then
                    dsp_sc_data_write_int <= dsp_sc_data_write_wire_int;
                end if;

                --------------------------------------------------------------------------
                --  ██╗  ██╗██╗    ██╗      ██╗      ██████╗  ██████╗ ██████╗ ███████╗  --
                --  ██║  ██║██║    ██║      ██║     ██╔═══██╗██╔═══██╗██╔══██╗██╔════╝  --
                --  ███████║██║ █╗ ██║█████╗██║     ██║   ██║██║   ██║██████╔╝███████╗  --
                --  ██╔══██║██║███╗██║╚════╝██║     ██║   ██║██║   ██║██╔═══╝ ╚════██║  --
                --  ██║  ██║╚███╔███╔╝      ███████╗╚██████╔╝╚██████╔╝██║     ███████║  --
                --  ╚═╝  ╚═╝ ╚══╝╚══╝       ╚══════╝ ╚═════╝  ╚═════╝ ╚═╝     ╚══════╝  --            
                --------------------------------------------------------------------------

                if halt_dsp = '0' then
                    -- Increment the write address when we have a result as a vector
                    if vec_write_rd_DSP = '1' and wb_ready = '1' then
                        RD_Data_IE_lat_o  <= std_logic_vector(unsigned(RD_Data_IE_lat_o)  + SIMD_RD_BYTES_wire); -- destination address increment
                    end if;
                    if wb_ready = '1' then
                        if to_integer(unsigned(MVSIZE_WRITE_o)) >= SIMD_RD_BYTES_wire then
                            MVSIZE_WRITE_o <= std_logic_vector(unsigned(MVSIZE_WRITE_o) - SIMD_RD_BYTES_wire);       -- decrement by SIMD_BYTE Execution Capability 
                        else
                            MVSIZE_WRITE_o <= (others => '0');                                                -- decrement the remaining bytes
                        end if;
                    end if;
                    -- Increment the read addresses
                    if to_integer(unsigned(MVSIZE_READ_o)) >= SIMD_RD_BYTES and dsp_data_gnt_i = '1' then -- Increment the addresses untill all the vector elements are operated fetched
                        if vec_read_rs1_DSP = '1' then
                            RS1_Data_IE_lat_o <= std_logic_vector(unsigned(RS1_Data_IE_lat_o) + SIMD_RD_BYTES_wire);   -- source 1 address increment
                        end if;
                        if vec_read_rs2_DSP = '1' then
                            RS2_Data_IE_lat_o <= std_logic_vector(unsigned(RS2_Data_IE_lat_o) + SIMD_RD_BYTES_wire); -- source 2 address increment
                        end if;
                    end if;
                    -- Decrement the vector elements that have already been operated on
                    if dsp_data_gnt_i = '1' then
                        if to_integer(unsigned(MVSIZE_READ_o)) >= SIMD_RD_BYTES then
                            MVSIZE_READ_o <= std_logic_vector(unsigned(MVSIZE_READ_o) - SIMD_RD_BYTES_wire); -- decrement by SIMD_BYTE Execution Capability
                        else
                            MVSIZE_READ_o <= (others => '0');                                               -- decrement the remaining bytes
                        end if;
                    end if;
                    dsp_sc_data_read_mask <= (others => '0');
                    if dsp_data_gnt_i_lat = '1' then
                        if to_integer(unsigned(MVSIZE_READ_MASK_s)) >= SIMD_RD_BYTES then
                            dsp_sc_data_read_mask <= (others => '1');
                            MVSIZE_READ_MASK_s <= std_logic_vector(unsigned(MVSIZE_READ_MASK_s) - SIMD_RD_BYTES_wire); -- decrement by SIMD_BYTE Execution Capability 
                        else
                            MVSIZE_READ_MASK_s <= (others => '0');
                            dsp_sc_data_read_mask(to_integer(unsigned(MVSIZE_READ_MASK_s))*8 - 1 downto 0) <= (others => '1');
                        end if;
                    end if;
                end if;
            end if;
        end process exec_stage;

        Update_RD_Data_IE_lat: process(RD_Data_IE_lat_i)
        begin
            RD_Data_IE_lat_o <= RD_Data_IE_lat_i;
        end process Update_RD_Data_IE_lat;

        Update_MVSIZE_WRITE: process(MVSIZE_WRITE_i)
        begin
            MVSIZE_WRITE_o <= MVSIZE_WRITE_i;
        end process Update_MVSIZE_WRITE;

        Update_MVSIZE_READ: process(MVSIZE_READ_i)
        begin
            MVSIZE_READ_o <= MVSIZE_READ_i;
        end process Update_MVSIZE_READ;

        Update_RS1_Data_IE_lat: process(RS1_Data_IE_lat_i)
        begin
            RS1_Data_IE_lat_o <= RS1_Data_IE_lat_i;
        end process Update_RS1_Data_IE_lat;

        Update_RS2_Data_IE_lat: process(RS2_Data_IE_lat_i)
        begin
            RS2_Data_IE_lat_o <= RS2_Data_IE_lat_i;
        end process Update_RS2_Data_IE_lat;

        Update_MVSIZE_READ_MASK: process(MVSIZE_READ_MASK_i)
        begin
            MVSIZE_READ_MASK_s <= MVSIZE_READ_MASK_i;
        end process Update_MVSIZE_READ_MASK;

end DSP_Exec_Unit_stage_exec_arch;