-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Mapping is
    generic (
        THREAD_POOL_SIZE      : integer;
        SIMD                  : natural;
        multithreaded_accl_en : natural;
        --------------------------------
        ACCL_NUM              : natural;
        FU_NUM                : natural;
        Data_Width            : natural;
        SIMD_Width            : natural
        
    );
    port(
        -- CSR Signals
        MVTYPE                          : in  array_2d_MVTYPE(THREAD_POOL_SIZE-1 downto 0);
        -- Scratchpad Interface Signals
        dsp_sc_data_read                : in  array_3d_dsp_operands(ACCL_NUM-1 downto 0);
        -- ID_Stage Signals
        dsp_instr_req                   : in  std_logic_vector(ACCL_NUM-1 downto 0);
        decoded_instruction_DSP         : in  std_logic_vector(DSP_UNIT_INSTR_SET_SIZE-1 downto 0);
        -- input from ACCUMULATOR
        dsp_out_accum_results           : in array_2d_dsp_out_accum_results(FU_NUM-1 downto 0);
        -- input from DSP_pipeline_controller
        busy_DSP_internal_lat           : in std_logic_vector(ACCL_NUM-1 downto 0);
        SIMD_RD_BYTES                   : in array_2d_int(ACCL_NUM-1 downto 0);
        state_DSP                       : in array_2d_state_DSP(ACCL_NUM-1 downto 0);
        halt_dsp_lat                    : in std_logic_vector(ACCL_NUM-1 downto 0);
        -- input from DSP_Exec_Unit
        decoded_instruction_DSP_lat     : in array_2d_decoded_instruction_DSP_lat(ACCL_NUM-1 downto 0);
        MVTYPE_DSP                      : in array_2d_MVTYPE_DSP(ACCL_NUM-1 downto 0);
        RS1_Data_IE_lat                 : in array_2d_Data_IE_lat(ACCL_NUM-1 downto 0);
        dsp_sc_data_write_int           : in array_2d_dsp_operands(ACCL_NUM-1 downto 0);
        dsp_sc_data_read_mask           : in array_2d_dsp_operands(ACCL_NUM-1 downto 0);
        vec_read_rs2_DSP                : in std_logic_vector(ACCL_NUM-1 downto 0);  -- Indicates whether the operand being read is a vector or a scalar
        MPSCLFAC_DSP                    : in array_2d_MPSCLFAC(ACCL_NUM-1 downto 0);
        dotp                            : in std_logic_vector(ACCL_NUM-1 downto 0);  -- indicator used in the pipeline handler to switch functional units
        dotpps                          : in std_logic_vector(ACCL_NUM-1 downto 0);  -- indicator used in the pipeline handler to switch functional units
        rf_rs2                          : in std_logic_vector(ACCL_NUM-1 downto 0);  -- Indicates whether the operand being read is a vector or a scalar
        RS2_Data_IE_lat                 : in array_2d_Data_IE_lat(ACCL_NUM-1 downto 0);
        -- input from DSP_Excpt_Unit
        halt_dsp                        : in std_logic_vector(ACCL_NUM-1 downto 0);
        -- input from multiplier stage 2
        dsp_out_mul_results             : in array_2d_dsp_operands(FU_NUM-1 downto 0);
        -- input from shifter stage 2
        dsp_out_shifter_results         : in array_2d_dsp_operands(FU_NUM-1 downto 0);
        -- input from adder stage 2
        dsp_out_adder_results           : in array_2d_dsp_operands(FU_NUM-1 downto 0);
        -- input from comparators
        dsp_out_cmp_results             : in array_2d_dsp_operands(FU_NUM-1 downto 0);

        -- output for DSP_Exec_Unit
        dsp_sc_data_write_wire_int      : inout array_2d_dsp_operands(ACCL_NUM-1 downto 0);
        SIMD_RD_BYTES_wire              : out array_2d_int(ACCL_NUM-1 downto 0);
        -- Scratchpad Interface Signals
        dsp_sc_data_write_wire          : out array_2d_dsp_operands(ACCL_NUM-1 downto 0);
        -- output for ACCUMULATOR
        dsp_in_accum_operands           : out array_2d_dsp_operands(FU_NUM-1 downto 0);
        -- output for adder 
        MSB_stage_1                     : out array_3d_MSB_stage(ACCL_NUM-1 downto 0);
        dsp_in_adder_operands           : out array_3d_dsp_operands(FU_NUM-1 downto 0);
        -- output for shifter
        dsp_in_shift_amount             : out array_2d_dsp_shift_amount(ACCL_NUM-1 downto 0);
        dsp_in_shifter_operand          : out array_2d_dsp_operands(FU_NUM-1 downto 0);
        -- output for comparator
        dsp_in_cmp_operands             : out array_2d_dsp_operands(FU_NUM-1 downto 0);
        -- output for multiplier stage 1
        dsp_in_mul_operands             : out array_3d_dsp_operands(FU_NUM-1 downto 0)
    );
end entity DSP_Mapping;

architecture DSP_Mapping_arch of DSP_Mapping is

constant DMR_ENABLED : boolean := false;
constant TMR_ENABLED : boolean := false;

-- output for ACCUMULATOR
signal dsp_in_accum_operands_tmp           : array_2d_dsp_operands(FU_NUM-1 downto 0);
-- output for adder 
signal MSB_stage_1_tmp                     : array_3d_MSB_stage(ACCL_NUM-1 downto 0);
signal dsp_in_adder_operands_tmp           : array_3d_dsp_operands(FU_NUM-1 downto 0);
-- output for shifter
signal dsp_in_shift_amount_tmp             : array_2d_dsp_shift_amount(ACCL_NUM-1 downto 0);
signal dsp_in_shifter_operand_tmp          : array_2d_dsp_operands(FU_NUM-1 downto 0);
-- output for comparator
signal dsp_in_cmp_operands_tmp             : array_2d_dsp_operands(FU_NUM-1 downto 0);
-- output for multiplier stage 1
signal dsp_in_mul_operands_tmp             : array_3d_dsp_operands(FU_NUM-1 downto 0);

subtype accl_range is integer range ACCL_NUM - 1 downto 0;
subtype fu_range   is integer range FU_NUM - 1 downto 0;

component DMR is
	port(
		in1, in2 : in std_logic;
		err_flag : out std_logic;
		result : out std_logic
	);
end component DMR;

component TMR is
	port(
		in1, in2, in3 : in std_logic;
		result : out std_logic
	);
end component TMR;

component DSP_Mapping_Multicore_Out_Mapper is
    generic (
        SIMD                  : natural;
        --------------------------------
        Data_Width            : natural;
        SIMD_Width            : natural
        
    );
    port(
        -- CSR Signals
        MVTYPE                          : in  std_logic_vector(3 downto 0);
        -- ID_Stage Signals
        dsp_instr_req                   : in  std_logic;
        decoded_instruction_DSP         : in  std_logic_vector(DSP_UNIT_INSTR_SET_SIZE-1 downto 0);
        -- input from ACCUMULATOR
        dsp_out_accum_results           : in std_logic_vector(31 downto 0);
        -- input from DSP_pipeline_controller
        busy_DSP_internal_lat           : in std_logic;
        SIMD_RD_BYTES                   : in integer;
        state_DSP                       : in std_logic_vector(1 downto 0);
        halt_dsp_lat                    : in std_logic;
        -- input from DSP_Exec_Unit
        decoded_instruction_DSP_lat     : in std_logic_vector(DSP_UNIT_INSTR_SET_SIZE -1 downto 0);
        MVTYPE_DSP                      : in std_logic_vector(1 downto 0);
        RS1_Data_IE_lat                 : in std_logic_vector(31 downto 0);
        dsp_sc_data_write_int           : in std_logic_vector(SIMD_Width-1 downto 0);
        -- input from DSP_Excpt_Unit
        halt_dsp                        : in std_logic;
        -- input from multiplier stage 2
        dsp_out_mul_results             : in std_logic_vector(SIMD_Width-1 downto 0);
        -- input from shifter stage 2
        dsp_out_shifter_results         : in std_logic_vector(SIMD_Width-1 downto 0);
        -- input from adder stage 2
        dsp_out_adder_results           : in std_logic_vector(SIMD_Width-1 downto 0);
        -- input from comparators
        dsp_out_cmp_results             : in std_logic_vector(SIMD_Width-1 downto 0);

        -- output for DSP_Exec_Unit
        dsp_sc_data_write_wire_int      : inout std_logic_vector(SIMD_Width-1 downto 0);
        SIMD_RD_BYTES_wire              : out integer;
        -- Scratchpad Interface Signals
        dsp_sc_data_write_wire          : out std_logic_vector(SIMD_Width-1 downto 0)

    );
end component DSP_Mapping_Multicore_Out_Mapper;

component DSP_Mapping_IN_Unit_Multicore is
    generic (
        SIMD                  : natural;
        --------------------------------
        SIMD_Width            : natural
    );
    port(
        -- ID_Stage Signals
        dsp_instr_req                   : in  std_logic;
        -- Scratchpad Interface Signals
        dsp_sc_data_read                : in  array_2d_dsp_operands(1 downto 0);
        -- input from DSP_pipeline_controller
        busy_DSP_internal_lat           : in std_logic;
        state_DSP                       : in std_logic_vector(1 downto 0);
        -- input from DSP_Exec_Unit
        decoded_instruction_DSP_lat     : in std_logic_vector(DSP_UNIT_INSTR_SET_SIZE -1 downto 0);
        dsp_sc_data_read_mask           : in std_logic_vector(SIMD_Width-1 downto 0);
        vec_read_rs2_DSP                : in std_logic;  -- Indicates whether the operand being read is a vector or a scalar
        MVTYPE_DSP                      : in std_logic_vector(1 downto 0);
        MPSCLFAC_DSP                    : in std_logic_vector(4 downto 0);
        dotp                            : in std_logic;  -- indicator used in the pipeline handler to switch functional units
        dotpps                          : in std_logic;  -- indicator used in the pipeline handler to switch functional units
        rf_rs2                          : in std_logic;
        RS2_Data_IE_lat                 : in std_logic_vector(31 downto 0);
        -- input from multiplier stage 2
        dsp_out_mul_results             : in std_logic_vector(SIMD_Width-1 downto 0);
        -- input from shifter stage 2
        dsp_out_shifter_results         : in std_logic_vector(SIMD_Width-1 downto 0);
        -- input from adder stage 2
        dsp_out_adder_results           : in std_logic_vector(SIMD_Width-1 downto 0);

        -- output for ACCUMULATOR
        dsp_in_accum_operands           : out std_logic_vector(SIMD_Width-1 downto 0);
        -- output for adder 
        MSB_stage_1                     : out array_2d_MSB_stage(1 downto 0);
        dsp_in_adder_operands           : out array_2d_dsp_operands(1 downto 0);
        -- output for shifter
        dsp_in_shift_amount             : out std_logic_vector(4 downto 0);
        dsp_in_shifter_operand          : out std_logic_vector(SIMD_Width-1 downto 0);
        -- output for comparator
        dsp_in_cmp_operands             : out std_logic_vector(SIMD_Width-1 downto 0);
        -- output for multiplier stage 1
        dsp_in_mul_operands             : out array_2d_dsp_operands(1 downto 0)
    );
end component DSP_Mapping_IN_Unit_Multicore;

component DSP_Mapping_Multithread_Out_Mapper is
    generic(
        SIMD                  : natural;
        --------------------------------
        Data_Width            : natural;
        SIMD_Width            : natural
    );
    port(-- IN THE TOP ENTITY CONNECT ONLY INDEX (0) FOR ALL SIGNALS HAVING SIZE OF fu_range
        -- CSR Signals
        MVTYPE                          : in  std_logic_vector(3 downto 0);
        -- ID_Stage Signals
        dsp_instr_req                   : in  std_logic;
        decoded_instruction_DSP         : in  std_logic_vector(DSP_UNIT_INSTR_SET_SIZE-1 downto 0);
        -- input from ACCUMULATOR
        dsp_out_accum_results           : in std_logic_vector(31 downto 0);
        -- input from DSP_pipeline_controller
        busy_DSP_internal_lat           : in std_logic;
        state_DSP                       : in std_logic_vector(1 downto 0);
        halt_dsp_lat                    : std_logic;
        -- input from DSP_Exec_Unit
        decoded_instruction_DSP_lat     : in std_logic_vector(DSP_UNIT_INSTR_SET_SIZE -1 downto 0);
        MVTYPE_DSP                      : in std_logic_vector(1 downto 0);
        RS1_Data_IE_lat                 : in std_logic_vector(31 downto 0);
        dsp_sc_data_write_int           : in std_logic_vector(SIMD_Width-1 downto 0);
        -- input from DSP_Excpt_Unit
        halt_dsp                        : in std_logic;
        -- input from multiplier stage 2
        dsp_out_mul_results             : in std_logic_vector(SIMD_Width-1 downto 0);
        -- input from shifter stage 2
        dsp_out_shifter_results         : in std_logic_vector(SIMD_Width-1 downto 0);
        -- input from adder stage 2
        dsp_out_adder_results           : in std_logic_vector(SIMD_Width-1 downto 0);
        -- input from comparators
        dsp_out_cmp_results             : in std_logic_vector(SIMD_Width-1 downto 0);

        --output for DSP_Exec_Unit
        dsp_sc_data_write_wire_int      : inout std_logic_vector(SIMD_Width-1 downto 0);
        SIMD_RD_BYTES_wire              : out integer;
        -- Scratchpad Interface Signals
        dsp_sc_data_write_wire          : out std_logic_vector(SIMD_Width-1 downto 0)
    );
end component DSP_Mapping_Multithread_Out_Mapper;

component DSP_Mapping_IN_Unit_Multithread is
    generic (
        SIMD                  : natural;
        --------------------------------
        SIMD_Width            : natural
    );
    port(
        -- ID_Stage Signals
        dsp_instr_req                   : in  std_logic;
        -- Scratchpad Interface Signals
        dsp_sc_data_read                : in  array_2d_dsp_operands(1 downto 0);
        -- input from DSP_pipeline_controller
        busy_DSP_internal_lat           : in std_logic;
        state_DSP                       : in std_logic_vector(1 downto 0);
        -- input from DSP_Exec_Unit
        decoded_instruction_DSP_lat     : in std_logic_vector(DSP_UNIT_INSTR_SET_SIZE -1 downto 0);
        dsp_sc_data_read_mask           : in std_logic_vector(SIMD_Width-1 downto 0);
        vec_read_rs2_DSP                : in std_logic;  -- Indicates whether the operand being read is a vector or a scalar
        MVTYPE_DSP                      : in std_logic_vector(1 downto 0);
        MPSCLFAC_DSP                    : in std_logic_vector(4 downto 0);
        dotp                            : in std_logic;  -- indicator used in the pipeline handler to switch functional units
        dotpps                          : in std_logic;  -- indicator used in the pipeline handler to switch functional units
        rf_rs2                          : in std_logic;
        RS2_Data_IE_lat                 : in std_logic_vector(31 downto 0);
        -- input from multiplier stage 2
        dsp_out_mul_results             : in std_logic_vector(SIMD_Width-1 downto 0);
        -- input from shifter stage 2
        dsp_out_shifter_results         : in std_logic_vector(SIMD_Width-1 downto 0);
        -- input from adder stage 2
        dsp_out_adder_results           : in std_logic_vector(SIMD_Width-1 downto 0);

        -- output for ACCUMULATOR
        dsp_in_accum_operands           : out std_logic_vector(SIMD_Width-1 downto 0);
        -- output for adder 
        MSB_stage_1                     : out array_2d_MSB_stage(1 downto 0);
        dsp_in_adder_operands           : out array_2d_dsp_operands(1 downto 0);
        -- output for shifter
        dsp_in_shift_amount             : out std_logic_vector(4 downto 0);
        dsp_in_shifter_operand          : out std_logic_vector(SIMD_Width-1 downto 0);
        -- output for comparator
        dsp_in_cmp_operands             : out std_logic_vector(SIMD_Width-1 downto 0);
        -- output for multiplier stage 1
        dsp_in_mul_operands             : out array_2d_dsp_operands(1 downto 0)
    );
end component DSP_Mapping_IN_Unit_Multithread;

begin

MAPPING_MULTICORE: if multithreaded_accl_en = 0 generate
    MAPPING_OUT_UNIT_replicated: for h in fu_range generate
        MAPPING_OUT_UNIT: DSP_Mapping_Multicore_Out_Mapper
            generic map (
                SIMD => SIMD,
                Data_Width => Data_Width,
                SIMD_Width => SIMD_Width
            )
            port map (
                MVTYPE => MVTYPE(h),
                dsp_instr_req => dsp_instr_req(h),
                decoded_instruction_DSP => decoded_instruction_DSP,
                dsp_out_accum_results => dsp_out_accum_results(h),
                busy_DSP_internal_lat => busy_DSP_internal_lat(h),
                SIMD_RD_BYTES => SIMD_RD_BYTES(h),
                state_DSP => state_DSP(h),
                halt_dsp_lat => halt_dsp_lat(h),
                decoded_instruction_DSP_lat => decoded_instruction_DSP_lat(h),
                MVTYPE_DSP => MVTYPE_DSP(h),
                RS1_Data_IE_lat => RS1_Data_IE_lat(h),
                dsp_sc_data_write_int => dsp_sc_data_write_int(h),
                halt_dsp => halt_dsp(h),
                dsp_out_mul_results => dsp_out_mul_results(h),
                dsp_out_shifter_results => dsp_out_shifter_results(h),
                dsp_out_adder_results => dsp_out_adder_results(h),
                dsp_out_cmp_results => dsp_out_cmp_results(h),

                dsp_sc_data_write_wire_int => dsp_sc_data_write_wire_int(h),
                SIMD_RD_BYTES_wire => SIMD_RD_BYTES_wire(h),
                dsp_sc_data_write_wire => dsp_sc_data_write_wire(h)
            );
    end generate MAPPING_OUT_UNIT_replicated;
            
    MAPPING_IN_UNIT_DMR: if DMR_ENABLED generate
        MAPPING_IN_UNIT_extra: if ACCL_NUM mod 2 /= 0 generate
            MAPPING_IN_UNIT_replicated: for h in ACCL_NUM - 1 downto ACCL_NUM - (ACCL_NUM mod 2) generate
                MAPPING_IN_UNIT: DSP_Mapping_IN_Unit_Multicore
                    generic map (
                        SIMD => SIMD,
                        SIMD_Width => SIMD_Width
                    )
                    port map (
                        dsp_instr_req => dsp_instr_req(h),
                        dsp_sc_data_read => dsp_sc_data_read(h),
                        busy_DSP_internal_lat => busy_DSP_internal_lat(h),
                        state_DSP => state_DSP(h),
                        decoded_instruction_DSP_lat => decoded_instruction_DSP_lat(h),
                        dsp_sc_data_read_mask => dsp_sc_data_read_mask(h),
                        vec_read_rs2_DSP => vec_read_rs2_DSP(h),
                        MVTYPE_DSP => MVTYPE_DSP(h),
                        MPSCLFAC_DSP => MPSCLFAC_DSP(h),
                        dotp => dotp(h),
                        dotpps => dotpps(h),
                        rf_rs2 => rf_rs2(h),
                        RS2_Data_IE_lat => RS2_Data_IE_lat(h),
                        dsp_out_mul_results => dsp_out_mul_results(h),
                        dsp_out_shifter_results => dsp_out_shifter_results(h),
                        dsp_out_adder_results => dsp_out_adder_results(h),

                        dsp_in_accum_operands => dsp_in_accum_operands_tmp(h),
                        MSB_stage_1 => MSB_stage_1_tmp(h),
                        dsp_in_adder_operands => dsp_in_adder_operands_tmp(h),
                        dsp_in_shift_amount => dsp_in_shift_amount_tmp(h),
                        dsp_in_shifter_operand => dsp_in_shifter_operand_tmp(h),
                        dsp_in_cmp_operands => dsp_in_cmp_operands_tmp(h),
                        dsp_in_mul_operands => dsp_in_mul_operands_tmp(h)
                    );
                -- Assign the temporary signals to the output signals directly
                dsp_in_accum_operands(h) <= dsp_in_accum_operands_tmp(h);
                MSB_stage_1(h) <= MSB_stage_1_tmp(h);
                dsp_in_adder_operands(h) <= dsp_in_adder_operands_tmp(h);
                dsp_in_shift_amount(h) <= dsp_in_shift_amount_tmp(h);
                dsp_in_shifter_operand(h) <= dsp_in_shifter_operand_tmp(h);
                dsp_in_cmp_operands(h) <= dsp_in_cmp_operands_tmp(h);
                dsp_in_mul_operands(h) <= dsp_in_mul_operands_tmp(h);
            end generate MAPPING_IN_UNIT_replicated;
        end generate MAPPING_IN_UNIT_extra;

        MAPPING_IN_UNIT_replicated_DMR: for h in integer(floor(real(ACCL_NUM - 2)/2.0)) downto 0 generate
            MAPPING_IN_UNIT_DMR_1: DSP_Mapping_IN_Unit_Multicore
            generic map (
                SIMD => SIMD,
                SIMD_Width => SIMD_Width
            )
            port map (
                dsp_instr_req => dsp_instr_req(h),
                dsp_sc_data_read => dsp_sc_data_read(h),
                busy_DSP_internal_lat => busy_DSP_internal_lat(h),
                state_DSP => state_DSP(h),
                decoded_instruction_DSP_lat => decoded_instruction_DSP_lat(h),
                dsp_sc_data_read_mask => dsp_sc_data_read_mask(h),
                vec_read_rs2_DSP => vec_read_rs2_DSP(h),
                MVTYPE_DSP => MVTYPE_DSP(h),
                MPSCLFAC_DSP => MPSCLFAC_DSP(h),
                dotp => dotp(h),
                dotpps => dotpps(h),
                rf_rs2 => rf_rs2(h),
                RS2_Data_IE_lat => RS2_Data_IE_lat(h),
                dsp_out_mul_results => dsp_out_mul_results(h),
                dsp_out_shifter_results => dsp_out_shifter_results(h),
                dsp_out_adder_results => dsp_out_adder_results(h),

                dsp_in_accum_operands => dsp_in_accum_operands_tmp(h*2),
                MSB_stage_1 => MSB_stage_1_tmp(h*2),
                dsp_in_adder_operands => dsp_in_adder_operands_tmp(h*2),
                dsp_in_shift_amount => dsp_in_shift_amount_tmp(h*2),
                dsp_in_shifter_operand => dsp_in_shifter_operand_tmp(h*2),
                dsp_in_cmp_operands => dsp_in_cmp_operands_tmp(h*2),
                dsp_in_mul_operands => dsp_in_mul_operands_tmp(h*2)
            );
            
            MAPPING_IN_UNIT_DMR_2: DSP_Mapping_IN_Unit_Multicore
            generic map (
                SIMD => SIMD,
                SIMD_Width => SIMD_Width
            )
            port map (
                dsp_instr_req => dsp_instr_req(h),
                dsp_sc_data_read => dsp_sc_data_read(h),
                busy_DSP_internal_lat => busy_DSP_internal_lat(h),
                state_DSP => state_DSP(h),
                decoded_instruction_DSP_lat => decoded_instruction_DSP_lat(h),
                dsp_sc_data_read_mask => dsp_sc_data_read_mask(h),
                vec_read_rs2_DSP => vec_read_rs2_DSP(h),
                MVTYPE_DSP => MVTYPE_DSP(h),
                MPSCLFAC_DSP => MPSCLFAC_DSP(h),
                dotp => dotp(h),
                dotpps => dotpps(h),
                rf_rs2 => rf_rs2(h),
                RS2_Data_IE_lat => RS2_Data_IE_lat(h),
                dsp_out_mul_results => dsp_out_mul_results(h),
                dsp_out_shifter_results => dsp_out_shifter_results(h),
                dsp_out_adder_results => dsp_out_adder_results(h),

                dsp_in_accum_operands => dsp_in_accum_operands_tmp(h*2+1),
                MSB_stage_1 => MSB_stage_1_tmp(h*2+1),
                dsp_in_adder_operands => dsp_in_adder_operands_tmp(h*2+1),
                dsp_in_shift_amount => dsp_in_shift_amount_tmp(h*2+1),
                dsp_in_shifter_operand => dsp_in_shifter_operand_tmp(h*2+1),
                dsp_in_cmp_operands => dsp_in_cmp_operands_tmp(h*2+1),
                dsp_in_mul_operands => dsp_in_mul_operands_tmp(h*2+1)
            );

            DMR_dsp_in_accum_operands_2d: for i in 0 to SIMD_Width-1 generate
                DMR_dsp_in_accum_operands_inst: DMR
                port map(
                    in1 => dsp_in_accum_operands_tmp(h*2)(i),
                    in2 => dsp_in_accum_operands_tmp(h*2+1)(i),
                    err_flag => open,
                    result => dsp_in_accum_operands(h)(i)
                );
            end generate DMR_dsp_in_accum_operands_2d;

            DMR_MSB_stage_1_3d: for i in 1 downto 0 generate
                DMR_MSB_stage_1_2d: for j in 4*SIMD-1 downto 0 generate
                    DMR_MSB_stage_1_inst: DMR
                    port map(
                        in1 => MSB_stage_1_tmp(h*2)(i)(j),
                        in2 => MSB_stage_1_tmp(h*2+1)(i)(j),
                        err_flag => open,
                        result => MSB_stage_1(h)(i)(j)
                    );
                end generate DMR_MSB_stage_1_2d;
            end generate DMR_MSB_stage_1_3d;

            DMR_dsp_in_adder_operands_3d: for i in 1 downto 0 generate
                DMR_dsp_in_adder_operands_2d: for j in SIMD_Width-1 downto 0 generate
                    DMR_dsp_in_adder_operands_inst: DMR
                    port map(
                        in1 => dsp_in_adder_operands_tmp(h*2)(i)(j),
                        in2 => dsp_in_adder_operands_tmp(h*2+1)(i)(j),
                        err_flag => open,
                        result => dsp_in_adder_operands(h)(i)(j)
                    );
                end generate DMR_dsp_in_adder_operands_2d;
            end generate DMR_dsp_in_adder_operands_3d;

            DMR_dsp_in_shift_amount_2d: for i in 4 downto 0 generate
                DMR_dsp_in_shift_amount_inst: DMR
                port map(
                    in1 => dsp_in_shift_amount_tmp(h*2)(i),
                    in2 => dsp_in_shift_amount_tmp(h*2+1)(i),
                    err_flag => open,
                    result => dsp_in_shift_amount(h)(i)
                );
            end generate DMR_dsp_in_shift_amount_2d;

            DMR_dsp_in_shifter_operand_2d: for i in SIMD_Width-1 downto 0 generate
                DMR_dsp_in_shifter_operand_inst: DMR
                port map(
                    in1 => dsp_in_shifter_operand_tmp(h*2)(i),
                    in2 => dsp_in_shifter_operand_tmp(h*2+1)(i),
                    err_flag => open,
                    result => dsp_in_shifter_operand(h)(i)
                );
            end generate DMR_dsp_in_shifter_operand_2d;

            DMR_dsp_in_cmp_operands_2d: for i in SIMD_Width-1 downto 0 generate
                DMR_dsp_in_cmp_operands_inst: DMR
                port map(
                    in1 => dsp_in_cmp_operands_tmp(h*2)(i),
                    in2 => dsp_in_cmp_operands_tmp(h*2+1)(i),
                    err_flag => open,
                    result => dsp_in_cmp_operands(h)(i)
                );
            end generate DMR_dsp_in_cmp_operands_2d;

            DMR_dsp_in_mul_operands_3d: for i in 1 downto 0 generate
                DMR_dsp_in_mul_operands_2d: for j in SIMD_Width-1 downto 0 generate
                    DMR_dsp_in_mul_operands_inst: DMR
                    port map(
                        in1 => dsp_in_mul_operands_tmp(h*2)(i)(j),
                        in2 => dsp_in_mul_operands_tmp(h*2+1)(i)(j),
                        err_flag => open,
                        result => dsp_in_mul_operands(h)(i)(j)
                    );
                end generate DMR_dsp_in_mul_operands_2d;
            end generate DMR_dsp_in_mul_operands_3d;
        end generate MAPPING_IN_UNIT_replicated_DMR;
    end generate MAPPING_IN_UNIT_DMR;

    MAPPING_IN_UNIT_TMR: if TMR_ENABLED generate
        MAPPING_IN_UNIT_extra: if ACCL_NUM mod 3 /= 0 generate
            MAPPING_IN_UNIT_replicated: for h in ACCL_NUM - 1 downto ACCL_NUM - (ACCL_NUM mod 3) generate
                MAPPING_IN_UNIT: DSP_Mapping_IN_Unit_Multicore
                    generic map (
                        SIMD => SIMD,
                        SIMD_Width => SIMD_Width
                    )
                    port map (
                        dsp_instr_req => dsp_instr_req(h),
                        dsp_sc_data_read => dsp_sc_data_read(h),
                        busy_DSP_internal_lat => busy_DSP_internal_lat(h),
                        state_DSP => state_DSP(h),
                        decoded_instruction_DSP_lat => decoded_instruction_DSP_lat(h),
                        dsp_sc_data_read_mask => dsp_sc_data_read_mask(h),
                        vec_read_rs2_DSP => vec_read_rs2_DSP(h),
                        MVTYPE_DSP => MVTYPE_DSP(h),
                        MPSCLFAC_DSP => MPSCLFAC_DSP(h),
                        dotp => dotp(h),
                        dotpps => dotpps(h),
                        rf_rs2 => rf_rs2(h),
                        RS2_Data_IE_lat => RS2_Data_IE_lat(h),
                        dsp_out_mul_results => dsp_out_mul_results(h),
                        dsp_out_shifter_results => dsp_out_shifter_results(h),
                        dsp_out_adder_results => dsp_out_adder_results(h),

                        dsp_in_accum_operands => dsp_in_accum_operands_tmp(h),
                        MSB_stage_1 => MSB_stage_1_tmp(h),
                        dsp_in_adder_operands => dsp_in_adder_operands_tmp(h),
                        dsp_in_shift_amount => dsp_in_shift_amount_tmp(h),
                        dsp_in_shifter_operand => dsp_in_shifter_operand_tmp(h),
                        dsp_in_cmp_operands => dsp_in_cmp_operands_tmp(h),
                        dsp_in_mul_operands => dsp_in_mul_operands_tmp(h)
                    );
                -- Assign the temporary signals to the output signals directly
                dsp_in_accum_operands(h) <= dsp_in_accum_operands_tmp(h);
                MSB_stage_1(h) <= MSB_stage_1_tmp(h);
                dsp_in_adder_operands(h) <= dsp_in_adder_operands_tmp(h);
                dsp_in_shift_amount(h) <= dsp_in_shift_amount_tmp(h);
                dsp_in_shifter_operand(h) <= dsp_in_shifter_operand_tmp(h);
                dsp_in_cmp_operands(h) <= dsp_in_cmp_operands_tmp(h);
                dsp_in_mul_operands(h) <= dsp_in_mul_operands_tmp(h);
            end generate MAPPING_IN_UNIT_replicated;
        end generate MAPPING_IN_UNIT_extra;

        MAPPING_IN_UNIT_replicated_TMR: for h in integer(floor(real(ACCL_NUM - 1)/3.0)) downto 0 generate
            MAPPING_IN_UNIT_TMR_1: DSP_Mapping_IN_Unit_Multicore
            generic map (
                SIMD => SIMD,
                SIMD_Width => SIMD_Width
            )
            port map (
                dsp_instr_req => dsp_instr_req(h),
                dsp_sc_data_read => dsp_sc_data_read(h),
                busy_DSP_internal_lat => busy_DSP_internal_lat(h),
                state_DSP => state_DSP(h),
                decoded_instruction_DSP_lat => decoded_instruction_DSP_lat(h),
                dsp_sc_data_read_mask => dsp_sc_data_read_mask(h),
                vec_read_rs2_DSP => vec_read_rs2_DSP(h),
                MVTYPE_DSP => MVTYPE_DSP(h),
                MPSCLFAC_DSP => MPSCLFAC_DSP(h),
                dotp => dotp(h),
                dotpps => dotpps(h),
                rf_rs2 => rf_rs2(h),
                RS2_Data_IE_lat => RS2_Data_IE_lat(h),
                dsp_out_mul_results => dsp_out_mul_results(h),
                dsp_out_shifter_results => dsp_out_shifter_results(h),
                dsp_out_adder_results => dsp_out_adder_results(h),

                dsp_in_accum_operands => dsp_in_accum_operands_tmp(h*3),
                MSB_stage_1 => MSB_stage_1_tmp(h*3),
                dsp_in_adder_operands => dsp_in_adder_operands_tmp(h*3),
                dsp_in_shift_amount => dsp_in_shift_amount_tmp(h*3),
                dsp_in_shifter_operand => dsp_in_shifter_operand_tmp(h*3),
                dsp_in_cmp_operands => dsp_in_cmp_operands_tmp(h*3),
                dsp_in_mul_operands => dsp_in_mul_operands_tmp(h*3)
            );
            
            MAPPING_IN_UNIT_DMR_2: DSP_Mapping_IN_Unit_Multicore
            generic map (
                SIMD => SIMD,
                SIMD_Width => SIMD_Width
            )
            port map (
                dsp_instr_req => dsp_instr_req(h),
                dsp_sc_data_read => dsp_sc_data_read(h),
                busy_DSP_internal_lat => busy_DSP_internal_lat(h),
                state_DSP => state_DSP(h),
                decoded_instruction_DSP_lat => decoded_instruction_DSP_lat(h),
                dsp_sc_data_read_mask => dsp_sc_data_read_mask(h),
                vec_read_rs2_DSP => vec_read_rs2_DSP(h),
                MVTYPE_DSP => MVTYPE_DSP(h),
                MPSCLFAC_DSP => MPSCLFAC_DSP(h),
                dotp => dotp(h),
                dotpps => dotpps(h),
                rf_rs2 => rf_rs2(h),
                RS2_Data_IE_lat => RS2_Data_IE_lat(h),
                dsp_out_mul_results => dsp_out_mul_results(h),
                dsp_out_shifter_results => dsp_out_shifter_results(h),
                dsp_out_adder_results => dsp_out_adder_results(h),

                dsp_in_accum_operands => dsp_in_accum_operands_tmp(h*3+1),
                MSB_stage_1 => MSB_stage_1_tmp(h*3+1),
                dsp_in_adder_operands => dsp_in_adder_operands_tmp(h*3+1),
                dsp_in_shift_amount => dsp_in_shift_amount_tmp(h*3+1),
                dsp_in_shifter_operand => dsp_in_shifter_operand_tmp(h*3+1),
                dsp_in_cmp_operands => dsp_in_cmp_operands_tmp(h*3+1),
                dsp_in_mul_operands => dsp_in_mul_operands_tmp(h*3+1)
            );

            MAPPING_IN_UNIT_DMR_3: DSP_Mapping_IN_Unit_Multicore
            generic map (
                SIMD => SIMD,
                SIMD_Width => SIMD_Width
            )
            port map (
                dsp_instr_req => dsp_instr_req(h),
                dsp_sc_data_read => dsp_sc_data_read(h),
                busy_DSP_internal_lat => busy_DSP_internal_lat(h),
                state_DSP => state_DSP(h),
                decoded_instruction_DSP_lat => decoded_instruction_DSP_lat(h),
                dsp_sc_data_read_mask => dsp_sc_data_read_mask(h),
                vec_read_rs2_DSP => vec_read_rs2_DSP(h),
                MVTYPE_DSP => MVTYPE_DSP(h),
                MPSCLFAC_DSP => MPSCLFAC_DSP(h),
                dotp => dotp(h),
                dotpps => dotpps(h),
                rf_rs2 => rf_rs2(h),
                RS2_Data_IE_lat => RS2_Data_IE_lat(h),
                dsp_out_mul_results => dsp_out_mul_results(h),
                dsp_out_shifter_results => dsp_out_shifter_results(h),
                dsp_out_adder_results => dsp_out_adder_results(h),

                dsp_in_accum_operands => dsp_in_accum_operands_tmp(h*3+2),
                MSB_stage_1 => MSB_stage_1_tmp(h*3+2),
                dsp_in_adder_operands => dsp_in_adder_operands_tmp(h*3+2),
                dsp_in_shift_amount => dsp_in_shift_amount_tmp(h*3+2),
                dsp_in_shifter_operand => dsp_in_shifter_operand_tmp(h*3+2),
                dsp_in_cmp_operands => dsp_in_cmp_operands_tmp(h*3+2),
                dsp_in_mul_operands => dsp_in_mul_operands_tmp(h*3+2)
            );

            TMR_dsp_in_accum_operands_2d: for i in 0 to SIMD_Width-1 generate
                TMR_dsp_in_accum_operands_inst: TMR
                port map(
                    in1 => dsp_in_accum_operands_tmp(h*3)(i),
                    in2 => dsp_in_accum_operands_tmp(h*3+1)(i),
                    in3 => dsp_in_accum_operands_tmp(h*3+2)(i),
                    result => dsp_in_accum_operands(h)(i)
                );
            end generate TMR_dsp_in_accum_operands_2d;

            TMR_MSB_stage_1_3d: for i in 1 downto 0 generate
                TMR_MSB_stage_1_2d: for j in 4*SIMD-1 downto 0 generate 
                    TMR_MSB_stage_1_inst: TMR
                    port map(
                        in1 => MSB_stage_1_tmp(h*3)(i)(j),
                        in2 => MSB_stage_1_tmp(h*3+1)(i)(j),
                        in3 => MSB_stage_1_tmp(h*3+2)(i)(j),
                        result => MSB_stage_1(h)(i)(j)
                    );
                end generate TMR_MSB_stage_1_2d;
            end generate TMR_MSB_stage_1_3d;

            TMR_dsp_in_adder_operands_3d: for i in 1 downto 0 generate
                TMR_dsp_in_adder_operands_2d: for j in SIMD_Width-1 downto 0 generate
                    TMR_dsp_in_adder_operands_inst: TMR
                    port map(
                        in1 => dsp_in_adder_operands_tmp(h*3)(i)(j),
                        in2 => dsp_in_adder_operands_tmp(h*3+1)(i)(j),
                        in3 => dsp_in_adder_operands_tmp(h*3+2)(i)(j),
                        result => dsp_in_adder_operands(h)(i)(j)
                    );
                end generate TMR_dsp_in_adder_operands_2d;
            end generate TMR_dsp_in_adder_operands_3d;

            TMR_dsp_in_shift_amount_2d: for i in 4 downto 0 generate
                TMR_dsp_in_shift_amount_inst: TMR
                port map(
                    in1 => dsp_in_shift_amount_tmp(h*3)(i),
                    in2 => dsp_in_shift_amount_tmp(h*3+1)(i),
                    in3 => dsp_in_shift_amount_tmp(h*3+2)(i),
                    result => dsp_in_shift_amount(h)(i)
                );
            end generate TMR_dsp_in_shift_amount_2d;

            TMR_dsp_in_shifter_operand_2d: for i in SIMD_Width-1 downto 0 generate
                TMR_dsp_in_shifter_operand_inst: TMR
                port map(
                    in1 => dsp_in_shifter_operand_tmp(h*3)(i),
                    in2 => dsp_in_shifter_operand_tmp(h*3+1)(i),
                    in3 => dsp_in_shifter_operand_tmp(h*3+2)(i),
                    result => dsp_in_shifter_operand(h)(i)
                );
            end generate TMR_dsp_in_shifter_operand_2d;

            TMR_dsp_in_cmp_operands_2d: for i in SIMD_Width-1 downto 0 generate
                TMR_dsp_in_cmp_operands_inst: TMR
                port map(
                    in1 => dsp_in_cmp_operands_tmp(h*3)(i),
                    in2 => dsp_in_cmp_operands_tmp(h*3+1)(i),
                    in3 => dsp_in_cmp_operands_tmp(h*3+2)(i),
                    result => dsp_in_cmp_operands(h)(i)
                );
            end generate TMR_dsp_in_cmp_operands_2d;

            TMR_dsp_in_mul_operands_3d: for i in 1 downto 0 generate
                TMR_dsp_in_mul_operands_2d: for j in SIMD_Width-1 downto 0 generate
                    TMR_dsp_in_mul_operands_inst: TMR
                    port map(
                        in1 => dsp_in_mul_operands_tmp(h*3)(i)(j),
                        in2 => dsp_in_mul_operands_tmp(h*3+1)(i)(j),
                        in3 => dsp_in_mul_operands_tmp(h*3+2)(i)(j),
                        result => dsp_in_mul_operands(h)(i)(j)
                    );
                end generate TMR_dsp_in_mul_operands_2d;
            end generate TMR_dsp_in_mul_operands_3d;

        end generate MAPPING_IN_UNIT_replicated_TMR;
    end generate MAPPING_IN_UNIT_TMR;


    MAPPING_IN_UNIT_no_redundancy: if (not DMR_ENABLED) and (not TMR_ENABLED) generate
        MAPPING_IN_UNIT_replicated: for h in accl_range generate
            MAPPING_IN_UNIT: DSP_Mapping_IN_Unit_Multicore
                generic map (
                    SIMD => SIMD,
                    SIMD_Width => SIMD_Width
                )
                port map (
                    dsp_instr_req => dsp_instr_req(h),
                    dsp_sc_data_read => dsp_sc_data_read(h),
                    busy_DSP_internal_lat => busy_DSP_internal_lat(h),
                    state_DSP => state_DSP(h),
                    decoded_instruction_DSP_lat => decoded_instruction_DSP_lat(h),
                    dsp_sc_data_read_mask => dsp_sc_data_read_mask(h),
                    vec_read_rs2_DSP => vec_read_rs2_DSP(h),
                    MVTYPE_DSP => MVTYPE_DSP(h),
                    MPSCLFAC_DSP => MPSCLFAC_DSP(h),
                    dotp => dotp(h),
                    dotpps => dotpps(h),
                    rf_rs2 => rf_rs2(h),
                    RS2_Data_IE_lat => RS2_Data_IE_lat(h),
                    dsp_out_mul_results => dsp_out_mul_results(h),
                    dsp_out_shifter_results => dsp_out_shifter_results(h),
                    dsp_out_adder_results => dsp_out_adder_results(h),

                    dsp_in_accum_operands => dsp_in_accum_operands_tmp(h),
                    MSB_stage_1 => MSB_stage_1_tmp(h),
                    dsp_in_adder_operands => dsp_in_adder_operands_tmp(h),
                    dsp_in_shift_amount => dsp_in_shift_amount_tmp(h),
                    dsp_in_shifter_operand => dsp_in_shifter_operand_tmp(h),
                    dsp_in_cmp_operands => dsp_in_cmp_operands_tmp(h),
                    dsp_in_mul_operands => dsp_in_mul_operands_tmp(h)
                );
        end generate MAPPING_IN_UNIT_replicated;

        -- Assign the temporary signals to the output signals directly
        dsp_in_accum_operands <= dsp_in_accum_operands_tmp;
        MSB_stage_1 <= MSB_stage_1_tmp;
        dsp_in_adder_operands <= dsp_in_adder_operands_tmp;
        dsp_in_shift_amount <= dsp_in_shift_amount_tmp;
        dsp_in_shifter_operand <= dsp_in_shifter_operand_tmp;
        dsp_in_cmp_operands <= dsp_in_cmp_operands_tmp;
        dsp_in_mul_operands <= dsp_in_mul_operands_tmp;
    end generate MAPPING_IN_UNIT_no_redundancy;
end generate MAPPING_MULTICORE;

MAPPING_MULTITHREAD: if multithreaded_accl_en = 1 generate
    MAPPING_OUT_UNIT_replicated: for h in accl_range generate
        MAPPING_OUT_UNIT: DSP_Mapping_Multithread_Out_Mapper
            generic map (
                SIMD => SIMD,
                Data_Width => Data_Width,
                SIMD_Width => SIMD_Width
            )
            port map (
                MVTYPE => MVTYPE(h),
                dsp_instr_req => dsp_instr_req(h),
                decoded_instruction_DSP => decoded_instruction_DSP,
                dsp_out_accum_results => dsp_out_accum_results(0),
                busy_DSP_internal_lat => busy_DSP_internal_lat(h),
                state_DSP => state_DSP(h),
                halt_dsp_lat => halt_dsp_lat(h),
                decoded_instruction_DSP_lat => decoded_instruction_DSP_lat(h),
                MVTYPE_DSP => MVTYPE_DSP(h),
                RS1_Data_IE_lat => RS1_Data_IE_lat(h),
                dsp_sc_data_write_int => dsp_sc_data_write_int(h),
                halt_dsp => halt_dsp(h),
                dsp_out_mul_results => dsp_out_mul_results(0),
                dsp_out_shifter_results => dsp_out_shifter_results(0),
                dsp_out_adder_results => dsp_out_adder_results(0),
                dsp_out_cmp_results => dsp_out_cmp_results(0),

                dsp_sc_data_write_wire_int => dsp_sc_data_write_wire_int(h),
                SIMD_RD_BYTES_wire => SIMD_RD_BYTES_wire(h),
                dsp_sc_data_write_wire => dsp_sc_data_write_wire(h)
            );
        end generate MAPPING_OUT_UNIT_replicated;

        MAPPING_IN_UNIT_replicated: for h in accl_range generate
        MAPPING_IN_UNIT: DSP_Mapping_IN_Unit_Multithread
            generic map (
                SIMD => SIMD,
                SIMD_Width => SIMD_Width
            )
            port map (
                dsp_instr_req => dsp_instr_req(h),
                dsp_sc_data_read => dsp_sc_data_read(h),
                busy_DSP_internal_lat => busy_DSP_internal_lat(h),
                state_DSP => state_DSP(h),
                decoded_instruction_DSP_lat => decoded_instruction_DSP_lat(h),
                dsp_sc_data_read_mask => dsp_sc_data_read_mask(h),
                vec_read_rs2_DSP => vec_read_rs2_DSP(h),
                MVTYPE_DSP => MVTYPE_DSP(h),
                MPSCLFAC_DSP => MPSCLFAC_DSP(h),
                dotp => dotp(h),
                dotpps => dotpps(h),
                rf_rs2 => rf_rs2(h),
                RS2_Data_IE_lat => RS2_Data_IE_lat(h),
                dsp_out_mul_results => dsp_out_mul_results(0),
                dsp_out_shifter_results => dsp_out_shifter_results(0),
                dsp_out_adder_results => dsp_out_adder_results(0),

                dsp_in_accum_operands => dsp_in_accum_operands(0),
                MSB_stage_1 => MSB_stage_1(0),
                dsp_in_adder_operands => dsp_in_adder_operands(0),
                dsp_in_shift_amount => dsp_in_shift_amount(0),
                dsp_in_shifter_operand => dsp_in_shifter_operand(0),
                dsp_in_cmp_operands => dsp_in_cmp_operands(0),
                dsp_in_mul_operands => dsp_in_mul_operands(0)
            );
    end generate MAPPING_IN_UNIT_replicated;
    end generate MAPPING_MULTITHREAD;

end architecture DSP_Mapping_arch;