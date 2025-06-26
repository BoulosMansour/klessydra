-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Busy_FU_Sync is
    port(
    -- Core Signals
    clk_i, rst_ni                   : in std_logic;
    --inputs from DSP_FU_Handler
    busy_add_wire                   : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_mul_wire                   : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_shf_wire                   : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_acc_wire                   : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_cmp_wire                   : in std_logic;  -- busy signal active only when the FU is shared and currently in use 

    --OUTPUTS
    busy_add                        : out std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_mul                        : out std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_shf                        : out std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_acc                        : out std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_cmp                        : out std_logic  -- busy signal active only when the FU is shared and currently in use 
    );
end entity DSP_Busy_FU_Sync;

architecture DSP_Busy_FU_Sync_arch of DSP_Busy_FU_Sync is
begin
  DSP_BUSY_FU_SYNC : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
    elsif rising_edge(clk_i) then
      busy_add    <= busy_add_wire;
      busy_mul    <= busy_mul_wire;
      busy_shf    <= busy_shf_wire;
      busy_acc    <= busy_acc_wire;
      busy_cmp    <= busy_cmp_wire;
    end if;
  end process;
end architecture DSP_Busy_FU_Sync_arch;