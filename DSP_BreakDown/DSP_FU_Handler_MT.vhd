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
    -- Core Signals
    clk_i, rst_ni                   : in std_logic;
    -- ID_Stage Signals
    decoded_instruction_DSP         : in  std_logic_vector(DSP_UNIT_INSTR_SET_SIZE-1 downto 0);
    dsp_instr_req                   : in  std_logic_vector(ACCL_NUM-1 downto 0);
    --input from DSP_Excpt_Cntrl_Unit_comb
    busy_dsp_internal               : in std_logic_vector(ACCL_NUM-1 downto 0);
    -- input from DSP_pipeline_controller
    busy_DSP_internal_lat           : in std_logic_vector(ACCL_NUM-1 downto 0);
    state_DSP                       : in array_2d(ACCL_NUM-1 downto 0)(1 downto 0);
    --inputs from DSP_FU_Enabler_Sync
    cmp_en                          : in std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the shifters
    shift_en                        : in std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the shifters
    add_en                          : in std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the adders
    mul_en                          : in std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the multipliers
    accum_en                        : in std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the accumulator
    
    --outputs to DSP_FU_Enabler_Sync
    cmp_en_wire                     : out std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the shifters
    shift_en_wire                   : out std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the shifters
    add_en_wire                     : out std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the adders
    mul_en_wire                     : out std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the multipliers
    accum_en_wire                   : out std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the accumulatorss
    --outputs to DSP_Excpt_Cntrl_Unit_comb
    halt_hart                       : out std_logic_vector(ACCL_NUM-1 downto 0) -- halts the thread when the requested functional unit is in use
    );
end entity DSP_FU_Handler_MT;

architecture DSP_FU_Handler_MT_arch of DSP_FU_Handler_MT is

subtype accl_range is integer range ACCL_NUM - 1 downto 0;

signal busy_add                         : std_logic;  -- busy signal active only when the FU is shared and currently in use 
signal busy_mul                         : std_logic;  -- busy signal active only when the FU is shared and currently in use 
signal busy_shf                         : std_logic;  -- busy signal active only when the FU is shared and currently in use 
signal busy_acc                         : std_logic;  -- busy signal active only when the FU is shared and currently in use 
signal busy_cmp                         : std_logic;  -- busy signal active only when the FU is shared and currently in use 
signal fu_gnt                           : array_2D(accl_range)(4 downto 0); -- grant signal from the FU issue buffer
signal fu_req                           : array_2D(accl_range)(4 downto 0); -- Each threa has request bits equal to the total number of FUs
signal fu_gnt_wire                      : array_2D(accl_range)(4 downto 0); -- Each threa has grant bits equal to the total number of FUs
signal fu_gnt_en                        : array_2D(accl_range)(4 downto 0); -- Enable the giving of the grant to the thread pointed at by the issue buffer
signal fu_rd_ptr                        : array_2D(4 downto 0)(TPS_BUF_CEIL-1 downto 0); -- five rd pointers each has a number of bits equal to ceil(log2(THREAD_POOL_SIZE-1))
signal fu_issue_buffer                  : array_3D(4 downto 0)(THREAD_POOL_SIZE-2 downto 0)(TPS_CEIL-1 downto 0);

signal add_en_pending                   : std_logic_vector(ACCL_NUM-1 downto 0);  -- signal to preserve the request to access the adder "multhithreaded mode" only
signal shift_en_pending                 : std_logic_vector(ACCL_NUM-1 downto 0);  -- signal to preserve the request to access the shifter "multhithreaded mode" only
signal mul_en_pending                   : std_logic_vector(ACCL_NUM-1 downto 0);  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
signal accum_en_pending                 : std_logic_vector(ACCL_NUM-1 downto 0);  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
signal cmp_en_pending                   : std_logic_vector(ACCL_NUM-1 downto 0);  -- signal to preserve the request to access the ReLU "multhithreaded mode" only
signal add_en_pending_wire              : std_logic_vector(ACCL_NUM-1 downto 0);  -- signal to preserve the request to access the adder "multhithreaded mode" only
signal shift_en_pending_wire            : std_logic_vector(ACCL_NUM-1 downto 0);  -- signal to preserve the request to access the shifter "multhithreaded mode" only
signal mul_en_pending_wire              : std_logic_vector(ACCL_NUM-1 downto 0);  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
signal accum_en_pending_wire            : std_logic_vector(ACCL_NUM-1 downto 0);  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
signal cmp_en_pending_wire              : std_logic_vector(ACCL_NUM-1 downto 0);  -- signal to preserve the request to access the ReLU "multhithreaded mode" only

signal busy_add_wire                    : std_logic;  -- busy signal active only when the FU is shared and currently in use 
signal busy_mul_wire                    : std_logic;  -- busy signal active only when the FU is shared and currently in use 
signal busy_shf_wire                    : std_logic;  -- busy signal active only when the FU is shared and currently in use 
signal busy_acc_wire                    : std_logic;  -- busy signal active only when the FU is shared and currently in use 
signal busy_cmp_wire                    : std_logic;  -- busy signal active only when the FU is shared and currently in use 


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
        busy_add_wire                   : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
        busy_mul_wire                   : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
        busy_shf_wire                   : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
        busy_acc_wire                   : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
        busy_cmp_wire                   : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
        --inputs from DSP_FU_Enabler_comb
        add_en_pending_wire             : in std_logic;  -- signal to preserve the request to access the adder "multhithreaded mode" only
        shift_en_pending_wire           : in std_logic;  -- signal to preserve the request to access the shifter "multhithreaded mode" only
        mul_en_pending_wire             : in std_logic;  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
        accum_en_pending_wire           : in std_logic;  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
        cmp_en_pending_wire             : in std_logic;  -- signal to preserve the request to access the ReLU "multhithreaded mode" only
        --inputs from DSP_FU_Issue_Buffer_Sync
        fu_issue_buffer                 : in array_3D(4 downto 0)(THREAD_POOL_SIZE-2 downto 0)(TPS_CEIL-1 downto 0);
        fu_rd_ptr                       : in array_2D(4 downto 0)(TPS_BUF_CEIL-1 downto 0); -- five rd pointers each has a number of bits equal to ceil(log2(THREAD_POOL_SIZE-1))

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

component DSP_FU_Handler_MT_pending_enabler_sync is
    port(
    -- Core Signals
    clk_i, rst_ni                   : in std_logic;
    --INPUTS
    add_en_pending_wire             : in std_logic;  -- signal to preserve the request to access the adder "multhithreaded mode" only
    shift_en_pending_wire           : in std_logic;  -- signal to preserve the request to access the shifter "multhithreaded mode" only
    mul_en_pending_wire             : in std_logic;  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
    accum_en_pending_wire           : in std_logic;  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
    cmp_en_pending_wire             : in std_logic;  -- signal to preserve the request to access the ReLU "multhithreaded mode" only

    --OUTPUTS
    add_en_pending                  : out std_logic;  -- signal to preserve the request to access the adder "multhithreaded mode" only
    shift_en_pending                : out std_logic;  -- signal to preserve the request to access the shifter "multhithreaded mode" only
    mul_en_pending                  : out std_logic;  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
    accum_en_pending                : out std_logic;  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
    cmp_en_pending                  : out std_logic  -- signal to preserve the request to access the ReLU "multhithreaded mode" only
    );
end component DSP_FU_Handler_MT_pending_enabler_sync;

begin
    DSP_FU_Handler_MT_fu_enabler_comb_replicated : for h in accl_range generate
        DSP_FU_Handler_MT_fu_enabler_comb_inst : DSP_FU_Handler_MT_fu_enabler_comb
        port map (
            -- ID_Stage Signals --input port
            decoded_instruction_DSP         => decoded_instruction_DSP,
            dsp_instr_req                   => dsp_instr_req(h),
            --input from DSP_Excpt_Cntrl_Unit_comb --input port
            busy_dsp_internal               => busy_dsp_internal(h),
            -- input from DSP_pipeline_controller --input port
            busy_DSP_internal_lat           => busy_DSP_internal_lat(h),
            state_DSP                       => state_DSP(h),
            --inputs from DSP_FU_Enabler_Sync --input port
            cmp_en                          => cmp_en(h),  -- enables the use of the shifters
            shift_en                        => shift_en(h),  -- enables the use of the shifters
            add_en                          => add_en(h),  -- enables the use of the adders
            mul_en                          => mul_en(h),  -- enables the use of the multipliers
            accum_en                        => accum_en(h),  -- enables the use of the accumulator
            add_en_pending                  => add_en_pending(h),  -- signal to preserve the request to access the adder "multhithreaded mode" only
            shift_en_pending                => shift_en_pending(h),  -- signal to preserve the request to access the shifter "multhithreaded mode" only
            mul_en_pending                  => mul_en_pending(h),  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
            accum_en_pending                => accum_en_pending(h),  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
            cmp_en_pending                  => cmp_en_pending(h),  -- signal to preserve the request to access the ReLU "multhithreaded mode" only
            --input from DSP_FU_Handler_MT_busy_fu_sync --signal
            busy_add                        => busy_add,
            busy_mul                        => busy_mul,
            busy_shf                        => busy_shf,
            busy_acc                        => busy_acc,
            busy_cmp                        => busy_cmp,
            --input from DSP_FU_Handler_MT_fu_issue_buffer_sync --signal
            fu_gnt                          => fu_gnt(h),

            --OUTPUTS --signal
            fu_req                          => fu_req(h), -- Each threa has request bits equal to the total number of FUs
            --outputs to DSP_FU_Enabler_Sync
            cmp_en_wire                     => cmp_en_wire(h),  -- enables the use of the shifters
            shift_en_wire                   => shift_en_wire(h),  -- enables the use of the shifters
            add_en_wire                     => add_en_wire(h),  -- enables the use of the adders
            mul_en_wire                     => mul_en_wire(h),  -- enables the use of the multipliers
            accum_en_wire                   => accum_en_wire(h),  -- enables the use of the accumulatorss
            add_en_pending_wire             => add_en_pending_wire(h),  -- signal to preserve the request to access the adder "multhithreaded mode" only
            shift_en_pending_wire           => shift_en_pending_wire(h),  -- signal to preserve the request to access the shifter "multhithreaded mode" only
            mul_en_pending_wire             => mul_en_pending_wire(h),  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
            accum_en_pending_wire           => accum_en_pending_wire(h),  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
            cmp_en_pending_wire             => cmp_en_pending_wire(h),  -- signal to preserve the request to access the ReLU "multhithreaded mode" only
            --outputs to DSP_Excpt_Cntrl_Unit_comb
            halt_hart                       => halt_hart(h) -- halts the thread when the requested functional unit is in use
        );
    end generate DSP_FU_Handler_MT_fu_enabler_comb_replicated;

    DSP_FU_Issue_Buffer_Sync_inst : DSP_FU_Issue_Buffer_Sync
        generic map (
            THREAD_POOL_SIZE      => THREAD_POOL_SIZE,
            ACCL_NUM              => ACCL_NUM,
            TPS_CEIL              => TPS_CEIL,
            TPS_BUF_CEIL          => TPS_BUF_CEIL
        )
        port map (
            -- Core Signals
            clk_i                   => clk_i,
            rst_ni                  => rst_ni,
            --inputs from DSP_pipeline_controller
            state_DSP               => state_DSP,
            --inputs from DSP_FU_Handler_MT_fu_issue_buffer_comb
            fu_gnt_wire             => fu_gnt_wire,
            fu_gnt_en               => fu_gnt_en,
            --inputs from DSP_FU_Handler_MT_fu_enabler_comb
            fu_req                  => fu_req,

            --OUTPUTS
            fu_rd_ptr               => fu_rd_ptr,
            fu_gnt                  => fu_gnt, -- Each threa has grant bits equal to the total number of FUs
            fu_issue_buffer         => fu_issue_buffer
        );

    DSP_FU_Issue_Buffer_Comb_replicated: for h in accl_range generate
        DSP_FU_Issue_Buffer_Comb_inst: DSP_FU_Issue_Buffer_Comb
        generic map(
            THREAD_POOL_SIZE        => THREAD_POOL_SIZE,
            TPS_CEIL                => TPS_CEIL,
            TPS_BUF_CEIL            => TPS_BUF_CEIL
        )
        port map(
            --inputs from DSP_pipeline_controller
            state_DSP               => state_DSP(h),
            --inputs from DSP_FU_Handler
            busy_add_wire               => busy_add_wire, 
            busy_mul_wire               => busy_mul_wire, 
            busy_shf_wire               => busy_shf_wire, 
            busy_acc_wire               => busy_acc_wire, 
            busy_cmp_wire               => busy_cmp_wire, 
            --inputs from DSP_FU_Enabler_comb
            add_en_pending_wire         => add_en_pending_wire(h),
            shift_en_pending_wire       => shift_en_pending_wire(h),
            mul_en_pending_wire         => mul_en_pending_wire(h),
            accum_en_pending_wire       => accum_en_pending_wire(h),
            cmp_en_pending_wire         => cmp_en_pending_wire(h),
            --inputs from DSP_FU_Issue_Buffer_Sync
            fu_issue_buffer             => fu_issue_buffer,
            fu_rd_ptr                   => fu_rd_ptr,

            --output for DSP_FU_Issue_Buffer_Sync
            fu_gnt_wire                 => fu_gnt_wire(h),
            fu_gnt_en                   => fu_gnt_en(h)    
        );
    end generate DSP_FU_Issue_Buffer_Comb_replicated;

    DSP_Busy_FU_Sync_inst: DSP_Busy_FU_Sync
    port map(
        -- Core Signals
        clk_i                   => clk_i,
        rst_ni                  => rst_ni,
        --inputs from DSP_FU_Handler
        busy_add_wire           => busy_add_wire,
        busy_mul_wire           => busy_mul_wire,
        busy_shf_wire           => busy_shf_wire,
        busy_acc_wire           => busy_acc_wire,
        busy_cmp_wire           => busy_cmp_wire,

        --OUTPUTS - signals
        busy_add                => busy_add,
        busy_mul                => busy_mul,
        busy_shf                => busy_shf,
        busy_acc                => busy_acc,
        busy_cmp                => busy_cmp
    );

    DSP_FU_Handler_MT_pending_enabler_sync_replicated: for h in accl_range generate
        DSP_FU_Handler_MT_pending_enabler_sync_inst: DSP_FU_Handler_MT_pending_enabler_sync
        port map(
            -- Core Signals
            clk_i                   => clk_i,
            rst_ni                  => rst_ni,
            --INPUTS
            add_en_pending_wire     => add_en_pending_wire(h),  -- signal to preserve the request to access the adder "multhithreaded mode" only
            shift_en_pending_wire   => shift_en_pending_wire(h),  -- signal to preserve the request to access the shifter "multhithreaded mode" only
            mul_en_pending_wire     => mul_en_pending_wire(h),  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
            accum_en_pending_wire   => accum_en_pending_wire(h),  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
            cmp_en_pending_wire     => cmp_en_pending_wire(h),  -- signal to preserve the request to access the ReLU "multhithreaded mode" only

            --OUTPUTS
            add_en_pending          => add_en_pending(h),  -- signal to preserve the request to access the adder "multhithreaded mode" only
            shift_en_pending        => shift_en_pending(h),  -- signal to preserve the request to access the shifter "multhithreaded mode" only
            mul_en_pending          => mul_en_pending(h),  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
            accum_en_pending        => accum_en_pending(h),  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
            cmp_en_pending          => cmp_en_pending(h)   -- signal to preserve the request to access the ReLU "multhithreaded mode" only
        );
    end generate DSP_FU_Handler_MT_pending_enabler_sync_replicated;

    busy_add_wire <= '1' when add_en_wire   /= (accl_range => '0') else '0';
    busy_mul_wire <= '1' when mul_en_wire   /= (accl_range => '0') else '0';
    busy_shf_wire <= '1' when shift_en_wire /= (accl_range => '0') else '0';
    busy_acc_wire <= '1' when accum_en_wire /= (accl_range => '0') else '0';
    busy_cmp_wire <= '1' when cmp_en_wire   /= (accl_range => '0') else '0';


end architecture DSP_FU_Handler_MT_arch;