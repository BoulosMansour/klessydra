-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Exec_Unit is
    generic (
        THREAD_POOL_SIZE      : integer;
        Addr_Width            : natural;
        --------------------------------
        SPM_ADDR_WID          : natural;
        SIMD_Width            : natural
    );
    port (
        clk_i, rst_ni                   : in std_logic;
        dsp_instr_req                   : in std_logic;
        decoded_instruction_DSP         : in  std_logic_vector(DSP_UNIT_INSTR_SET_SIZE-1 downto 0);
        -- input from fsm_DSP_pipeline_controller
        busy_DSP_internal_lat           : in std_logic;
        state_DSP                       : in std_logic_vector(1 downto 0);
        halt_dsp_lat                    : in std_logic;
        SIMD_RD_BYTES                   : in integer;

        -- Processing Pipeline Signals
        rs1_to_sc                       : in  std_logic_vector(SPM_ADDR_WID-1 downto 0);
        rs2_to_sc                       : in  std_logic_vector(SPM_ADDR_WID-1 downto 0);
        rd_to_sc                        : in  std_logic_vector(SPM_ADDR_WID-1 downto 0);
        --CSR Signals
        MVSIZE                          : in  array_2d(THREAD_POOL_SIZE-1 downto 0)(Addr_Width downto 0);
        MVSIZE_h                        : in  std_logic_vector(Addr_Width downto 0);
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
        -- input from DSP_Excpt_Cntrl_Unit_comb
        recover_state_wires             : in std_logic;
        halt_dsp                        : in std_logic;
        wb_ready                        : in std_logic;
        -- Scratchpad Interface Signals
        dsp_data_gnt_i                  : in  std_logic;

        -- input form MAPPING_OUT_UNIT_comb
        SIMD_RD_BYTES_wire              : in integer;
        dsp_sc_data_write_wire_int      : in std_logic_vector(SIMD_Width-1 downto 0);
        dsp_data_gnt_i_lat              : in std_logic;

        -- OUTPUTS
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

        recover_state                   : out std_logic;
        dsp_sc_data_write_int           : out std_logic_vector(SIMD_Width-1 downto 0);
        dsp_sc_data_read_mask           : out std_logic_vector(SIMD_Width-1 downto 0);

        --Common signals with stage init
        RD_Data_IE_lat                  : out std_logic_vector(Addr_Width -1 downto 0);
        MVSIZE_WRITE                    : out std_logic_vector(Addr_Width downto 0);   -- Bytes remaining to write
        MVSIZE_READ                     : out std_logic_vector(Addr_Width downto 0);   -- Bytes remaining to read
        RS1_Data_IE_lat                 : out std_logic_vector(31 downto 0);
        RS2_Data_IE_lat                 : out std_logic_vector(31 downto 0);
        vec_read_rs1_DSP                : out std_logic;  -- Indicates whether the operand being read is a vector or a scalar
        vec_read_rs2_DSP                : out std_logic;  -- Indicates whether the operand being read is a vector or a scalar
        vec_write_rd_DSP                : out std_logic  -- Indicates whether the result being written is a vector or a scalar
    );
end entity DSP_Exec_Unit;

architecture DSP_Exec_Unit_arch of DSP_Exec_Unit is
component DSP_Exec_Unit_stage_init is
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
        MVSIZE_h                        : in  std_logic_vector(Addr_Width downto 0);
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
end component DSP_Exec_Unit_stage_init;

component DSP_Exec_Unit_stage_exec is
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
        dsp_data_gnt_i                  : in  std_logic;
        
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
end component DSP_Exec_Unit_stage_exec;

-- enable signals for subcomponents
signal enable_init_stage_s         : std_logic;
signal enable_exec_stage_s         : std_logic;

-- common signals for subcomponents
signal RD_Data_IE_lat_s         :std_logic_vector(Addr_Width -1 downto 0);  -- from DSP_Exec_Unit_stage_init
signal MVSIZE_WRITE_s                  : std_logic_vector(Addr_Width downto 0);  -- Bytes remaining to write
signal MVSIZE_READ_s                   : std_logic_vector(Addr_Width downto 0);  -- Bytes remaining to read
signal RS1_Data_IE_lat_s               : std_logic_vector(31 downto 0);
signal RS2_Data_IE_lat_s               : std_logic_vector(31 downto 0);
signal MVSIZE_READ_MASK_s              : std_logic_vector(Addr_Width downto 0);  -- Bytes remaining to read

begin
enable_exec_stage_s <= '1' when (state_DSP = dsp_init and busy_DSP_internal_lat = '1' and dsp_instr_req = '1') else '0';
enable_init_stage_s <= '1' when (state_DSP = dsp_exec and busy_DSP_internal_lat = '1' and dsp_instr_req = '1') else '0';

init_stage: DSP_Exec_Unit_stage_init 
    generic map (
        THREAD_POOL_SIZE      => THREAD_POOL_SIZE,
        Addr_Width            => Addr_Width,
        --------------------------------
        SPM_ADDR_WID          => SPM_ADDR_WID
    )
    port map(
        clk_i                           => clk_i,
        rst_ni                          => rst_ni,
        enable_i                        => enable_init_stage_s,
        decoded_instruction_DSP         => decoded_instruction_DSP,
        -- Processing Pipeline Signals
        rs1_to_sc                       => rs1_to_sc,
        rs2_to_sc                       => rs2_to_sc,
        rd_to_sc                        => rd_to_sc,
        --CSR Signals
        MVSIZE                          => MVSIZE,
        MVSIZE_h                        => MVSIZE_h,
        MVTYPE                          => MVTYPE,
        MPSCLFAC                        => MPSCLFAC,
        -- ID_Stage Signals
        harc_EXEC                       => harc_EXEC,
        vec_read_rs1_ID                 => vec_read_rs1_ID,
        vec_read_rs2_ID                 => vec_read_rs2_ID,
        vec_write_rd_ID                 => vec_write_rd_ID,
        RD_Data_IE                      => RD_Data_IE,
        RS1_Data_IE                     => RS1_Data_IE,
        RS2_Data_IE                     => RS2_Data_IE,
        -- Scratchpad Interface Signals
        dsp_data_gnt_i                  => dsp_data_gnt_i,

        -- input form MAPPING_OUT_UNIT_comb
        SIMD_RD_BYTES_wire              => SIMD_RD_BYTES_wire,

        FUNCT_SELECT_MASK               => FUNCT_SELECT_MASK, -- when the mask is set to "FFFFFFFF" we enable KDOTP32 execution using the 16-bit muls
        twos_complement                 => twos_complement,
        relu_instr                      => relu_instr,
        rf_rs2                          => rf_rs2,
        dotpps                          => dotpps,  -- indicator used in the pipeline handler to switch functional units
        dotp                            => dotp,  -- indicator used in the pipeline handler to switch functional units
        slt                             => slt,  -- indicator used in the pipeline handler to switch functional units
        carry_pass                      => carry_pass,  -- carry enable signal, depending on it's configuration, we can do KADDV8, KADDV16, KADDV32
        
        MPSCLFAC_DSP                    => MPSCLFAC_DSP,
        MVTYPE_DSP                      => MVTYPE_DSP,
        decoded_instruction_DSP_lat     => decoded_instruction_DSP_lat,
        dsp_rs1_to_sc                   => dsp_rs1_to_sc,
        dsp_rs2_to_sc                   => dsp_rs2_to_sc,
        dsp_rd_to_sc                    => dsp_rd_to_sc,

        -- common signals with stage exec
        vec_write_rd_DSP                => vec_write_rd_DSP,  -- Indicates whether the result being written is a vector or a scalar
        vec_read_rs1_DSP                => vec_read_rs1_DSP,  -- Indicates whether the operand being read is a vector or a scalar
        vec_read_rs2_DSP                => vec_read_rs2_DSP,  -- Indicates whether the operand being read is a vector or a scalar
        MVSIZE_READ_MASK                => MVSIZE_READ_MASK_s,  -- Bytes remaining to read
        MVSIZE_WRITE                    => MVSIZE_WRITE_s,  -- Bytes remaining to write
        RD_Data_IE_lat                  => RD_Data_IE_lat_s,
        RS1_Data_IE_lat                 => RS1_Data_IE_lat_s,
        RS2_Data_IE_lat                 => RS2_Data_IE_lat_s,
        MVSIZE_READ                     => MVSIZE_READ_s  -- Bytes remaining to read
        );

exec_stage: DSP_Exec_Unit_stage_exec
    generic map(
        Addr_Width            => Addr_Width,
        --------------------------------
        SIMD_Width            => SIMD_Width
    )
    port map(
        --INPUTS
        clk_i                           => clk_i,
        rst_ni                          => rst_ni,
        enable_i                        => enable_exec_stage_s,
        -- input from DSP_Excpt_Cntrl_Unit_comb
        recover_state_wires             => recover_state_wires,
        halt_dsp                        => halt_dsp,
        wb_ready                        => wb_ready,
        -- input from fsm_DSP_pipeline_controller
        halt_dsp_lat                    => halt_dsp_lat,
        SIMD_RD_BYTES                   => SIMD_RD_BYTES,
        -- input from MAPPING_OUT_UNIT_comb
        dsp_sc_data_write_wire_int      => dsp_sc_data_write_wire_int,
        SIMD_RD_BYTES_wire              => SIMD_RD_BYTES_wire,
        dsp_data_gnt_i_lat              => dsp_data_gnt_i_lat,
         -- Scratchpad Interface Signals
        dsp_data_gnt_i                  => dsp_data_gnt_i,
        
        -- OUTPUTS
        recover_state                   => recover_state,
        dsp_sc_data_write_int           => dsp_sc_data_write_int,
        dsp_sc_data_read_mask           => dsp_sc_data_read_mask,

        --Common signals with stage init
        RD_Data_IE_lat_i                => RD_Data_IE_lat_s,  -- from DSP_Exec_Unit_stage_init
        RD_Data_IE_lat_o                => RD_Data_IE_lat,
        MVSIZE_WRITE_i                  => MVSIZE_WRITE_s,  -- Bytes remaining to write
        MVSIZE_WRITE_o                  => MVSIZE_WRITE, -- Bytes remaining to write
        MVSIZE_READ_i                   => MVSIZE_READ_s,  -- Bytes remaining to read
        MVSIZE_READ_o                   => MVSIZE_READ,   -- Bytes remaining to read
        RS1_Data_IE_lat_i               => RS1_Data_IE_lat_s,
        RS1_Data_IE_lat_o               => RS1_Data_IE_lat,
        RS2_Data_IE_lat_i               => RS2_Data_IE_lat_s,
        RS2_Data_IE_lat_o               => RS2_Data_IE_lat,
        MVSIZE_READ_MASK_i              => MVSIZE_READ_MASK_s,  -- Bytes remaining to read
        vec_write_rd_DSP                => vec_write_rd_DSP,  -- Indicates whether the result being written is a vector or a scalar
        vec_read_rs1_DSP                => vec_read_rs1_DSP,  -- Indicates whether the operand being read is a vector or a scalar
        vec_read_rs2_DSP                => vec_read_rs2_DSP  -- Indicates whether the operand being read is a vector or a scalar
        );

end architecture DSP_Exec_Unit_arch;