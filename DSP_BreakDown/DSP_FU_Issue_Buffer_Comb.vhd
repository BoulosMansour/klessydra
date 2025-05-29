-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_FU_Issue_Buffer_Comb is
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
        busy_add_wire                   : std_logic;  -- busy signal active only when the FU is shared and currently in use 
        busy_mul_wire                   : std_logic;  -- busy signal active only when the FU is shared and currently in use 
        busy_shf_wire                   : std_logic;  -- busy signal active only when the FU is shared and currently in use 
        busy_acc_wire                   : std_logic;  -- busy signal active only when the FU is shared and currently in use 
        busy_cmp_wire                   : std_logic;  -- busy signal active only when the FU is shared and currently in use 
        --inputs from DSP_FU_Enabler_comb
        add_en_pending_wire             : std_logic;  -- signal to preserve the request to access the adder "multhithreaded mode" only
        shift_en_pending_wire           : std_logic;  -- signal to preserve the request to access the shifter "multhithreaded mode" only
        mul_en_pending_wire             : std_logic;  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
        accum_en_pending_wire           : std_logic;  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
        cmp_en_pending_wire             : std_logic;  -- signal to preserve the request to access the ReLU "multhithreaded mode" only
        --inputs from DSP_FU_Issue_Buffer_Sync
        fu_issue_buffer                 : array_3D(4 downto 0)(THREAD_POOL_SIZE-2 downto 0)(TPS_CEIL-1 downto 0);
        fu_rd_ptr                       : array_2D(4 downto 0)(TPS_BUF_CEIL-1 downto 0); -- five rd pointers each has a number of bits equal to ceil(log2(THREAD_POOL_SIZE-1))

        --output for DSP_FU_Issue_Buffer_Sync
        fu_gnt_wire                     : out std_logic_vector(4 downto 0); -- Each threa has grant bits equal to the total number of FUs
        fu_gnt_en                       : out std_logic_vector(4 downto 0) -- Enable the giving of the grant to the thread pointed at by the issue buffer
    );
end entity DSP_FU_Issue_Buffer_comb;

architecture DSP_FU_Issue_Buffer_comb_arch of DSP_FU_Issue_Buffer_comb is
begin
  FU_Issue_Buffer_comb : process(all)
  begin
      fu_gnt_wire <= (others => '0');
      fu_gnt_en   <= (others => '0');
      if add_en_pending_wire = '1' and busy_add_wire = '0' then
        fu_gnt_en(0) <= '1';
      end if;
      if shift_en_pending_wire = '1' and busy_shf_wire = '0' then
        fu_gnt_en(1) <= '1';
      end if;
      if mul_en_pending_wire = '1' and busy_mul_wire = '0' then
        fu_gnt_en(2) <= '1';
      end if;
      if accum_en_pending_wire = '1' and busy_acc_wire = '0' then
        fu_gnt_en(3) <= '1';
      end if;
      if cmp_en_pending_wire = '1' and busy_cmp_wire = '0' then
        fu_gnt_en(4) <= '1';
      end if;
      case state_DSP is
        when dsp_halt_hart =>
          for i in 0 to 4 loop 
            if fu_gnt_en(i) = '1' then
              fu_gnt_wire(to_integer(unsigned(fu_issue_buffer(i)(to_integer(unsigned(fu_rd_ptr(i)))))))(i) <= '1'; -- give a grant to fu_gnt(i), such that the 'h' index points to the thread in "fu_issue_buffer"
            end if;
          end loop;
        when others =>
          null;
      end case;
  end process;
end architecture DSP_FU_Issue_Buffer_comb_arch;