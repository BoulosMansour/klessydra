-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;

package tb_config is

  constant THREAD_POOL_SIZE      : integer := 3;
  constant accl_en               : natural := 1;
  constant replicate_accl_en     : natural := 0;
  constant multithreaded_accl_en : natural := 0;
  constant SPM_NUM               : natural := 4; 
  constant Addr_Width            : natural := 14;
  constant SIMD                  : natural := 2;
  --------------------------------
  constant TPS_CEIL          : natural := integer(ceil(log2(real(THREAD_POOL_SIZE))));
  constant TPS_BUF_CEIL      : natural := integer(ceil(log2(real(THREAD_POOL_SIZE-1))));
  constant SPM_ADDR_WID      : natural := integer(ceil(log2(real(SPM_NUM+1)))); 
  constant SIMD_BITS         : natural := integer(ceil(log2(real(SIMD))));
  constant Data_Width        : natural := 32;
  constant SIMD_Width        : natural := SIMD*Data_Width;
  constant ACCL_NUM          : natural := (THREAD_POOL_SIZE - (THREAD_POOL_SIZE-1)*(1-replicate_accl_en));
  constant FU_NUM            : natural := (ACCL_NUM - (ACCL_NUM-1)*(multithreaded_accl_en));


  subtype harc_range is integer range THREAD_POOL_SIZE - 1 downto 0;  -- will be used replicated units in the core
  subtype accl_range is integer range ACCL_NUM - 1 downto 0;  -- will be used replicated accelerators in the core 
  subtype fu_range   is integer range FU_NUM - 1 downto 0; -- will be used replicated accelerators in the core 

end package;