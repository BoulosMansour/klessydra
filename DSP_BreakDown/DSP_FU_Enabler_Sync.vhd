-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_FU_enabler_sync is
    port(
    -- Core Signals
    clk_i, rst_ni                   : in std_logic;
    cmp_en_wire                     : std_logic;  -- enables the use of the shifters
    shift_en_wire                   : std_logic;  -- enables the use of the shifters
    add_en_wire                     : std_logic;  -- enables the use of the adders
    mul_en_wire                     : std_logic;  -- enables the use of the multipliers
    accum_en_wire                   : std_logic;  -- enables the use of the accumulatorss
    add_en_pending_wire             : std_logic;  -- signal to preserve the request to access the adder "multhithreaded mode" only
    shift_en_pending_wire           : std_logic;  -- signal to preserve the request to access the shifter "multhithreaded mode" only
    mul_en_pending_wire             : std_logic;  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
    accum_en_pending_wire           : std_logic;  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
    cmp_en_pending_wire             : std_logic;  -- signal to preserve the request to access the ReLU "multhithreaded mode" only

    --OUTPUTS
    cmp_en                          : out std_logic;  -- enables the use of the shifters
    shift_en                        : out std_logic;  -- enables the use of the shifters
    add_en                          : out std_logic;  -- enables the use of the adders
    mul_en                          : out std_logic;  -- enables the use of the multipliers
    accum_en                        : out std_logic;  -- enables the use of the accumulator
    add_en_pending                  : out std_logic;  -- signal to preserve the request to access the adder "multhithreaded mode" only
    shift_en_pending                : out std_logic;  -- signal to preserve the request to access the shifter "multhithreaded mode" only
    mul_en_pending                  : out std_logic;  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
    accum_en_pending                : out std_logic;  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
    cmp_en_pending                  : out std_logic  -- signal to preserve the request to access the ReLU "multhithreaded mode" only
    );
end entity DSP_FU_enabler_sync;

architecture DSP_FU_enabler_sync_arch of DSP_FU_enabler_sync is
begin
    DSP_FU_ENABLER_SYNCHRONIZER : process(clk_i, rst_ni)
    begin
        if rst_ni = '0' then
            shift_en         <= '0'; 
            add_en           <= '0'; 
            cmp_en           <= '0';
            accum_en         <= '0'; 
            mul_en           <= '0';
            add_en_pending   <= '0';
            shift_en_pending <= '0';
            mul_en_pending   <= '0';
            accum_en_pending <= '0';
            cmp_en_pending   <= '0';
        elsif rising_edge(clk_i) then
            shift_en         <= shift_en_wire; 
            add_en           <= add_en_wire; 
            cmp_en           <= cmp_en_wire; 
            accum_en         <= accum_en_wire; 
            mul_en           <= mul_en_wire; 
            add_en_pending   <= add_en_pending_wire;
            shift_en_pending <= shift_en_pending_wire;
            mul_en_pending   <= mul_en_pending_wire;
            accum_en_pending <= accum_en_pending_wire;
            cmp_en_pending   <= cmp_en_pending_wire;
        end if;
    end process;
end architecture DSP_FU_enabler_sync_arch;