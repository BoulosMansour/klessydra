-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_FU_Handler_MT_pending_enabler_sync is
    port(
    -- Core Signals
    clk_i, rst_ni                   : in std_logic;
    --INPUTS
    add_en_pending_wire             : std_logic;  -- signal to preserve the request to access the adder "multhithreaded mode" only
    shift_en_pending_wire           : std_logic;  -- signal to preserve the request to access the shifter "multhithreaded mode" only
    mul_en_pending_wire             : std_logic;  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
    accum_en_pending_wire           : std_logic;  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
    cmp_en_pending_wire             : std_logic;  -- signal to preserve the request to access the ReLU "multhithreaded mode" only

    --OUTPUTS
    add_en_pending                  : out std_logic;  -- signal to preserve the request to access the adder "multhithreaded mode" only
    shift_en_pending                : out std_logic;  -- signal to preserve the request to access the shifter "multhithreaded mode" only
    mul_en_pending                  : out std_logic;  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
    accum_en_pending                : out std_logic;  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
    cmp_en_pending                  : out std_logic  -- signal to preserve the request to access the ReLU "multhithreaded mode" only
    );
end entity DSP_FU_Handler_MT_pending_enabler_sync;

architecture DSP_FU_Handler_MT_pending_enabler_sync_arch of DSP_FU_Handler_MT_pending_enabler_sync is
begin
  DSP_FU_ENABLER_SYNC : process(clk_i, rst_ni) -- remoce the pending signals as they are all used only inside the FU_Handler_MT and create a new component to be imported inside the FU_Handler_MT
  begin
    if rst_ni = '0' then
      add_en_pending   <= '0';
      shift_en_pending <= '0';
      mul_en_pending   <= '0';
      accum_en_pending <= '0';
      cmp_en_pending   <= '0';
    elsif rising_edge(clk_i) then
      add_en_pending   <= add_en_pending_wire;
      shift_en_pending <= shift_en_pending_wire;
      mul_en_pending   <= mul_en_pending_wire;
      accum_en_pending <= accum_en_pending_wire;
      cmp_en_pending   <= cmp_en_pending_wire;
    end if;
  end process;
end architecture DSP_FU_Handler_MT_pending_enabler_sync_arch;