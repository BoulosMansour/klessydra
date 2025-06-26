-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_FU_Issue_Buffer_Sync is --this component should not be repicated, the signals already have the correct dimensions
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
    --inputs from DSP_pipeline_controller
    state_DSP                       : in array_2d(ACCL_NUM-1 downto 0)(1 downto 0);
    --inputs from DSP_FU_Handler_MT_fu_issue_buffer_comb
    fu_gnt_wire                     : in array_2D(ACCL_NUM-1 downto 0)(4 downto 0); -- Each threa has grant bits equal to the total number of FUs
    fu_gnt_en                       : array_2D(ACCL_NUM-1 downto 0)(4 downto 0); -- Enable the giving of the grant to the thread pointed at by the issue buffer
    --inputs from DSP_FU_Handler_MT_fu_enabler_comb
    fu_req                          : array_2D(ACCL_NUM-1 downto 0)(4 downto 0); -- Each threa has request bits equal to the total number of FUs

    --OUTPUTS
    fu_rd_ptr                       : out array_2D(4 downto 0)(TPS_BUF_CEIL-1 downto 0); -- five rd pointers each has a number of bits equal to ceil(log2(THREAD_POOL_SIZE-1))
    fu_gnt                          : out array_2D(ACCL_NUM-1 downto 0)(4 downto 0); -- Each threa has grant bits equal to the total number of FUs
    fu_issue_buffer                 : out array_3D(4 downto 0)(THREAD_POOL_SIZE-2 downto 0)(TPS_CEIL-1 downto 0)
    );
end entity DSP_FU_Issue_Buffer_Sync;

architecture DSP_FU_Issue_Buffer_Sync_arch of DSP_FU_Issue_Buffer_Sync is
subtype accl_range is integer range ACCL_NUM - 1 downto 0;
begin
  FU_Issue_Buffer_sync : process(clk_i, rst_ni)
  variable fu_wr_ptr                       : array_2D(4 downto 0)(TPS_BUF_CEIL-1 downto 0); -- five rd pointers each has a number of bits equal to ceil(log2(THREAD_POOL_SIZE-1))
  begin
    if rst_ni = '0' then
      fu_rd_ptr  <= (others => (others => '0'));
      fu_wr_ptr  := (others => (others => '0'));
      fu_gnt     <= (others => (others => '0'));
    elsif rising_edge(clk_i) then
      fu_gnt <= fu_gnt_wire;
      for h in accl_range loop
        for i in 0 to 4 loop  -- Loop index 'i' is for the total number of different functional units (regardless what SIMD config is set)
          if fu_req(h)(i) = '1' then  -- if a reservation was made, to use a functional unit
            --to_integer(unsigned(fu_issue_buffer(i)(to_integer(unsigned(fu_wr_ptr(i)))))) <= h;  -- store the thread_ID in its corresponding buffer at the fu_wr_ptr position
            --fu_issue_buffer(to_integer(unsigned(fu_wr_ptr(i))))(i) <= std_logic_vector(unsigned(h));  -- store the thread_ID in its corresponding buffer at the fu_wr_ptr position
            fu_issue_buffer(i)(to_integer(unsigned(fu_wr_ptr(i))))  <= std_logic_vector(to_unsigned(h,TPS_CEIL));
            if unsigned(fu_wr_ptr(i)) = THREAD_POOL_SIZE - 2 then -- increment the pointer wr logic
              fu_wr_ptr(i) := (others => '0');
            else
              fu_wr_ptr(i) := std_logic_vector(unsigned(fu_wr_ptr(i)) + 1);
            end if;
          end if;
          case state_DSP(h) is
            when dsp_halt_hart =>
              if fu_gnt_en(h)(i) = '1' then
                if unsigned(fu_rd_ptr(i)) = THREAD_POOL_SIZE - 2 then  -- increment the read pointer
                  fu_rd_ptr(i) <= (others => '0');
                else
                  fu_rd_ptr(i) <= std_logic_vector(unsigned(fu_rd_ptr(i)) + 1);
                end if;
              end if;
            when others =>
             null;
          end case;
        end loop;
      end loop;
    end if;
  end process;
end architecture DSP_FU_Issue_Buffer_Sync_arch;