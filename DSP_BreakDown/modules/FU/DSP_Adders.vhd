-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Adders is
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
    carry_pass                      : in array_2d_carry_pass(ACCL_NUM-1 downto 0);  -- carry enable signal, depending on it's configuration, we can do KADDV8, KADDV16, KADDV32
    twos_complement                 : in array_2d_twos_complement(ACCL_NUM-1 downto 0);
    -- inputs from DSP_Excpt_Unit
    recover_state_wires             : in std_logic_vector(ACCL_NUM-1 downto 0); -- used to recover the state of the DSP, in case of an exception
    -- inputs from DSP_FU_Handler
    add_en                          : in std_logic_vector(ACCL_NUM-1 downto 0);  -- enables the use of the adders
    -- inputs from DSP_Mapping
    MSB_stage_1                     : in array_3d_MSB_stage(ACCL_NUM-1 downto 0);
    dsp_in_adder_operands           : in array_3d_dsp_operands(FU_NUM-1 downto 0);
   
    -- outputs for DSP_Mapping
    dsp_out_adder_results           : out array_2d_dsp_operands(FU_NUM-1 downto 0);
    -- outputs for comparator
    MSB_stage_2                     : out array_3d_MSB_stage(ACCL_NUM-1 downto 0)
    );
end entity DSP_Adders;

architecture DSP_Adders_arch of DSP_Adders is
  subtype accl_range is integer range ACCL_NUM - 1 downto 0;
  subtype fu_range   is integer range FU_NUM - 1 downto 0;

  -- Sensor monitoring signals (mid-level: adder-enable observation)
  signal adders_sensor_activity          : std_logic_vector(7 downto 0);
  signal adders_sensor_alert             : std_logic;

  signal dsp_add_8_0                    : array_3d_dsp_add(fu_range); -- 9-bits, contains the results of 8-bit adders
  signal dsp_add_16_8                   : array_3d_dsp_add(fu_range); -- 9-bits  contains the results of 8-bit adders
  signal dsp_add_8_0_wire               : array_3d_dsp_add(fu_range); -- 9-bits, contains the results of 8-bit adders
  signal dsp_add_16_8_wire              : array_3d_dsp_add(fu_range); -- 9-bits  contains the results of 8-bit adders
  signal carry_16_wire                  : array_2d_carry_out(fu_range);  -- carry-out bit of the "dsp_add_16_8" signal
  signal dsp_in_adder_operands_lat      : array_3d_dsp_in_adder_operands_lat(fu_range); -- data_Width devided by the number of pipeline stages
  signal carry_16                       : array_2d_carry_out(fu_range);  -- carry-out bit of the "dsp_add_16_8" signal
  signal dsp_add_24_16_wire             : array_3d_dsp_add(fu_range); -- 9-bits  contains the results of 8-bit adders
  signal dsp_add_32_24_wire             : array_3d_dsp_add(fu_range); -- 9-bits, this should be 8 if we choose to discard the overflow of the addition of the upper byte


  component DSP_Adders_stg_1 is
    generic (
      SIMD            : natural;  
      --------------------------
      SIMD_Width      : natural
    );  
    port(
      -- inputs from DSP_pipeline_controller
      adder_stage_1_en                : in std_logic;
      -- inputs from DSP_Exec_Unit
      carry_pass                      : in std_logic_vector(2 downto 0);  -- carry enable signal, depending on it's configuration, we can do KADDV8, KADDV16, KADDV32
      twos_complement                 : in std_logic_vector(31 downto 0);
      --inputs from DSP_Excpt_Unit
      recover_state_wires             : in std_logic;
      -- inputs from DSP_mapping
      dsp_in_adder_operands           : in array_2d_dsp_operands(1 downto 0);
      -- inputs for Adder
      dsp_add_8_0                     : in array_2d_dsp_add(SIMD-1 downto 0); -- 9-bits, contains the results of 8-bit adders
      dsp_add_16_8                    : in array_2d_dsp_add(SIMD-1 downto 0); -- 9-bits  contains the results of 8-bit adders

      -- outputs for Adder
      dsp_add_8_0_wire                : out array_2d_dsp_add(SIMD-1 downto 0); -- 9-bits, contains the results of 8-bit adders
      dsp_add_16_8_wire               : out array_2d_dsp_add(SIMD-1 downto 0); -- 9-bits  contains the results of 8-bit adders
      carry_16_wire                   : out std_logic_vector(SIMD-1 downto 0)  -- carry-out bit of the "dsp_add_16_8" signal
    );
  end component DSP_Adders_stg_1;

  component DSP_Adders_stg_2 is
    generic(
      SIMD            : natural;
      --------------------------
      SIMD_Width      :natural
    );
    port(
      -- inputs from DSP_pipeline_controller
      halt_dsp_lat                    : in std_logic;
      adder_stage_2_en                : in std_logic;
      -- inputs from DSP_Exec_Unit
      twos_complement                 : in std_logic_vector(31 downto 0);
      carry_pass                      : in std_logic_vector(2 downto 0);  -- carry enable signal, depending on it's configuration, we can do KADDV8, KADDV16, KADDV32
      -- inputs from DSP_Excpt_Unit
      recover_state_wires             : in std_logic;
      -- inputs from Adder
      dsp_in_adder_operands_lat       : in array_2d_dsp_in_adder_operands_lat(1 downto 0); -- data_Width devided by the number of pipeline stages
      carry_16                        : in std_logic_vector(SIMD-1 downto 0);  -- carry-out bit of the "dsp_add_16_8" signal

      --output for Adder
      dsp_add_24_16_wire              : out array_2d_dsp_add(SIMD-1 downto 0); -- 9-bits  contains the results of 8-bit adders
      dsp_add_32_24_wire              : out array_2d_dsp_add(SIMD-1 downto 0) -- 9-bits, this should be 8 if we choose to discard the overflow of the addition of the upper byte
    );
  end component DSP_Adders_stg_2;

  component DSP_Adders_Sync is
    generic(
      SIMD            : natural;  
      --------------------------
      SIMD_Width      : natural
    );
    port(
      -- Core Signals
      clk_i, rst_ni                   : in std_logic;
      -- inputs from DSP_pipeline_controller
      halt_dsp_lat                    : in std_logic;
      adder_stage_2_en                : in std_logic;
      -- inputs from DSP_Excpt_Unit
      recover_state_wires             : in std_logic;
      -- inputs from DSP_FU_Handler
      add_en                          : in std_logic;  -- enables the use of the adders
      -- inputs from DSP_Mapping
      MSB_stage_1                     : in array_2d_MSB_stage(1 downto 0);
      dsp_in_adder_operands           : in array_2d_dsp_operands(1 downto 0);
      -- inputs from adder
      carry_16_wire                   : in std_logic_vector(SIMD-1 downto 0);  -- carry-out bit of the "dsp_add_16_8" signal
      dsp_add_8_0_wire                : in array_2d_dsp_add(SIMD-1 downto 0); -- 9-bits, contains the results of 8-bit adders
      dsp_add_16_8_wire               : in array_2d_dsp_add(SIMD-1 downto 0); -- 9-bits  contains the results of 8-bit adders
      dsp_add_32_24_wire              : in array_2d_dsp_add(SIMD-1 downto 0); -- 9-bits, this should be 8 if we choose to discard the overflow of the addition of the upper byte
      dsp_add_24_16_wire              : in array_2d_dsp_add(SIMD-1 downto 0); -- 9-bits  contains the results of 8-bit adders

      -- outputs for DSP_Mapping
      dsp_out_adder_results           : out std_logic_vector(SIMD_Width-1 downto 0);
      -- outputs for comparator
      MSB_stage_2                     : out array_2d_MSB_stage(1 downto 0);
      -- outputs for Adder
      carry_16                        : out std_logic_vector(SIMD-1 downto 0);  -- carry-out bit of the "dsp_add_16_8" signal
      dsp_add_8_0                     : inout array_2d_dsp_add(SIMD-1 downto 0); -- 9-bits, contains the results of 8-bit adders
      dsp_add_16_8                    : inout array_2d_dsp_add(SIMD-1 downto 0); -- 9-bits  contains the results of 8-bit adders
      dsp_in_adder_operands_lat       : out array_2d_dsp_in_adder_operands_lat(1 downto 0) -- data_Width devided by the number of pipeline stages
    );
  end component  DSP_Adders_Sync;

  -- SENSOR-DECLARATION: activity_sensor

begin
  ADDER_MULTICORE: if multithreaded_accl_en = 0 generate
    DSP_Adders_replicated: for h in accl_range generate
      DSP_Adders_stg_1_inst: DSP_Adders_stg_1
        generic map (
          SIMD            => SIMD,
          SIMD_Width      => SIMD_Width
        )
        port map (
          adder_stage_1_en                => adder_stage_1_en(h),
          carry_pass                      => carry_pass(h),
          twos_complement                 => twos_complement(h),
          recover_state_wires             => recover_state_wires(h),
          dsp_in_adder_operands           => dsp_in_adder_operands(h),
          dsp_add_8_0                     => dsp_add_8_0(h),
          dsp_add_16_8                    => dsp_add_16_8(h),
          dsp_add_8_0_wire                => dsp_add_8_0_wire(h),
          dsp_add_16_8_wire               => dsp_add_16_8_wire(h),
          carry_16_wire                   => carry_16_wire(h)
        );
      DSP_Adders_stg_2_inst: DSP_Adders_stg_2
        generic map (
          SIMD            => SIMD,
          SIMD_Width      => SIMD_Width
        )
        port map (
          halt_dsp_lat                    => halt_dsp_lat(h),
          adder_stage_2_en                => adder_stage_2_en(h),
          twos_complement                 => twos_complement(h),
          carry_pass                      => carry_pass(h),
          recover_state_wires             => recover_state_wires(h),
          dsp_in_adder_operands_lat       => dsp_in_adder_operands_lat(h),
          carry_16                        => carry_16_wire(h),
          dsp_add_24_16_wire              => dsp_add_24_16_wire(h),
          dsp_add_32_24_wire              => dsp_add_32_24_wire(h)
        );
      DSP_Adders_Sync_inst: DSP_Adders_Sync
        generic map (
          SIMD            => SIMD,
          SIMD_Width      => SIMD_Width
        )
        port map (
          clk_i                          => clk_i,
          rst_ni                         => rst_ni,
          halt_dsp_lat                   => halt_dsp_lat(h),
          adder_stage_2_en               => adder_stage_2_en(h),
          recover_state_wires            => recover_state_wires(h),
          add_en                         => add_en(h),
          MSB_stage_1                    => MSB_stage_1(h),
          dsp_in_adder_operands          => dsp_in_adder_operands(h),
          carry_16_wire                  => carry_16_wire(h),
          dsp_add_8_0_wire               => dsp_add_8_0_wire(h),
          dsp_add_16_8_wire              => dsp_add_16_8_wire(h),
          dsp_add_32_24_wire             => dsp_add_32_24_wire(h),
          dsp_add_24_16_wire             => dsp_add_24_16_wire(h),
          dsp_out_adder_results           => dsp_out_adder_results(h),
          MSB_stage_2                     => MSB_stage_2(h),
          carry_16                        => carry_16(h),
          dsp_add_8_0                     => dsp_add_8_0(h),
          dsp_add_16_8                    => dsp_add_16_8(h),
          dsp_in_adder_operands_lat       => dsp_in_adder_operands_lat(h)
        );
    end generate DSP_Adders_replicated;
  end generate ADDER_MULTICORE;

  ADDER_MULTITHREAD: if multithreaded_accl_en = 1 generate
    DSP_Adders_replicated: for h in accl_range generate
      DSP_Adders_stg_1_inst: DSP_Adders_stg_1
        generic map (
          SIMD            => SIMD,
          SIMD_Width      => SIMD_Width
        )
        port map (
          adder_stage_1_en                => adder_stage_1_en(h),
          carry_pass                      => carry_pass(h),
          twos_complement                 => twos_complement(h),
          recover_state_wires             => recover_state_wires(h),
          dsp_in_adder_operands           => dsp_in_adder_operands(0),
          dsp_add_8_0                     => dsp_add_8_0(0),
          dsp_add_16_8                    => dsp_add_16_8(0),
          dsp_add_8_0_wire                => dsp_add_8_0_wire(0),
          dsp_add_16_8_wire               => dsp_add_16_8_wire(0),
          carry_16_wire                   => carry_16_wire(0)
        );
      DSP_Adders_stg_2_inst: DSP_Adders_stg_2
        generic map (
          SIMD            => SIMD,
          SIMD_Width      => SIMD_Width
        )
        port map (
          halt_dsp_lat                    => halt_dsp_lat(h),
          adder_stage_2_en                => adder_stage_2_en(h),
          twos_complement                 => twos_complement(h),
          carry_pass                      => carry_pass(h),
          recover_state_wires             => recover_state_wires(h),
          dsp_in_adder_operands_lat       => dsp_in_adder_operands_lat(0),
          carry_16                        => carry_16_wire(0),
          dsp_add_24_16_wire              => dsp_add_24_16_wire(0),
          dsp_add_32_24_wire              => dsp_add_32_24_wire(0)
        );
      DSP_Adders_Sync_inst: DSP_Adders_Sync
        generic map (
          SIMD            => SIMD,
          SIMD_Width      => SIMD_Width
        )
        port map (
          clk_i                          => clk_i,
          rst_ni                         => rst_ni,
          halt_dsp_lat                   => halt_dsp_lat(h),
          adder_stage_2_en               => adder_stage_2_en(h),
          recover_state_wires            => recover_state_wires(h),
          add_en                         => add_en(h),
          MSB_stage_1                    => MSB_stage_1(0),
          dsp_in_adder_operands          => dsp_in_adder_operands(0),
          carry_16_wire                  => carry_16_wire(0),
          dsp_add_8_0_wire               => dsp_add_8_0_wire(0),
          dsp_add_16_8_wire              => dsp_add_16_8_wire(0),
          dsp_add_32_24_wire             => dsp_add_32_24_wire(0),
          dsp_add_24_16_wire             => dsp_add_24_16_wire(0),
          dsp_out_adder_results           => dsp_out_adder_results(0),
          MSB_stage_2                     => MSB_stage_2(0),
          carry_16                        => carry_16(0),
          dsp_add_8_0                     => dsp_add_8_0(0),
          dsp_add_16_8                    => dsp_add_16_8(0),
          dsp_in_adder_operands_lat       => dsp_in_adder_operands_lat(0)
        );
    end generate DSP_Adders_replicated;
  end generate ADDER_MULTITHREAD;
  -- SENSOR-INSTANTIATION: act_sensor_adders

end architecture DSP_Adders_arch;