-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity RTL_DSP_TOP is
  generic(
    THREAD_POOL_SIZE      : integer;
    accl_en               : natural;
    replicate_accl_en     : natural;
    multithreaded_accl_en : natural;
    SPM_NUM               : natural; 
    Addr_Width            : natural;
    SIMD                  : natural;
    --------------------------------
    ACCL_NUM              : natural;
    FU_NUM                : natural;
    TPS_CEIL              : natural;
    TPS_BUF_CEIL          : natural;
    SPM_ADDR_WID          : natural;
    SIMD_BITS             : natural;
    Data_Width            : natural;
    SIMD_Width            : natural
  );
  port (
    -- Core Signals
    clk_i, rst_ni              : in std_logic;
    -- Processing Pipeline Signals
    rs1_to_sc                  : in  std_logic_vector(SPM_ADDR_WID-1 downto 0);
    rs2_to_sc                  : in  std_logic_vector(SPM_ADDR_WID-1 downto 0);
    rd_to_sc                   : in  std_logic_vector(SPM_ADDR_WID-1 downto 0);
  -- CSR Signals
    MVSIZE                     : in  array_2d(THREAD_POOL_SIZE-1 downto 0)(Addr_Width downto 0);
    MVTYPE                     : in  array_2d(THREAD_POOL_SIZE-1 downto 0)(3 downto 0);
    MPSCLFAC                   : in  array_2d(THREAD_POOL_SIZE-1 downto 0)(4 downto 0);
    dsp_except_data            : out array_2d(ACCL_NUM-1 downto 0)(31 downto 0);
  -- Program Counter Signals
    dsp_taken_branch           : out std_logic_vector(ACCL_NUM-1 downto 0);
    dsp_except_condition       : out std_logic_vector(ACCL_NUM-1 downto 0);
    -- ID_Stage Signals
    decoded_instruction_DSP    : in  std_logic_vector(DSP_UNIT_INSTR_SET_SIZE-1 downto 0);
    harc_EXEC                  : in  integer range THREAD_POOL_SIZE-1 downto 0;
    pc_IE                      : in  std_logic_vector(31 downto 0);
    RS1_Data_IE                : in  std_logic_vector(31 downto 0);
    RS2_Data_IE                : in  std_logic_vector(31 downto 0);
    RD_Data_IE                 : in  std_logic_vector(Addr_Width -1 downto 0);
    dsp_instr_req              : in  std_logic_vector(ACCL_NUM-1 downto 0);
    spm_rs1                    : in  std_logic;
    spm_rs2                    : in  std_logic;
    vec_read_rs1_ID            : in  std_logic;
    vec_read_rs2_ID            : in  std_logic;
    vec_write_rd_ID            : in  std_logic;
    busy_dsp                   : out std_logic_vector(ACCL_NUM-1 downto 0);
  -- Scratchpad Interface Signals
    dsp_data_gnt_i             : in  std_logic_vector(ACCL_NUM-1 downto 0);
    dsp_sci_wr_gnt             : in  std_logic_vector(ACCL_NUM-1 downto 0);
    dsp_sc_data_read           : in  array_3d(ACCL_NUM-1 downto 0)(1 downto 0)(SIMD_Width-1 downto 0);
    dsp_we_word                : out array_2d(ACCL_NUM-1 downto 0)(SIMD-1 downto 0);
    dsp_sc_read_addr           : out array_3d(ACCL_NUM-1 downto 0)(1 downto 0)(Addr_Width-1 downto 0);
    dsp_to_sc                  : out array_3d(ACCL_NUM-1 downto 0)(SPM_NUM-1 downto 0)(1 downto 0);
    dsp_sc_data_write_wire     : out array_2d(ACCL_NUM-1 downto 0)(SIMD_Width-1 downto 0);
    dsp_sc_write_addr          : out array_2d(ACCL_NUM-1 downto 0)(Addr_Width-1 downto 0);
    dsp_sci_we                 : out array_2d(ACCL_NUM-1 downto 0)(SPM_NUM-1 downto 0);
    dsp_sci_req                : out array_2d(ACCL_NUM-1 downto 0)(SPM_NUM-1 downto 0);
    -- tracer signals
    state_DSP                  : out array_2d(ACCL_NUM-1 downto 0)(1 downto 0)
  );
end entity;

architecture RTL_DSP_TOP_arch of RTL_DSP_TOP is
  subtype harc_range is integer range THREAD_POOL_SIZE - 1 downto 0;
  subtype accl_range is integer range ACCL_NUM - 1 downto 0;
  subtype fu_range   is integer range FU_NUM - 1 downto 0;


  signal nextstate_DSP : array_2d(accl_range)(1 downto 0);

  -- Virtual Parallelism Signals
  signal cmp_en                          : std_logic_vector(accl_range);  -- enables the use of the shifters
  signal shift_en                        : std_logic_vector(accl_range);  -- enables the use of the shifters
  signal add_en                          : std_logic_vector(accl_range);  -- enables the use of the adders
  signal mul_en                          : std_logic_vector(accl_range);  -- enables the use of the multipliers
  signal accum_en                        : std_logic_vector(accl_range);  -- enables the use of the accumulator
  signal halt_hart                       : std_logic_vector(accl_range); -- halts the thread when the requested functional unit is in use
  
  -- Functional Unit Ports ---
  --signal dsp_in_sign_bits               : array_2d(accl_range)(4*SIMD-1 downto 0);               -- vivado unsynthesizable, but more efficient alternative
  signal dsp_in_shifter_operand          : array_2d(fu_range)(SIMD_Width-1 downto 0);
  signal dsp_out_shifter_results         : array_2d(fu_range)(SIMD_Width-1 downto 0);
  signal dsp_in_cmp_operands             : array_2d(fu_range)(SIMD_Width-1 downto 0);
  signal dsp_in_mul_operands             : array_3d(fu_range)(1 downto 0)(SIMD_Width-1 downto 0);
  signal dsp_out_mul_results             : array_2d(fu_range)(SIMD_Width-1 downto 0);
  signal dsp_out_cmp_results             : array_2d(fu_range)(SIMD_Width-1 downto 0);
  signal dsp_in_accum_operands           : array_2d(fu_range)(SIMD_Width-1 downto 0);
  signal dsp_out_accum_results           : array_2d(fu_range)(31 downto 0);
  signal dsp_in_adder_operands           : array_3d(fu_range)(1 downto 0)(SIMD_Width-1 downto 0);
  signal dsp_out_adder_results           : array_2d(fu_range)(SIMD_Width-1 downto 0);

  signal carry_pass                      : array_2d(accl_range)(2 downto 0);  -- carry enable signal, depending on it's configuration, we can do KADDV8, KADDV16, KADDV32
  signal FUNCT_SELECT_MASK               : array_2d(accl_range)(31 downto 0); -- when the mask is set to "FFFFFFFF" we enable KDOTP32 execution using the 16-bit muls
  signal twos_complement                 : array_2d(accl_range)(31 downto 0);
  signal dsp_in_shift_amount             : array_2d(accl_range)(4 downto 0);

  signal dsp_sc_data_write_wire_int      : array_2d(accl_range)(SIMD_Width-1 downto 0);
  signal dsp_sc_data_write_int           : array_2d(accl_range)(SIMD_Width-1 downto 0);

  signal MVTYPE_DSP                      : array_2d(accl_range)(1 downto 0);
  signal vec_write_rd_DSP                : std_logic_vector(accl_range);  -- Indicates whether the result being written is a vector or a scalar
  signal vec_read_rs1_DSP                : std_logic_vector(accl_range);  -- Indicates whether the operand being read is a vector or a scalar
  signal vec_read_rs2_DSP                : std_logic_vector(accl_range);  -- Indicates whether the operand being read is a vector or a scalar
  signal dotp                            : std_logic_vector(accl_range);  -- indicator used in the pipeline handler to switch functional units
  signal dotpps                          : std_logic_vector(accl_range);  -- indicator used in the pipeline handler to switch functional units
  signal slt                             : std_logic_vector(accl_range);  -- indicator used in the pipeline handler to switch functional units
  signal wb_ready                        : std_logic_vector(accl_range);
  signal halt_dsp                        : std_logic_vector(accl_range);
  signal halt_dsp_lat                    : std_logic_vector(accl_range);
  signal recover_state                   : std_logic_vector(accl_range);
  signal recover_state_wires             : std_logic_vector(accl_range);
  signal dsp_data_gnt_i_lat              : std_logic_vector(accl_range);
  signal shifter_stage_1_en              : std_logic_vector(accl_range);
  signal shifter_stage_2_en              : std_logic_vector(accl_range);
  signal shifter_stage_3_en              : std_logic_vector(accl_range);
  signal adder_stage_1_en                : std_logic_vector(accl_range);
  signal adder_stage_2_en                : std_logic_vector(accl_range);
  signal adder_stage_3_en                : std_logic_vector(accl_range);
  signal mul_stage_1_en                  : std_logic_vector(accl_range);
  signal mul_stage_2_en                  : std_logic_vector(accl_range);
  signal mul_stage_3_en                  : std_logic_vector(accl_range);
  signal cmp_stage_1_en                  : std_logic_vector(accl_range);
  signal cmp_stage_2_en                  : std_logic_vector(accl_range);
  signal accum_stage_1_en                : std_logic_vector(accl_range);
  signal accum_stage_2_en                : std_logic_vector(accl_range);
  signal accum_stage_3_en                : std_logic_vector(accl_range);
  signal dsp_except_data_wire            : array_2d(accl_range)(31 downto 0);
  signal MSB_stage_1                     : array_3d(accl_range)(1 downto 0)(4*SIMD-1 downto 0);
  signal MSB_stage_2                     : array_3d(accl_range)(1 downto 0)(4*SIMD-1 downto 0);
  
  signal decoded_instruction_DSP_lat     : array_2d(accl_range)(DSP_UNIT_INSTR_SET_SIZE -1 downto 0);
  signal dsp_rs1_to_sc                   : array_2d(accl_range)(SPM_ADDR_WID-1 downto 0);
  signal dsp_rs2_to_sc                   : array_2d(accl_range)(SPM_ADDR_WID-1 downto 0);
  signal dsp_rd_to_sc                    : array_2d(accl_range)(SPM_ADDR_WID-1 downto 0);
  signal dsp_sc_data_read_mask           : array_2d(accl_range)(SIMD_Width-1 downto 0);
  signal RS1_Data_IE_lat                 : array_2d(accl_range)(31 downto 0);
  signal RS2_Data_IE_lat                 : array_2d(accl_range)(31 downto 0);
  signal RD_Data_IE_lat                  : array_2d(accl_range)(Addr_Width -1 downto 0);
  signal MVSIZE_READ                     : array_2d(accl_range)(Addr_Width downto 0);  -- Bytes remaining to read
  signal MVSIZE_WRITE                    : array_2d(accl_range)(Addr_Width downto 0);  -- Bytes remaining to write
  signal MPSCLFAC_DSP                    : array_2d(accl_range)(4 downto 0);
  signal busy_dsp_internal               : std_logic_vector(accl_range);
  signal busy_DSP_internal_lat           : std_logic_vector(accl_range);
  signal rf_rs2                          : std_logic_vector(accl_range);
  signal relu_instr                      : std_logic_vector(accl_range);
  signal SIMD_RD_BYTES_wire              : array_2d_int(accl_range);
  signal SIMD_RD_BYTES                   : array_2d_int(accl_range);


  component ACCUMULATOR
    generic(
      multithreaded_accl_en             : natural;
      SIMD                              : natural;
      ---------------------------------------------------------
      ACCL_NUM                          : natural;
      FU_NUM                            : natural;
      Data_Width                        : natural;
      SIMD_Width                        : natural
    );
  port(
      clk_i                             : in  std_logic;
      rst_ni                            : in  std_logic;
      MVTYPE_DSP                        : in  array_2d(accl_range)(1 downto 0);
      accum_stage_1_en                  : in  std_logic_vector(accl_range);
      accum_stage_2_en                  : in  std_logic_vector(accl_range);
      recover_state_wires               : in  std_logic_vector(accl_range);
      halt_dsp_lat                      : in  std_logic_vector(accl_range);
      state_DSP                         : in  array_2d(accl_range)(1 downto 0);
      decoded_instruction_DSP_lat       : in  array_2d(accl_range)(DSP_UNIT_INSTR_SET_SIZE -1 downto 0);
      dsp_in_accum_operands             : in  array_2d(fu_range)(SIMD_Width-1 downto 0);
      dsp_out_accum_results             : out array_2d(fu_range)(31 downto 0)
  );
  end component;

  component DSP_Exec_Unit is
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
  end component DSP_Exec_Unit;

  component DSP_Excpt_Cntrl_unit is
    generic(
      THREAD_POOL_SIZE      : integer;
      Addr_Width            : natural;
      SPM_NUM               : natural;
      SIMD                  : natural;
      -----------------------------------
      SPM_ADDR_WID          : natural;
      SIMD_BITS             : natural
    );
    port(
      -- INPUTS
      RD_Data_IE_lat                  : in std_logic_vector(Addr_Width -1 downto 0);
      MVSIZE_WRITE                    : in std_logic_vector(Addr_Width downto 0);  -- Bytes remaining to write
      vec_read_rs2_DSP                : in std_logic;  -- Indicates whether the operand being read is a vector or a scalar
      vec_write_rd_DSP                : in std_logic;  -- Indicates whether the result being written is a vector or a scalar
      recover_state                   : in std_logic;
      dsp_rs1_to_sc                   : in std_logic_vector(SPM_ADDR_WID-1 downto 0);
      dsp_rs2_to_sc                   : in std_logic_vector(SPM_ADDR_WID-1 downto 0);
      dsp_rd_to_sc                    : in std_logic_vector(SPM_ADDR_WID-1 downto 0);
      RS1_Data_IE_lat                 : in std_logic_vector(31 downto 0);
      RS2_Data_IE_lat                 : in std_logic_vector(31 downto 0);
      MVSIZE_READ                     : in std_logic_vector(Addr_Width downto 0);  -- Bytes remaining to read
      accum_stage_3_en                : in std_logic;
      dsp_sci_wr_gnt                  : in std_logic;
      mul_stage_3_en                  : in std_logic;
      adder_stage_3_en                : in std_logic;
      dsp_except_data                 : in std_logic_vector(31 downto 0);
      busy_DSP_internal_lat           : in std_logic;
      state_DSP                       : in std_logic_vector(1 downto 0); -- tracer signals
      SIMD_RD_BYTES                   : in integer;
      rf_rs2                          : in std_logic;
      decoded_instruction_DSP_lat     : in std_logic_vector(DSP_UNIT_INSTR_SET_SIZE -1 downto 0);
      cmp_stage_2_en                  : in std_logic;
      shifter_stage_3_en              : in std_logic;
      rs1_to_sc                       : in std_logic_vector(SPM_ADDR_WID-1 downto 0);
      rs2_to_sc                       : in std_logic_vector(SPM_ADDR_WID-1 downto 0);
      rd_to_sc                        : in std_logic_vector(SPM_ADDR_WID-1 downto 0);
      MVSIZE                          : in array_2d(THREAD_POOL_SIZE-1 downto 0)(Addr_Width downto 0);
      MVTYPE                          : in array_2d(THREAD_POOL_SIZE-1 downto 0)(3 downto 0);
      harc_EXEC                       : in integer range THREAD_POOL_SIZE-1 downto 0;
      RS1_Data_IE                     : in std_logic_vector(31 downto 0);
      RS2_Data_IE                     : in std_logic_vector(31 downto 0);
      RD_Data_IE                      : in std_logic_vector(Addr_Width -1 downto 0);
      spm_rs1                         : in std_logic;
      spm_rs2                         : in std_logic;
      vec_read_rs1_ID                 : in std_logic;
      vec_read_rs2_ID                 : in std_logic;
      vec_write_rd_ID                 : in std_logic;
      dsp_instr_req                   : in std_logic;
      halt_hart                       : in std_logic; -- halts the thread when the requested functional unit is in use
  
      -- output signals
      nextstate_DSP                   : out std_logic_vector(1 downto 0);
      busy_dsp_internal               : out std_logic;
      wb_ready                        : out std_logic;
      dsp_sci_we                      : out std_logic_vector(SPM_NUM-1 downto 0);
      dsp_sc_write_addr               : out std_logic_vector(Addr_Width-1 downto 0);
      dsp_sc_read_addr                : out array_2d(1 downto 0)(Addr_Width-1 downto 0);
      dsp_sci_req                     : out std_logic_vector(SPM_NUM-1 downto 0);
      dsp_to_sc                       : out array_2d(SPM_NUM-1 downto 0)(1 downto 0);
      halt_dsp                        : out std_logic;
      recover_state_wires             : out std_logic;
      dsp_except_data_wire            : out std_logic_vector(31 downto 0);
      dsp_except_condition            : out std_logic;
      dsp_we_word                     : out std_logic_vector(SIMD-1 downto 0);
      dsp_taken_branch                : out std_logic    
    );
  end component DSP_Excpt_Cntrl_unit;

  component DSP_pipeline_controller is
    port(
      -- Core Signals
      clk_i, rst_ni                   : in std_logic;
      -- Scratchpad Interface Signals
      dsp_data_gnt_i                  : in  std_logic;
      -- input from DSP_Exec_Unit
      nextstate_DSP                   : in std_logic_vector(1 downto 0);
      dotp                            : in std_logic;  -- indicator used in the pipeline handler to switch functional units
      dotpps                          : in std_logic;  -- indicator used in the pipeline handler to switch functional units
      slt                             : in std_logic;  -- indicator used in the pipeline handler to switch functional units
      -- input from mapping
      SIMD_RD_BYTES_wire              : in integer;
      --input from DSP_Excpt_Cntrl_Unit
      dsp_except_data_wire            : in std_logic_vector(31 downto 0);
      halt_dsp                        : in std_logic;
      busy_DSP_internal               : in std_logic;
      -- input from DSP_FU_Enabler_synchronizer
      cmp_en                          : in std_logic;  -- enables the use of the shifters
      shift_en                        : in std_logic;  -- enables the use of the shifters
      add_en                          : in std_logic;  -- enables the use of the adders
      mul_en                          : in std_logic;  -- enables the use of the multipliers
      accum_en                        : in std_logic;  -- enables the use of the accumulator

      --OUTPUTS
      dsp_data_gnt_i_lat              : out std_logic;
      adder_stage_1_en                : out std_logic;
      adder_stage_2_en                : out std_logic;
      adder_stage_3_en                : out std_logic;
      shifter_stage_1_en              : out std_logic;
      shifter_stage_2_en              : out std_logic;
      shifter_stage_3_en              : out std_logic;
      mul_stage_1_en                  : out std_logic;
      mul_stage_2_en                  : out std_logic;
      mul_stage_3_en                  : out std_logic;
      cmp_stage_1_en                  : out std_logic;
      cmp_stage_2_en                  : out std_logic;
      accum_stage_1_en                : out std_logic;
      accum_stage_2_en                : out std_logic;
      accum_stage_3_en                : out std_logic;
      halt_dsp_lat                    : out std_logic;
      busy_DSP_internal_lat           : out std_logic;
      SIMD_RD_BYTES                   : out integer;
      -- CSR Signals
      dsp_except_data                 : out std_logic_vector(31 downto 0);
      -- tracer signals
      state_DSP                       : out std_logic_vector(1 downto 0)
    );
  end component DSP_pipeline_controller;

  component DSP_FU_Handler is
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
  end component DSP_FU_Handler;

  component DSP_Mapping is
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
        MVTYPE                          : in  array_2d(THREAD_POOL_SIZE-1 downto 0)(3 downto 0);
        -- Scratchpad Interface Signals
        dsp_sc_data_read                : in  array_3d(ACCL_NUM-1 downto 0)(1 downto 0)(SIMD_Width-1 downto 0);
        -- ID_Stage Signals
        dsp_instr_req                   : in  std_logic_vector(ACCL_NUM-1 downto 0);
        decoded_instruction_DSP         : in  std_logic_vector(DSP_UNIT_INSTR_SET_SIZE-1 downto 0);
        -- input from ACCUMULATOR
        dsp_out_accum_results           : in array_2d(FU_NUM-1 downto 0)(31 downto 0);
        -- input from DSP_pipeline_controller
        busy_DSP_internal_lat           : in std_logic_vector(ACCL_NUM-1 downto 0);
        SIMD_RD_BYTES                   : in array_2d_int(ACCL_NUM-1 downto 0);
        state_DSP                       : in array_2d(ACCL_NUM-1 downto 0)(1 downto 0);
        halt_dsp_lat                    : in std_logic_vector(ACCL_NUM-1 downto 0);
        -- input from DSP_Exec_Unit
        decoded_instruction_DSP_lat     : in array_2d(ACCL_NUM-1 downto 0)(DSP_UNIT_INSTR_SET_SIZE -1 downto 0);
        MVTYPE_DSP                      : in array_2d(ACCL_NUM-1 downto 0)(1 downto 0);
        RS1_Data_IE_lat                 : in array_2d(ACCL_NUM-1 downto 0)(31 downto 0);
        dsp_sc_data_write_int           : in array_2d(ACCL_NUM-1 downto 0)(SIMD_Width-1 downto 0);
        dsp_sc_data_read_mask           : in array_2d(ACCL_NUM-1 downto 0)(SIMD_Width-1 downto 0);
        vec_read_rs2_DSP                : in std_logic_vector(ACCL_NUM-1 downto 0);  -- Indicates whether the operand being read is a vector or a scalar
        MPSCLFAC_DSP                    : in array_2d(ACCL_NUM-1 downto 0)(4 downto 0);
        dotp                            : in std_logic_vector(ACCL_NUM-1 downto 0);  -- indicator used in the pipeline handler to switch functional units
        dotpps                          : in std_logic_vector(ACCL_NUM-1 downto 0);  -- indicator used in the pipeline handler to switch functional units
        rf_rs2                          : in std_logic_vector(ACCL_NUM-1 downto 0);  -- Indicates whether the operand being read is a vector or a scalar
        RS2_Data_IE_lat                 : in array_2d(ACCL_NUM-1 downto 0)(31 downto 0);
        -- input from DSP_Excpt_Unit
        halt_dsp                        : in std_logic_vector(ACCL_NUM-1 downto 0);
        -- input from multiplier stage 2
        dsp_out_mul_results             : in array_2d(FU_NUM-1 downto 0)(SIMD_Width-1 downto 0);
        -- input from shifter stage 2
        dsp_out_shifter_results         : in array_2d(FU_NUM-1 downto 0)(SIMD_Width-1 downto 0);
        -- input from adder stage 2
        dsp_out_adder_results           : in array_2d(FU_NUM-1 downto 0)(SIMD_Width-1 downto 0);
        -- input from comparators
        dsp_out_cmp_results             : in array_2d(FU_NUM-1 downto 0)(SIMD_Width-1 downto 0);

        -- output for DSP_Exec_Unit
        dsp_sc_data_write_wire_int      : out array_2d(ACCL_NUM-1 downto 0)(SIMD_Width-1 downto 0);
        SIMD_RD_BYTES_wire              : out array_2d_int(ACCL_NUM-1 downto 0);
        -- Scratchpad Interface Signals
        dsp_sc_data_write_wire          : out array_2d(ACCL_NUM-1 downto 0)(SIMD_Width-1 downto 0);
        -- output for ACCUMULATOR
        dsp_in_accum_operands           : out array_2d(FU_NUM-1 downto 0)(SIMD_Width-1 downto 0);
        -- output for adder 
        MSB_stage_1                     : out array_3d(ACCL_NUM-1 downto 0)(1 downto 0)(4*SIMD-1 downto 0);
        dsp_in_adder_operands           : out array_3d(FU_NUM-1 downto 0)(1 downto 0)(SIMD_Width-1 downto 0);
        -- output for shifter
        dsp_in_shift_amount             : out array_2d(ACCL_NUM-1 downto 0)(4 downto 0);
        dsp_in_shifter_operand          : out array_2d(FU_NUM-1 downto 0)(SIMD_Width-1 downto 0);
        -- output for comparator
        dsp_in_cmp_operands             : out array_2d(FU_NUM-1 downto 0)(SIMD_Width-1 downto 0);
        -- output for multiplier stage 1
        dsp_in_mul_operands             : out array_3d(FU_NUM-1 downto 0)(1 downto 0)(SIMD_Width-1 downto 0)
    );
  end component DSP_Mapping;

  component DSP_Adders is
  generic (
    multithreaded_accl_en : natural;
    SIMD                  : natural;  
    --------------------------------
    ACCL_NUM              : natural;
    FU_NUM                : natural;
    SIMD_Width            : natural
  );
  port(
    -- Core Signals
    clk_i, rst_ni                 : in std_logic;
    -- inputs from DSP_pipeline_controller
    halt_dsp_lat                    : in std_logic_vector(ACCL_NUM-1 downto 0);
    adder_stage_1_en                : in std_logic_vector(ACCL_NUM-1 downto 0); -- enables the use of the adders in stage 1
    adder_stage_2_en                : in std_logic_vector(ACCL_NUM-1 downto 0); -- enables the use of the adders in stage 2
    -- inputs from DSP_Exec_Unit
    carry_pass                      : in array_2d(ACCL_NUM-1 downto 0)(2 downto 0);  -- carry enable signal, depending on it's configuration, we can do KADDV8, KADDV16, KADDV32
    twos_complement                 : in array_2d(ACCL_NUM-1 downto 0)(31 downto 0);
    -- inputs from DSP_Excpt_Unit
    recover_state_wires             : in std_logic_vector(ACCL_NUM-1 downto 0); -- used to recover the state of the DSP, in case of an exception
    -- inputs from DSP_FU_Handler
    add_en                          : in std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the adders
    -- inputs from DSP_Mapping
    MSB_stage_1                     : in array_3d(ACCL_NUM-1 downto 0)(1 downto 0)(4*SIMD-1 downto 0);
    dsp_in_adder_operands           : in array_3d(FU_NUM-1 downto 0)(1 downto 0)(SIMD_Width-1 downto 0);
   
    -- outputs for DSP_Mapping
    dsp_out_adder_results           : out array_2d(FU_NUM-1 downto 0)(SIMD_Width-1 downto 0);
    -- outputs for comparator
    MSB_stage_2                     : out array_3d(ACCL_NUM-1 downto 0)(1 downto 0)(4*SIMD-1 downto 0)
    );
  end component DSP_Adders;

  component DSP_Shifters is
  generic(
    multithreaded_accl_en : natural;
    SIMD                  : natural;
    --------------------------------
    ACCL_NUM              : natural;
    FU_NUM                : natural;
    SIMD_Width            : natural
  );
  port(
    -- Core Signals
    clk_i, rst_ni                   : in std_logic;
    -- inputs from DSP_pipeline_controller
    shifter_stage_1_en              : in std_logic_vector(accl_range);
    shifter_stage_2_en              : in std_logic_vector(accl_range);
    halt_dsp_lat                    : in std_logic_vector(accl_range);
    -- inputs from DSP_Exec_Unit
    MVTYPE_DSP                      : in array_2d(accl_range)(1 downto 0);
    decoded_instruction_DSP_lat     : in array_2d(accl_range)(DSP_UNIT_INSTR_SET_SIZE -1 downto 0);
    -- inputs from DSP_Excpt_Unit
    recover_state_wires             : in std_logic_vector(accl_range);
    -- inputs from DSP_FU_Handler
    shift_en                        : in std_logic_vector(accl_range);  -- enables the use of the shifters
    -- inputs from DSP_Mapping
    dsp_in_shifter_operand          : in array_2d(fu_range)(SIMD_Width-1 downto 0);
    dsp_in_shift_amount             : in array_2d(accl_range)(4 downto 0);

    --outputs for DSP_Mapping
    dsp_out_shifter_results         : out array_2d(fu_range)(SIMD_Width-1 downto 0)
  );
  end component DSP_Shifters;

  component DSP_Multipliers_TMR is
  generic(
    SIMD                  : natural;
    multithreaded_accl_en : natural;
    --------------------------------
    ACCL_NUM              : natural;
    FU_NUM                : natural;
    SIMD_Width            : natural;
    Data_Width            : natural
  );
  port(
    -- Core Signals
    clk_i, rst_ni                   : in std_logic;
    -- inputs from DSP_Exec_Unit
    FUNCT_SELECT_MASK               : array_2d(accl_range)(31 downto 0); -- when the mask is set to "FFFFFFFF" we enable KDOTP32 execution using the 16-bit muls
    MVTYPE_DSP                      : array_2d(accl_range)(1 downto 0);
    -- inputs DSP_Excpt_Unit
    recover_state_wires             : std_logic_vector(accl_range);
    -- inputs from DSP_pipeline_controller
    halt_dsp_lat                    : std_logic_vector(accl_range);
    mul_stage_1_en                  : std_logic_vector(accl_range);
    mul_stage_2_en                  : std_logic_vector(accl_range);
    -- inputs from DSP_FU_Handler
    mul_en                          : std_logic_vector(accl_range);  -- enables the use of the multipliers
    -- inputs from DSP_Mapping
    dsp_in_mul_operands             : array_3d(fu_range)(1 downto 0)(SIMD_Width-1 downto 0);
  
    --outputs for DSP_Mapping
    dsp_out_mul_results             : out array_2d(fu_range)(SIMD_Width-1 downto 0)
  );
  end component DSP_Multipliers_TMR;

  component DSP_Comparators is
  generic(
    SIMD                  : natural;
    multithreaded_accl_en : natural;
    --------------------------------
    ACCL_NUM              : natural;
    FU_NUM                : natural;
    SIMD_Width            : natural
  );
  port(
    -- Core Signals
    clk_i, rst_ni                   : in std_logic;
    -- inputs from DSP_Exec_Unit
    MVTYPE_DSP                      : in array_2d(accl_range)(1 downto 0);
    relu_instr                      : in std_logic_vector(accl_range);
    -- inputs from DSP_pipeline_controller
    halt_dsp_lat                    : in std_logic_vector(accl_range);
    cmp_stage_1_en                  : in std_logic_vector(accl_range);
    -- inputs from DSP_Excpt_Unit
    recover_state_wires             : in std_logic_vector(accl_range);
    -- inputs from DSP_FU_Handler
    cmp_en                          : in std_logic_vector(accl_range);  -- enables the use of the shifters
    -- inputs from DSP_Mapping
    dsp_in_cmp_operands             : in array_2d(fu_range)(SIMD_Width-1 downto 0);
    -- inputs from adders
    MSB_stage_2                     : in array_3d(accl_range)(1 downto 0)(4*SIMD-1 downto 0);
  
    -- outputs for DSP_Mapping
    dsp_out_cmp_results             : out array_2d(fu_range)(SIMD_Width-1 downto 0)
  );
end component DSP_Comparators;
--------------------------------------------------------------------------------------------------
-------------------------------- DSP BEGIN -------------------------------------------------------
begin
busy_dsp <= busy_dsp_internal;

  DSP_EXEC_UNIT_replicated: for h in accl_range generate
    DSP_EXEC_UNIT_inst: DSP_Exec_Unit
      generic map(
        THREAD_POOL_SIZE      => THREAD_POOL_SIZE,
        Addr_Width            => Addr_Width,
        --------------------------------
        SPM_ADDR_WID          => SPM_ADDR_WID,
        SIMD_Width            => SIMD_Width
      )
      port map(
        clk_i                             => clk_i,
        rst_ni                            => rst_ni,
        dsp_instr_req                     => dsp_instr_req(h),
        decoded_instruction_DSP           => decoded_instruction_DSP,
        busy_DSP_internal_lat             => busy_DSP_internal_lat(h),
        state_DSP                         => state_DSP(h),
        halt_dsp_lat                      => halt_dsp_lat(h),
        SIMD_RD_BYTES                     => SIMD_RD_BYTES(h),
        rs1_to_sc                         => rs1_to_sc,
        rs2_to_sc                         => rs2_to_sc,
        rd_to_sc                          => rd_to_sc,
        MVSIZE                            => MVSIZE,
        MVSIZE_h                          => MVSIZE(h),
        MVTYPE                            => MVTYPE,
        MPSCLFAC                          => MPSCLFAC,
        harc_EXEC                         => harc_EXEC,
        vec_read_rs1_ID                   => vec_read_rs1_ID,
        vec_read_rs2_ID                   => vec_read_rs2_ID,
        vec_write_rd_ID                   => vec_write_rd_ID,
        RD_Data_IE                        => RD_Data_IE,
        RS1_Data_IE                       => RS1_Data_IE,
        RS2_Data_IE                       => RS2_Data_IE,
        recover_state_wires               => recover_state_wires(h),
        halt_dsp                          => halt_dsp(h),
        wb_ready                          => wb_ready(h),
        dsp_data_gnt_i                    => dsp_data_gnt_i(h),
        SIMD_RD_BYTES_wire                => SIMD_RD_BYTES_wire(h),
        dsp_sc_data_write_wire_int        => dsp_sc_data_write_wire_int(h),
        dsp_data_gnt_i_lat                => dsp_data_gnt_i_lat(h),

        FUNCT_SELECT_MASK                 => FUNCT_SELECT_MASK(h),
        twos_complement                   => twos_complement(h),
        relu_instr                        => relu_instr(h),
        rf_rs2                            => rf_rs2(h),
        dotpps                            => dotpps(h),
        dotp                              => dotp(h),
        slt                               => slt(h),
        carry_pass                        => carry_pass(h),
        MPSCLFAC_DSP                      => MPSCLFAC_DSP(h),
        MVTYPE_DSP                        => MVTYPE_DSP(h),
        decoded_instruction_DSP_lat       => decoded_instruction_DSP_lat(h),
        dsp_rs1_to_sc                     => dsp_rs1_to_sc(h),
        dsp_rs2_to_sc                     => dsp_rs2_to_sc(h),
        dsp_rd_to_sc                      => dsp_rd_to_sc(h),
        recover_state                     => recover_state(h),
        dsp_sc_data_write_int             => dsp_sc_data_write_int(h),
        dsp_sc_data_read_mask             => dsp_sc_data_read_mask(h),
        RD_Data_IE_lat                    => RD_Data_IE_lat(h),
        MVSIZE_WRITE                      => MVSIZE_WRITE(h),
        MVSIZE_READ                       => MVSIZE_READ(h),
        RS1_Data_IE_lat                   => RS1_Data_IE_lat(h),
        RS2_Data_IE_lat                   => RS2_Data_IE_lat(h),
        vec_read_rs1_DSP                  => vec_read_rs1_DSP(h),
        vec_read_rs2_DSP                  => vec_read_rs2_DSP(h),
        vec_write_rd_DSP                  => vec_write_rd_DSP(h)
      );
  end generate DSP_EXEC_UNIT_replicated;

  DSP_EXCPT_CNTRL_UNIT_replicated: for h in accl_range generate
    DSP_EXCPT_CNTRL_UNIT_inst: DSP_Excpt_Cntrl_unit
      generic map(
        THREAD_POOL_SIZE      => THREAD_POOL_SIZE,
        Addr_Width            => Addr_Width,
        SPM_NUM               => SPM_NUM,
        SIMD                  => SIMD,
        -----------------------------------
        SPM_ADDR_WID          => SPM_ADDR_WID,
        SIMD_BITS             => SIMD_BITS
      )
      port map(
        RD_Data_IE_lat                  => RD_Data_IE_lat(h),
        MVSIZE_WRITE                    => MVSIZE_WRITE(h),
        vec_read_rs2_DSP                => vec_read_rs2_DSP(h),
        vec_write_rd_DSP                => vec_write_rd_DSP(h),
        recover_state                   => recover_state(h),
        dsp_rs1_to_sc                   => dsp_rs1_to_sc(h),
        dsp_rs2_to_sc                   => dsp_rs2_to_sc(h),
        dsp_rd_to_sc                    => dsp_rd_to_sc(h),
        RS1_Data_IE_lat                 => RS1_Data_IE_lat(h),
        RS2_Data_IE_lat                 => RS2_Data_IE_lat(h),
        MVSIZE_READ                     => MVSIZE_READ(h),
        accum_stage_3_en                => accum_stage_3_en(h),
        dsp_sci_wr_gnt                  => dsp_sci_wr_gnt(h),
        mul_stage_3_en                  => mul_stage_3_en(h),
        adder_stage_3_en                => adder_stage_3_en(h),
        dsp_except_data                 => dsp_except_data(h),
        busy_DSP_internal_lat           => busy_DSP_internal_lat(h),
        state_DSP                       => state_DSP(h),
        SIMD_RD_BYTES                   => SIMD_RD_BYTES(h),
        rf_rs2                          => rf_rs2(h),
        decoded_instruction_DSP_lat     => decoded_instruction_DSP_lat(h),
        cmp_stage_2_en                  => cmp_stage_2_en(h),
        shifter_stage_3_en              => shifter_stage_3_en(h),
        rs1_to_sc                       => rs1_to_sc,
        rs2_to_sc                       => rs2_to_sc,
        rd_to_sc                        => rd_to_sc,
        MVSIZE                          => MVSIZE,
        MVTYPE                          => MVTYPE,
        harc_EXEC                       => harc_EXEC,
        RS1_Data_IE                     => RS1_Data_IE,
        RS2_Data_IE                     => RS2_Data_IE,
        RD_Data_IE                      => RD_Data_IE,
        spm_rs1                         => spm_rs1,
        spm_rs2                         => spm_rs2,
        vec_read_rs1_ID                 => vec_read_rs1_ID,
        vec_read_rs2_ID                 => vec_read_rs2_ID,
        vec_write_rd_ID                 => vec_write_rd_ID,
        dsp_instr_req                   => dsp_instr_req(h),
        halt_hart                       => halt_hart(h),

        nextstate_DSP                   => nextstate_DSP(h),
        busy_dsp_internal               => busy_dsp_internal(h),
        wb_ready                        => wb_ready(h),
        dsp_sci_we                      => dsp_sci_we(h),
        dsp_sc_write_addr               => dsp_sc_write_addr(h),
        dsp_sc_read_addr                => dsp_sc_read_addr(h),
        dsp_sci_req                     => dsp_sci_req(h),
        dsp_to_sc                       => dsp_to_sc(h),
        halt_dsp                        => halt_dsp(h),
        recover_state_wires             => recover_state_wires(h),
        dsp_except_data_wire            => dsp_except_data_wire(h),
        dsp_except_condition            => dsp_except_condition(h),
        dsp_we_word                     => dsp_we_word(h),
        dsp_taken_branch                => dsp_taken_branch(h)
      );
  end generate DSP_EXCPT_CNTRL_UNIT_replicated;

  DSP_PIPELINE_CONTROLLER_replicated: for h in accl_range generate
    DSP_PIPELINE_CONTROLLER_inst: DSP_pipeline_controller
      port map(
        clk_i                             => clk_i,
        rst_ni                            => rst_ni,
        dsp_data_gnt_i                    => dsp_data_gnt_i(h),
        nextstate_DSP                     => nextstate_DSP(h),
        dotp                              => dotp(h),  
        dotpps                            => dotpps(h),
        slt                               => slt(h),
        SIMD_RD_BYTES_wire                => SIMD_RD_BYTES_wire(h),
        dsp_except_data_wire              => dsp_except_data_wire(h),
        halt_dsp                          => halt_dsp(h),
        busy_DSP_internal                 => busy_DSP_internal(h),
        cmp_en                            => cmp_en(h),
        shift_en                          => shift_en(h),
        add_en                            => add_en(h),
        mul_en                            => mul_en(h),
        accum_en                          => accum_en(h),

        dsp_data_gnt_i_lat                => dsp_data_gnt_i_lat(h),
        adder_stage_1_en                  => adder_stage_1_en(h),
        adder_stage_2_en                  => adder_stage_2_en(h),
        adder_stage_3_en                  => adder_stage_3_en(h),
        shifter_stage_1_en                => shifter_stage_1_en(h),
        shifter_stage_2_en                => shifter_stage_2_en(h),
        shifter_stage_3_en                => shifter_stage_3_en(h),
        mul_stage_1_en                    => mul_stage_1_en(h),
        mul_stage_2_en                    => mul_stage_2_en(h),
        mul_stage_3_en                    => mul_stage_3_en(h),
        cmp_stage_1_en                    => cmp_stage_1_en(h),
        cmp_stage_2_en                    => cmp_stage_2_en(h),
        accum_stage_1_en                  => accum_stage_1_en(h),
        accum_stage_2_en                  => accum_stage_2_en(h),
        accum_stage_3_en                  => accum_stage_3_en(h),
        halt_dsp_lat                      => halt_dsp_lat(h),
        busy_DSP_internal_lat             => busy_DSP_internal_lat(h),
        SIMD_RD_BYTES                     => SIMD_RD_BYTES(h),
        dsp_except_data                   => dsp_except_data(h),
        state_DSP                         => state_DSP(h)
      );
  end generate DSP_PIPELINE_CONTROLLER_replicated;

  DSP_FU_HANDLER_inst: DSP_FU_Handler
    generic map(
      multithreaded_accl_en => multithreaded_accl_en,
      THREAD_POOL_SIZE      => THREAD_POOL_SIZE,
      --------------------------------
      ACCL_NUM              => ACCL_NUM,
      TPS_CEIL              => TPS_CEIL,
      TPS_BUF_CEIL          => TPS_BUF_CEIL
    )
    port map(
      clk_i                             => clk_i,
      rst_ni                            => rst_ni,
      decoded_instruction_DSP           => decoded_instruction_DSP,
      dsp_instr_req                     => dsp_instr_req,
      busy_dsp_internal                 => busy_dsp_internal,
      busy_DSP_internal_lat             => busy_DSP_internal_lat,
      state_DSP                         => state_DSP,

      cmp_en                            => cmp_en,
      shift_en                          => shift_en,
      add_en                            => add_en,
      mul_en                            => mul_en,
      accum_en                          => accum_en,

      halt_hart                         => halt_hart
    );

    DSP_MAPPING_inst: DSP_Mapping
    generic map(
      THREAD_POOL_SIZE      => THREAD_POOL_SIZE,
      SIMD                  => SIMD,
      multithreaded_accl_en => multithreaded_accl_en,
      --------------------------------
      ACCL_NUM              => ACCL_NUM,
      FU_NUM                => FU_NUM,
      Data_Width            => Data_Width,
      SIMD_Width            => SIMD_Width
    )
    port map(
      MVTYPE                          => MVTYPE,
      dsp_sc_data_read                => dsp_sc_data_read,
      dsp_instr_req                   => dsp_instr_req,
      decoded_instruction_DSP         => decoded_instruction_DSP,
      dsp_out_accum_results           => dsp_out_accum_results,
      busy_DSP_internal_lat           => busy_DSP_internal_lat,
      SIMD_RD_BYTES                   => SIMD_RD_BYTES,
      state_DSP                       => state_DSP,
      halt_dsp_lat                    => halt_dsp_lat,
      decoded_instruction_DSP_lat     => decoded_instruction_DSP_lat,
      MVTYPE_DSP                      => MVTYPE_DSP,
      RS1_Data_IE_lat                 => RS1_Data_IE_lat,
      dsp_sc_data_write_int           => dsp_sc_data_write_int,
      dsp_sc_data_read_mask           => dsp_sc_data_read_mask,
      vec_read_rs2_DSP                => vec_read_rs2_DSP,
      MPSCLFAC_DSP                    => MPSCLFAC_DSP,
      dotp                            => dotp,
      dotpps                          => dotpps,
      rf_rs2                          => rf_rs2,
      RS2_Data_IE_lat                 => RS2_Data_IE_lat,
      halt_dsp                        => halt_dsp,
      dsp_out_mul_results             => dsp_out_mul_results,
      dsp_out_shifter_results         => dsp_out_shifter_results,
      dsp_out_adder_results           => dsp_out_adder_results,
      dsp_out_cmp_results             => dsp_out_cmp_results,

      dsp_sc_data_write_wire_int      => dsp_sc_data_write_wire_int,
      SIMD_RD_BYTES_wire              => SIMD_RD_BYTES_wire,
      dsp_sc_data_write_wire          => dsp_sc_data_write_wire,
      dsp_in_accum_operands           => dsp_in_accum_operands,
      MSB_stage_1                     => MSB_stage_1,
      dsp_in_adder_operands           => dsp_in_adder_operands,
      dsp_in_shift_amount             => dsp_in_shift_amount,
      dsp_in_shifter_operand          => dsp_in_shifter_operand,
      dsp_in_cmp_operands             => dsp_in_cmp_operands,
      dsp_in_mul_operands             => dsp_in_mul_operands
    );

  DSP_ADDERS_inst: DSP_Adders
    generic map(
      multithreaded_accl_en => multithreaded_accl_en,
      SIMD                  => SIMD,
      --------------------------------
      ACCL_NUM              => ACCL_NUM,
      FU_NUM                => FU_NUM,
      SIMD_Width            => SIMD_Width
    )
    port map(
      clk_i                             => clk_i,
      rst_ni                            => rst_ni,
      halt_dsp_lat                      => halt_dsp_lat,
      adder_stage_1_en                  => adder_stage_1_en,
      adder_stage_2_en                  => adder_stage_2_en,
      carry_pass                        => carry_pass,
      twos_complement                   => twos_complement,
      recover_state_wires               => recover_state_wires,
      add_en                            => add_en,
      MSB_stage_1                       => MSB_stage_1,
      dsp_in_adder_operands             => dsp_in_adder_operands,

      dsp_out_adder_results             => dsp_out_adder_results,
      MSB_stage_2                       => MSB_stage_2
    );

  DSP_SHIFTERS_inst: DSP_Shifters
    generic map(
      multithreaded_accl_en => multithreaded_accl_en,
      SIMD                  => SIMD,
      --------------------------------
      ACCL_NUM              => ACCL_NUM,
      FU_NUM                => FU_NUM,
      SIMD_Width            => SIMD_Width
    )
    port map(
      clk_i                             => clk_i,
      rst_ni                            => rst_ni,
      shifter_stage_1_en                => shifter_stage_1_en,
      shifter_stage_2_en                => shifter_stage_2_en,
      halt_dsp_lat                      => halt_dsp_lat,
      MVTYPE_DSP                        => MVTYPE_DSP,
      decoded_instruction_DSP_lat       => decoded_instruction_DSP_lat,
      recover_state_wires               => recover_state_wires,
      shift_en                          => shift_en,
      dsp_in_shifter_operand            => dsp_in_shifter_operand,
      dsp_in_shift_amount               => dsp_in_shift_amount,

      dsp_out_shifter_results           => dsp_out_shifter_results
    );

  DSP_MULTIPLIERS_inst: DSP_Multipliers_TMR
    generic map(
      SIMD                  => SIMD,
      multithreaded_accl_en => multithreaded_accl_en,
      --------------------------------
      ACCL_NUM              => ACCL_NUM,
      FU_NUM                => FU_NUM,
      SIMD_Width            => SIMD_Width,
      Data_Width            => Data_Width
    )
    port map(
      clk_i                             => clk_i,
      rst_ni                            => rst_ni,
      FUNCT_SELECT_MASK                 => FUNCT_SELECT_MASK,
      MVTYPE_DSP                        => MVTYPE_DSP,
      recover_state_wires               => recover_state_wires,
      halt_dsp_lat                      => halt_dsp_lat,
      mul_stage_1_en                    => mul_stage_1_en,
      mul_stage_2_en                    => mul_stage_2_en,
      mul_en                            => mul_en,
      dsp_in_mul_operands               => dsp_in_mul_operands,

      dsp_out_mul_results               => dsp_out_mul_results
    );

  DSP_COMPARATORS_inst: DSP_Comparators
    generic map(
      SIMD                  => SIMD,
      multithreaded_accl_en => multithreaded_accl_en,
      --------------------------------
      ACCL_NUM              => ACCL_NUM,
      FU_NUM                => FU_NUM,
      SIMD_Width            => SIMD_Width
    )
    port map(
      clk_i                             => clk_i,
      rst_ni                            => rst_ni,
      MVTYPE_DSP                        => MVTYPE_DSP,
      relu_instr                        => relu_instr,
      halt_dsp_lat                      => halt_dsp_lat,
      cmp_stage_1_en                    => cmp_stage_1_en,
      recover_state_wires               => recover_state_wires,
      cmp_en                            => cmp_en,
      dsp_in_cmp_operands               => dsp_in_cmp_operands,
      MSB_stage_2                       => MSB_stage_2,

      dsp_out_cmp_results               => dsp_out_cmp_results
  );

----------------------------------------------------
  --   █████╗  ██████╗ ██████╗██╗   ██╗███╗   ███╗  --
  --  ██╔══██╗██╔════╝██╔════╝██║   ██║████╗ ████║  --
  --  ███████║██║     ██║     ██║   ██║██╔████╔██║  --
  --  ██╔══██║██║     ██║     ██║   ██║██║╚██╔╝██║  --
  --  ██║  ██║╚██████╗╚██████╗╚██████╔╝██║ ╚═╝ ██║  --
  --  ╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝  --
  ----------------------------------------------------

 ACCUM_STG : ACCUMULATOR
    generic map(
      multithreaded_accl_en              => multithreaded_accl_en, 
      SIMD                               => SIMD, 
      -------------------------------------------------
      ACCL_NUM                           => ACCL_NUM, 
      FU_NUM                             => FU_NUM, 
      Data_Width                         => Data_Width, 
      SIMD_Width                         => SIMD_Width
    )
  port map(
      clk_i                             => clk_i,
      rst_ni                            => rst_ni,
      MVTYPE_DSP                        => MVTYPE_DSP,
      accum_stage_1_en                  => accum_stage_1_en,
      accum_stage_2_en                  => accum_stage_2_en,
      recover_state_wires               => recover_state_wires,
      halt_dsp_lat                      => halt_dsp_lat,
      state_DSP                         => state_DSP,
      decoded_instruction_DSP_lat       => decoded_instruction_DSP_lat,
      dsp_in_accum_operands             => dsp_in_accum_operands,
      dsp_out_accum_results             => dsp_out_accum_results
  );


end architecture RTL_DSP_TOP_arch;