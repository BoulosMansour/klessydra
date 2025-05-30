-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_FU_Handler is
    generic (
        multithreaded_accl_en : natural;
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
    cmp_en                          : out std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the shifters
    shift_en                        : out std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the shifters
    add_en                          : out std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the adders
    mul_en                          : out std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the multipliers
    accum_en                        : out std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the accumulator
    
    --outputs to DSP_Excpt_Cntrl_Unit_comb
    halt_hart                       : out std_logic_vector(ACCL_NUM-1 downto 0) -- halts the thread when the requested functional unit is in use
    );
end entity DSP_FU_Handler;

architecture DSP_FU_Handler of DSP_FU_Handler is
    subtype accl_range is integer range ACCL_NUM - 1 downto 0;

    --outputs to DSP_FU_Enabler_Sync
    signal cmp_en_wire                     : std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the shifters
    signal shift_en_wire                   : std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the shifters
    signal add_en_wire                     : std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the adders
    signal mul_en_wire                     : std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the multipliers
    signal accum_en_wire                   : std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the accumulatorss
    

    component DSP_FU_Handler_MT is
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
    end component DSP_FU_Handler_MT;

    component DSP_FU_Handler_MC is
        port(
        --ID_Stage Signals
        dsp_instr_req                   : in  std_logic;    
        decoded_instruction_DSP         : in  std_logic_vector(DSP_UNIT_INSTR_SET_SIZE-1 downto 0);
        --inputs from DSP_FU_Enabler_Sync
        cmp_en                          : in std_logic;  -- enables the use of the shifters
        shift_en                        : in std_logic;  -- enables the use of the shifters
        add_en                          : in std_logic;  -- enables the use of the adders
        mul_en                          : in std_logic;  -- enables the use of the multipliers
        accum_en                        : in std_logic;  -- enables the use of the accumulator
        --inputs from DSP_Excpt_Cntrl_Unit_comb
        busy_dsp_internal               : std_logic;
        -- inputs from fsm_DSP_pipeline_controller
        busy_DSP_internal_lat           : std_logic;
        state_DSP                       : in std_logic_vector(1 downto 0);

        --OUTPUTS
        cmp_en_wire                     : out std_logic;  -- enables the use of the shifters
        shift_en_wire                   : out std_logic;  -- enables the use of the shifters
        add_en_wire                     : out std_logic;  -- enables the use of the adders
        mul_en_wire                     : out std_logic;  -- enables the use of the multipliers
        accum_en_wire                   : out std_logic;  -- enables the use of the accumulatorss
        halt_hart                       : out std_logic   -- halts the thread when the requested functional unit is in use
        );
    end component  DSP_FU_Handler_MC;

    component DSP_FU_enabler_sync is
        port(
        -- Core Signals
        clk_i, rst_ni                   : in std_logic;
        cmp_en_wire                     : std_logic;  -- enables the use of the shifters
        shift_en_wire                   : std_logic;  -- enables the use of the shifters
        add_en_wire                     : std_logic;  -- enables the use of the adders
        mul_en_wire                     : std_logic;  -- enables the use of the multipliers
        accum_en_wire                   : std_logic;  -- enables the use of the accumulatorss

        --OUTPUTS
        cmp_en                          : out std_logic;  -- enables the use of the shifters
        shift_en                        : out std_logic;  -- enables the use of the shifters
        add_en                          : out std_logic;  -- enables the use of the adders
        mul_en                          : out std_logic;  -- enables the use of the multipliers
        accum_en                        : out std_logic  -- enables the use of the accumulator
        );
    end component DSP_FU_enabler_sync;
begin
    FU_HANDLER_MC : if multithreaded_accl_en = 0 generate
        DSP_FU_Handler_MC_inst : DSP_FU_Handler_MC
        port map (
            dsp_instr_req                   => dsp_instr_req(0),
            decoded_instruction_DSP         => decoded_instruction_DSP,
            cmp_en                          => cmp_en(0),
            shift_en                        => shift_en(0),
            add_en                          => add_en(0),
            mul_en                          => mul_en(0),
            accum_en                        => accum_en(0),
            busy_dsp_internal               => busy_dsp_internal(0),
            busy_DSP_internal_lat           => busy_DSP_internal_lat(0),
            state_DSP                       => state_DSP(0),
            cmp_en_wire                     => cmp_en_wire(0),
            shift_en_wire                   => shift_en_wire(0),
            add_en_wire                     => add_en_wire(0),
            mul_en_wire                     => mul_en_wire(0),
            accum_en_wire                   => accum_en_wire(0),
            halt_hart                       => halt_hart(0)
        );
    end generate FU_HANDLER_MC;

    FU_HANDLER_MT : if multithreaded_accl_en = 1 generate
        DSP_FU_Handler_MT_inst : DSP_FU_Handler_MT
        generic map (
            THREAD_POOL_SIZE      => THREAD_POOL_SIZE,
            --------------------------------
            ACCL_NUM              => ACCL_NUM,
            TPS_CEIL              => TPS_CEIL,
            TPS_BUF_CEIL          => TPS_BUF_CEIL
        )
        port map (
            clk_i                   => clk_i,
            rst_ni                  => rst_ni,
            decoded_instruction_DSP => decoded_instruction_DSP,
            dsp_instr_req           => dsp_instr_req,
            busy_dsp_internal       => busy_dsp_internal,
            busy_DSP_internal_lat   => busy_DSP_internal_lat,
            state_DSP               => state_DSP,
            cmp_en                  => cmp_en,
            shift_en                => shift_en,
            add_en                  => add_en,
            mul_en                  => mul_en,
            accum_en                => accum_en,
            cmp_en_wire             => cmp_en_wire,
            shift_en_wire           => shift_en_wire,
            add_en_wire             => add_en_wire,
            mul_en_wire             => mul_en_wire,
            accum_en_wire           => accum_en_wire,
            halt_hart               => halt_hart
        );
    end generate FU_HANDLER_MT;

    DSP_FU_ENABLER_SYNC_replicated : for h in accl_range generate
        DSP_FU_enabler_sync_inst : DSP_FU_enabler_sync
        port map (
            clk_i                   => clk_i,
            rst_ni                  => rst_ni,
            cmp_en_wire             => cmp_en_wire(h),
            shift_en_wire           => shift_en_wire(h),
            add_en_wire             => add_en_wire(h),
            mul_en_wire             => mul_en_wire(h),
            accum_en_wire           => accum_en_wire(h),
            cmp_en                  => cmp_en(h),
            shift_en                => shift_en(h),
            add_en                  => add_en(h),
            mul_en                  => mul_en(h),
            accum_en                => accum_en(h)
        );
    end generate DSP_FU_ENABLER_SYNC_replicated;
end architecture DSP_FU_Handler;