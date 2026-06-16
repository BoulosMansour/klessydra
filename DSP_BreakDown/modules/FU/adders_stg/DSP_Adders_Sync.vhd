-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Adders_Sync is
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
end entity DSP_Adders_Sync;

architecture DSP_Adders_Sync_arch of DSP_Adders_Sync is
  -- Sensor monitoring signals (deep-level: per-instance adder-enable observation)
  signal sync_sensor_activity            : std_logic_vector(7 downto 0);
  signal sync_sensor_alert               : std_logic;

  -- SENSOR-DECLARATION: activity_sensor
begin
  fsm_DSP_adder : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
    elsif rising_edge(clk_i) then
        -- Addition is here
        if add_en = '1' and halt_dsp_lat = '0' then
          carry_16     <= carry_16_wire;
          dsp_add_8_0  <= dsp_add_8_0_wire;
          dsp_add_16_8 <= dsp_add_16_8_wire;
          MSB_stage_2  <= MSB_stage_1;
          --  Addition in SIMD Virtual Parallelism is executed here, if the carries are blocked, we will have a chain of 8-bit or 16-bit adders, else we have normal 32-bit adders
          for i in 0 to SIMD-1 loop
            if (adder_stage_2_en = '1' or recover_state_wires = '1') then
                -- All the 8-bit adders are lumped into one output signal
              dsp_out_adder_results(31+32*(i) downto 32*(i)) <= dsp_add_32_24_wire(i)(7 downto 0) & dsp_add_24_16_wire(i)(7 downto 0) & dsp_add_16_8(i)(7 downto 0) & dsp_add_8_0(i)(7 downto 0);
            end if;
          end loop;
          for i in 0 to SIMD-1 loop
            for j in 0 to 1 loop
              dsp_in_adder_operands_lat(j)(15 +16*(i) downto 16*(i)) <= dsp_in_adder_operands(j)(31+32*(i) downto 16+32*(i));
            end loop;
          end loop;
        end if;
    end if;
  end process;
  -- SENSOR-INSTANTIATION: act_sensor_adders_sync

end architecture DSP_Adders_Sync_arch;