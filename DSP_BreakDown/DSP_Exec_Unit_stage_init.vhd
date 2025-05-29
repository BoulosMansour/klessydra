-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Exec_Unit_stage_init is
    generic (
        THREAD_POOL_SIZE      : integer;
        Addr_Width            : natural;
        --------------------------------
        SPM_ADDR_WID          : natural
    );
    port(
        clk_i                           : in  std_logic;
        rst_ni                          : in  std_logic;
        enable_i                        : in  std_logic; -- enable the init stage of the DSP Exec unit
        decoded_instruction_DSP         : in  std_logic_vector(DSP_UNIT_INSTR_SET_SIZE-1 downto 0);
        -- Processing Pipeline Signals
        rs1_to_sc                       : in  std_logic_vector(SPM_ADDR_WID-1 downto 0);
        rs2_to_sc                       : in  std_logic_vector(SPM_ADDR_WID-1 downto 0);
        rd_to_sc                        : in  std_logic_vector(SPM_ADDR_WID-1 downto 0);
        --CSR Signals
        MVSIZE                          : in  array_2d(THREAD_POOL_SIZE-1 downto 0)(Addr_Width downto 0);
        MVTYPE                          : in  array_2d(THREAD_POOL_SIZE-1 downto 0)(3 downto 0);
        MPSCLFAC                        : in  array_2d(THREAD_POOL_SIZE-1 downto 0)(4 downto 0);
        -- ID_Stage Signals
        harc_EXEC                       : in  integer range THREAD_POOL_SIZE-1 downto 0;
        vec_read_rs1_ID                 : in  std_logic;
        vec_read_rs2_ID                 : in  std_logic;
        vec_write_rd_ID                 : in  std_logic;
        RD_Data_IE                      : in  std_logic_vector(Addr_Width -1 downto 0);
        RS1_Data_IE                     : in  std_logic_vector(31 downto 0);
        RS2_Data_IE                     : in  std_logic_vector(31 downto 0);
        -- Scratchpad Interface Signals
        dsp_data_gnt_i             : in  std_logic;

        -- input form MAPPING_OUT_UNIT_comb
        SIMD_RD_BYTES_wire              : in integer;

        FUNCT_SELECT_MASK               : out std_logic_vector(31 downto 0); -- when the mask is set to "FFFFFFFF" we enable KDOTP32 execution using the 16-bit muls
        twos_complement                 : out std_logic_vector(31 downto 0);
        relu_instr                      : out std_logic;
        rf_rs2                          : out std_logic;
        dotpps                          : out std_logic;  -- indicator used in the pipeline handler to switch functional units
        dotp                            : out std_logic;  -- indicator used in the pipeline handler to switch functional units
        slt                             : out std_logic;  -- indicator used in the pipeline handler to switch functional units
        carry_pass                      : out std_logic_vector(2 downto 0);  -- carry enable signal, depending on it's configuration, we can do KADDV8, KADDV16, KADDV32
        
        MPSCLFAC_DSP                    : out std_logic_vector(4 downto 0);
        MVTYPE_DSP                      : out std_logic_vector(1 downto 0);
        decoded_instruction_DSP_lat     : out std_logic_vector(DSP_UNIT_INSTR_SET_SIZE -1 downto 0);
        dsp_rs1_to_sc                   : out std_logic_vector(SPM_ADDR_WID-1 downto 0);
        dsp_rs2_to_sc                   : out std_logic_vector(SPM_ADDR_WID-1 downto 0);
        dsp_rd_to_sc                    : out std_logic_vector(SPM_ADDR_WID-1 downto 0);
        
        -- common signals with stage exec
        vec_write_rd_DSP                : out std_logic;  -- Indicates whether the result being written is a vector or a scalar
        vec_read_rs1_DSP                : out std_logic;  -- Indicates whether the operand being read is a vector or a scalar
        vec_read_rs2_DSP                : out std_logic;  -- Indicates whether the operand being read is a vector or a scalar
        MVSIZE_READ_MASK                : out std_logic_vector(Addr_Width downto 0);  -- Bytes remaining to read
        MVSIZE_WRITE                    : out std_logic_vector(Addr_Width downto 0);  -- Bytes remaining to write
        RD_Data_IE_lat                  : out std_logic_vector(Addr_Width -1 downto 0);
        RS1_Data_IE_lat                 : out std_logic_vector(31 downto 0);
        RS2_Data_IE_lat                 : out std_logic_vector(31 downto 0);
        MVSIZE_READ                     : out std_logic_vector(Addr_Width downto 0)  -- Bytes remaining to read
        );
end entity DSP_Exec_Unit_stage_init;

architecture DSP_Exec_Unit_stage_init_arch of DSP_Exec_Unit_stage_init is
    begin
        init_stage: process(clk_i, rst_ni)
        begin
            if rst_ni = '0' then
                relu_instr <= '0';     --out
                rf_rs2     <= '0';     --out
                dotpps     <= '0';     --out
                dotp       <= '0';     --out
                slt        <= '0';     --out
            elsif rising_edge(clk_i) and enable_i = '1' then
                -------------------------------------------------------------
                --  ██╗███╗   ██╗██╗████████╗    ██████╗ ███████╗██████╗   --
                --  ██║████╗  ██║██║╚══██╔══╝    ██╔══██╗██╔════╝██╔══██╗  --
                --  ██║██╔██╗ ██║██║   ██║       ██║  ██║███████╗██████╔╝  --
                --  ██║██║╚██╗██║██║   ██║       ██║  ██║╚════██║██╔═══╝   --
                --  ██║██║ ╚████║██║   ██║       ██████╔╝███████║██║       --
                --  ╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝       ╚═════╝ ╚══════╝╚═╝       -- 
                -------------------------------------------------------------

                FUNCT_SELECT_MASK <= (others => '0');  --out
                twos_complement   <= (others => '0');  --out
                relu_instr <= '0'; --out
                rf_rs2     <= '0'; --out
                dotpps     <= '0'; --out
                dotp       <= '0'; --out
                slt        <= '0'; --out
                -- Set signals to enable correct virtual parallelism operation
                if (decoded_instruction_DSP(KADDV_bit_position)    = '1'  or 
                    decoded_instruction_DSP(KSVADDSC_bit_position) = '1') and
                    MVTYPE(harc_EXEC)(3 downto 2) = "10" then
                carry_pass <= "111";  -- pass all carry_outs
                elsif decoded_instruction_DSP(KSVADDRF_bit_position) = '1' and 
                    MVTYPE(harc_EXEC)(3 downto 2) = "10" then
                carry_pass <= "111";  -- pass all carry_outs
                rf_rs2 <= '1';
                elsif (decoded_instruction_DSP(KADDV_bit_position)    = '1'  or
                    decoded_instruction_DSP(KSVADDSC_bit_position) = '1') and
                    MVTYPE(harc_EXEC)(3 downto 2) = "01" then
                carry_pass <= "101";  -- pass carrries 9, and 25
                elsif decoded_instruction_DSP(KSVADDRF_bit_position) = '1' and
                    MVTYPE(harc_EXEC)(3 downto 2) = "01" then
                carry_pass <= "101";  -- pass carrries 9, and 25
                rf_rs2 <= '1';
                elsif (decoded_instruction_DSP(KADDV_bit_position)     = '1'  or
                    decoded_instruction_DSP(KSVADDSC_bit_position)  = '1') and
                    MVTYPE(harc_EXEC)(3 downto 2) = "00" then
                carry_pass <= "000";  -- don't pass carry_outs and keep addition 8-bit
                elsif decoded_instruction_DSP(KSVADDRF_bit_position)  = '1' and 
                    MVTYPE(harc_EXEC)(3 downto 2) = "00" then
                carry_pass <= "000";  -- don't pass carry_outs and keep addition 8-bit
                rf_rs2 <= '1';
                elsif (decoded_instruction_DSP(KSUBV_bit_position)  = '1') and
                    MVTYPE(harc_EXEC)(3 downto 2) = "10" then
                carry_pass <= "111";  -- pass all carry_outs
                twos_complement <= "00010001000100010001000100010001";
                elsif (decoded_instruction_DSP(KSUBV_bit_position)  = '1') and
                    MVTYPE(harc_EXEC)(3 downto 2) = "01" then
                carry_pass <= "101";  -- pass carrries 9, and 25
                twos_complement <= "01010101010101010101010101010101";
                elsif (decoded_instruction_DSP(KSUBV_bit_position)  = '1') and
                    MVTYPE(harc_EXEC)(3 downto 2) = "00" then
                carry_pass <= "000";  -- don't pass carry_outs and keep addition 8-bit
                twos_complement <= "11111111111111111111111111111111";
                elsif (decoded_instruction_DSP(KVSLT_bit_position)  = '1'  or
                    decoded_instruction_DSP(KSVSLT_bit_position) = '1') and
                    MVTYPE(harc_EXEC)(3 downto 2) = "10" then
                carry_pass <= "111";  -- pass all carry_outs
                twos_complement <= "00010001000100010001000100010001";
                slt <= '1';
                elsif (decoded_instruction_DSP(KVSLT_bit_position)  = '1'  or
                    decoded_instruction_DSP(KSVSLT_bit_position) = '1') and
                    MVTYPE(harc_EXEC)(3 downto 2) = "01" then
                carry_pass <= "101";  -- pass carrries 9, and 25
                twos_complement <= "01010101010101010101010101010101";
                slt <= '1';
                elsif (decoded_instruction_DSP(KVSLT_bit_position)  = '1'  or
                    decoded_instruction_DSP(KSVSLT_bit_position) = '1') and
                    MVTYPE(harc_EXEC)(3 downto 2) = "00" then
                carry_pass <= "000";  -- don't pass carry_outs and keep addition 8-bit
                twos_complement <= "11111111111111111111111111111111";
                slt <= '1';
                elsif decoded_instruction_DSP(KDOTP_bit_position) = '1' and
                    MVTYPE(harc_EXEC)(3 downto 2) = "10" then
                -- KDOTP32 does not use the adders of KADDV instructions but rather adds the mul_acc results using it's own adders
                FUNCT_SELECT_MASK <= (others => '1');  -- This enables 32-bit multiplication with the 16-bit multipliers
                dotp <= '1';
                elsif decoded_instruction_DSP(KDOTP_bit_position) = '1' and 
                    MVTYPE(harc_EXEC)(3 downto 2) = "01" then
                dotp <= '1';
                elsif decoded_instruction_DSP(KDOTP_bit_position) = '1' and
                    MVTYPE(harc_EXEC)(3 downto 2) = "00" then
                dotp <= '1';
                elsif decoded_instruction_DSP(KDOTPPS_bit_position) = '1' and
                    MVTYPE(harc_EXEC)(3 downto 2) = "10" then
                FUNCT_SELECT_MASK <= (others => '1');  -- This enables 32-bit multiplication with the 16-bit multipliers
                dotpps <= '1';
                elsif decoded_instruction_DSP(KDOTPPS_bit_position) = '1' and
                    MVTYPE(harc_EXEC)(3 downto 2) = "01" then
                dotpps <= '1';
                elsif decoded_instruction_DSP(KDOTPPS_bit_position)  = '1' and 
                    MVTYPE(harc_EXEC)(3 downto 2) = "00" then
                dotpps <= '1';
                elsif decoded_instruction_DSP(KSVMULRF_bit_position) = '1' and
                    MVTYPE(harc_EXEC)(3 downto 2) = "10" then
                FUNCT_SELECT_MASK <= (others => '1');
                rf_rs2 <= '1';
                elsif decoded_instruction_DSP(KSVMULRF_bit_position) = '1' and
                    MVTYPE(harc_EXEC)(3 downto 2) = "01" then
                rf_rs2 <= '1';
                elsif decoded_instruction_DSP(KSVMULRF_bit_position)  = '1' and
                    MVTYPE(harc_EXEC)(3 downto 2) = "00" then
                rf_rs2  <= '1';
                elsif (decoded_instruction_DSP(KVMUL_bit_position)    = '1'  or
                    decoded_instruction_DSP(KSVMULSC_bit_position) = '1') and
                    MVTYPE(harc_EXEC)(3 downto 2) = "10" then
                FUNCT_SELECT_MASK <= (others => '1');
                elsif decoded_instruction_DSP(KRELU_bit_position) = '1' then
                relu_instr <= '1';
                end if;

                -- We backup data from decode stage since they will get updated

                MVSIZE_READ_MASK <= MVSIZE(harc_EXEC);
                MVSIZE_WRITE <= MVSIZE(harc_EXEC);
                MPSCLFAC_DSP <= MPSCLFAC(harc_EXEC);
                MVTYPE_DSP <= MVTYPE(harc_EXEC)(3 downto 2);
                decoded_instruction_DSP_lat  <= decoded_instruction_DSP;
                vec_write_rd_DSP <= vec_write_rd_ID;
                vec_read_rs1_DSP <= vec_read_rs1_ID;
                vec_read_rs2_DSP <= vec_read_rs2_ID;
                dsp_rs1_to_sc <= rs1_to_sc;
                dsp_rs2_to_sc <= rs2_to_sc;
                dsp_rd_to_sc  <= rd_to_sc;
                RD_Data_IE_lat <= RD_Data_IE;
                -- Increment the read addresses
                if dsp_data_gnt_i = '1' then
                if vec_read_rs1_ID = '1' then
                    RS1_Data_IE_lat <= std_logic_vector(unsigned(RS1_Data_IE) + SIMD_RD_BYTES_wire);   -- source 1 address increment
                else
                    RS1_Data_IE_lat <= RS1_Data_IE;
                end if;
                if vec_read_rs2_ID = '1' then
                    RS2_Data_IE_lat <= std_logic_vector(unsigned(RS2_Data_IE) + SIMD_RD_BYTES_wire); -- source 2 address increment
                else
                    RS2_Data_IE_lat <= RS2_Data_IE;
                end if;
                -- Decrement the vector elements that have already been operated on
                if unsigned(MVSIZE) >= SIMD_RD_BYTES_wire then
                    MVSIZE_READ <= std_logic_vector(unsigned(MVSIZE) - SIMD_RD_BYTES_wire);  -- decrement by SIMD_BYTE Execution Capability
                else
                    MVSIZE_READ <= (others => '0');                                                     -- decrement the remaining bytes
                end if;
                else
                RS1_Data_IE_lat <= RS1_Data_IE;
                RS2_Data_IE_lat <= RS2_Data_IE;
                MVSIZE_READ <= MVSIZE(harc_EXEC);
                end if;
                -------------------------------------------------------------------------------
            end if;
        end process init_stage;
end DSP_Exec_Unit_stage_init_arch;