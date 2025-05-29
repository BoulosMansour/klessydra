-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_FU_Handler_MT is
    generic (
        THREAD_POOL_SIZE      : integer;
        --------------------------------
        ACCL_NUM              : natural;
        TPS_CEIL              : natural;
        TPS_BUF_CEIL          : natural
    );
    port(
    -- ID_Stage Signals
    decoded_instruction_DSP         : in  std_logic_vector(DSP_UNIT_INSTR_SET_SIZE-1 downto 0);
    dsp_instr_req                   : in  std_logic;
    --input from DSP_Excpt_Cntrl_Unit_comb
    busy_dsp_internal               : in std_logic;
    -- input from DSP_pipeline_controller
    busy_DSP_internal_lat           : in std_logic;
    state_DSP                       : in std_logic_vector(1 downto 0);
    --inputs from DSP_FU_Enabler_Sync
    cmp_en                          : in std_logic;  -- enables the use of the shifters
    shift_en                        : in std_logic;  -- enables the use of the shifters
    add_en                          : in std_logic;  -- enables the use of the adders
    mul_en                          : in std_logic;  -- enables the use of the multipliers
    accum_en                        : in std_logic;  -- enables the use of the accumulator
    add_en_pending                  : in std_logic;  -- signal to preserve the request to access the adder "multhithreaded mode" only
    shift_en_pending                : in std_logic;  -- signal to preserve the request to access the shifter "multhithreaded mode" only
    mul_en_pending                  : in std_logic;  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
    accum_en_pending                : in std_logic;  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
    cmp_en_pending                  : in std_logic;  -- signal to preserve the request to access the ReLU "multhithreaded mode" only
    --inputs from DSP_FU_Handler
    busy_add_wire                   : std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_mul_wire                   : std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_shf_wire                   : std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_acc_wire                   : std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_cmp_wire                   : std_logic  -- busy signal active only when the FU is shared and currently in use 
    );
end entity DSP_FU_Handler_MT;

architecture DSP_FU_Handler_MT_arch of DSP_FU_Handler_MT is
component DSP_FU_Handler_MT_fu_enabler_comb is
port(
    -- ID_Stage Signals --input port
    decoded_instruction_DSP         : in  std_logic_vector(DSP_UNIT_INSTR_SET_SIZE-1 downto 0);
    dsp_instr_req                   : in  std_logic;
    --input from DSP_Excpt_Cntrl_Unit_comb --input port
    busy_dsp_internal               : in std_logic;
    -- input from DSP_pipeline_controller --input port
    busy_DSP_internal_lat           : in std_logic;
    state_DSP                       : in std_logic_vector(1 downto 0);
    --inputs from DSP_FU_Enabler_Sync --input port
    cmp_en                          : in std_logic;  -- enables the use of the shifters
    shift_en                        : in std_logic;  -- enables the use of the shifters
    add_en                          : in std_logic;  -- enables the use of the adders
    mul_en                          : in std_logic;  -- enables the use of the multipliers
    accum_en                        : in std_logic;  -- enables the use of the accumulator
    add_en_pending                  : in std_logic;  -- signal to preserve the request to access the adder "multhithreaded mode" only
    shift_en_pending                : in std_logic;  -- signal to preserve the request to access the shifter "multhithreaded mode" only
    mul_en_pending                  : in std_logic;  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
    accum_en_pending                : in std_logic;  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
    cmp_en_pending                  : in std_logic;  -- signal to preserve the request to access the ReLU "multhithreaded mode" only
    --input from DSP_FU_Handler_MT_busy_fu_sync --signal
    busy_add                        : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_mul                        : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_shf                        : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_acc                        : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_cmp                        : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
    --input from DSP_FU_Handler_MT_fu_issue_buffer_sync --signal
    fu_gnt                          : in std_logic_vector(4 downto 0); -- grant signal from the FU issue buffer

    --OUTPUTS --signal
    fu_req                          : out std_logic_vector(4 downto 0); -- Each threa has request bits equal to the total number of FUs
    --outputs to DSP_FU_Enabler_Sync
    cmp_en_wire                     : out std_logic;  -- enables the use of the shifters
    shift_en_wire                   : out std_logic;  -- enables the use of the shifters
    add_en_wire                     : out std_logic;  -- enables the use of the adders
    mul_en_wire                     : out std_logic;  -- enables the use of the multipliers
    accum_en_wire                   : out std_logic;  -- enables the use of the accumulatorss
    add_en_pending_wire             : out std_logic;  -- signal to preserve the request to access the adder "multhithreaded mode" only
    shift_en_pending_wire           : out std_logic;  -- signal to preserve the request to access the shifter "multhithreaded mode" only
    mul_en_pending_wire             : out std_logic;  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
    accum_en_pending_wire           : out std_logic;  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
    cmp_en_pending_wire             : out std_logic;  -- signal to preserve the request to access the ReLU "multhithreaded mode" only
    --outputs to DSP_Excpt_Cntrl_Unit_comb
    halt_hart                       : out std_logic -- halts the thread when the requested functional unit is in use
    );
end component DSP_FU_Handler_MT_fu_enabler_comb;

component DSP_FU_Issue_Buffer_Sync is --this component should not be repicated, the signals already have the correct dimensions
    generic (
        THREAD_POOL_SIZE      : integer;
        --------------------------------
        ACCL_NUM              : natural;
        TPS_CEIL              : natural;
        TPS_BUF_CEIL          : natural
    );
    port(
    -- Core Signals
    clk_i, rst_ni                   : in std_logic;
    --inputs from DSP_pipeline_controller
    state_DSP                       : in array_2d(ACCL_NUM-1 downto 0)(1 downto 0);
    --inputs from DSP_FU_Handler_MT_fu_issue_buffer_comb
    fu_gnt_wire                     : in array_2D(ACCL_NUM-1 downto 0)(4 downto 0); -- Each threa has grant bits equal to the total number of FUs
    fu_gnt_en                       : in array_2D(ACCL_NUM-1 downto 0)(4 downto 0); -- Enable the giving of the grant to the thread pointed at by the issue buffer
    --inputs from DSP_FU_Handler_MT_fu_enabler_comb
    fu_req                          : in array_2D(ACCL_NUM-1 downto 0)(4 downto 0); -- Each threa has request bits equal to the total number of FUs

    --OUTPUTS
    fu_rd_ptr                       : out array_2D(4 downto 0)(TPS_BUF_CEIL-1 downto 0); -- five rd pointers each has a number of bits equal to ceil(log2(THREAD_POOL_SIZE-1))
    fu_gnt                          : out array_2D(ACCL_NUM-1 downto 0)(4 downto 0); -- Each threa has grant bits equal to the total number of FUs
    fu_issue_buffer                 : out array_3D(4 downto 0)(THREAD_POOL_SIZE-2 downto 0)(TPS_CEIL-1 downto 0)
    );
end component DSP_FU_Issue_Buffer_Sync;

component DSP_FU_Issue_Buffer_Comb is
    generic (
        THREAD_POOL_SIZE      : integer;
        --------------------------------
        TPS_CEIL              : natural;
        TPS_BUF_CEIL          : natural  
    );
    port(
        --inputs from DSP_pipeline_controller
        state_DSP                       : in std_logic_vector(1 downto 0);
        --inputs from DSP_FU_Handler
        busy_add_wire                   : std_logic;  -- busy signal active only when the FU is shared and currently in use 
        busy_mul_wire                   : std_logic;  -- busy signal active only when the FU is shared and currently in use 
        busy_shf_wire                   : std_logic;  -- busy signal active only when the FU is shared and currently in use 
        busy_acc_wire                   : std_logic;  -- busy signal active only when the FU is shared and currently in use 
        busy_cmp_wire                   : std_logic;  -- busy signal active only when the FU is shared and currently in use 
        --inputs from DSP_FU_Enabler_comb
        add_en_pending_wire             : std_logic;  -- signal to preserve the request to access the adder "multhithreaded mode" only
        shift_en_pending_wire           : std_logic;  -- signal to preserve the request to access the shifter "multhithreaded mode" only
        mul_en_pending_wire             : std_logic;  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
        accum_en_pending_wire           : std_logic;  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
        cmp_en_pending_wire             : std_logic;  -- signal to preserve the request to access the ReLU "multhithreaded mode" only
        --inputs from DSP_FU_Issue_Buffer_Sync
        fu_issue_buffer                 : array_3D(4 downto 0)(THREAD_POOL_SIZE-2 downto 0)(TPS_CEIL-1 downto 0);
        fu_rd_ptr                       : array_2D(4 downto 0)(TPS_BUF_CEIL-1 downto 0); -- five rd pointers each has a number of bits equal to ceil(log2(THREAD_POOL_SIZE-1))

        --output for DSP_FU_Issue_Buffer_Sync
        fu_gnt_wire                     : out std_logic_vector(4 downto 0); -- Each threa has grant bits equal to the total number of FUs
        fu_gnt_en                       : out std_logic_vector(4 downto 0) -- Enable the giving of the grant to the thread pointed at by the issue buffer
    );
end component DSP_FU_Issue_Buffer_Comb;

component DSP_Busy_FU_Sync is
    port(
    -- Core Signals
    clk_i, rst_ni                   : in std_logic;
    --inputs from DSP_FU_Handler
    busy_add_wire                   : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_mul_wire                   : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_shf_wire                   : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_acc_wire                   : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_cmp_wire                   : in std_logic;  -- busy signal active only when the FU is shared and currently in use 

    --OUTPUTS - signals
    busy_add                        : out std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_mul                        : out std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_shf                        : out std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_acc                        : out std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_cmp                        : out std_logic  -- busy signal active only when the FU is shared and currently in use 
    );
end component DSP_Busy_FU_Sync;

begin
end architecture DSP_FU_Handler_MT_arch;