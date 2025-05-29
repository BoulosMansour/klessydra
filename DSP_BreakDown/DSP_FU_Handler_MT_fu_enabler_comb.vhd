-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_FU_Handler_MT_fu_enabler_comb is
    port(
    -- ID_Stage Signals
    decoded_instruction_DSP         : in  std_logic_vector(DSP_UNIT_INSTR_SET_SIZE-1 downto 0);
    dsp_instr_req                   : in  std_logic;
    --input from DSP_Excpt_Cntrl_Unit_comb
    busy_dsp_internal               : in std_logic;
    -- input from DSP_pipeline_controller
    busy_DSP_internal_lat           : in std_logic;
    state_DSP                       : in std_logic_vector(1 downto 0);
    --inputs from DSP_FU_Enabler_Sync
    cmp_en                          : in std_logic;  -- enables the use of the shifters
    shift_en                        : in std_logic;  -- enables the use of the shifters
    add_en                          : in std_logic;  -- enables the use of the adders
    mul_en                          : in std_logic;  -- enables the use of the multipliers
    accum_en                        : in std_logic;  -- enables the use of the accumulator
    add_en_pending                  : in std_logic;  -- signal to preserve the request to access the adder "multhithreaded mode" only
    shift_en_pending                : in std_logic;  -- signal to preserve the request to access the shifter "multhithreaded mode" only
    mul_en_pending                  : in std_logic;  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
    accum_en_pending                : in std_logic;  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
    cmp_en_pending                  : in std_logic;  -- signal to preserve the request to access the ReLU "multhithreaded mode" only
    --input from DSP_FU_Handler_MT_busy_fu_sync
    busy_add                        : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_mul                        : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_shf                        : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_acc                        : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
    busy_cmp                        : in std_logic;  -- busy signal active only when the FU is shared and currently in use 
    --input from DSP_FU_Handler_MT_fu_issue_buffer_sync
    fu_gnt                          : in std_logic_vector(4 downto 0); -- grant signal from the FU issue buffer

    --OUTPUTS
    cmp_en_wire                     : out std_logic;  -- enables the use of the shifters
    shift_en_wire                   : out std_logic;  -- enables the use of the shifters
    add_en_wire                     : out std_logic;  -- enables the use of the adders
    mul_en_wire                     : out std_logic;  -- enables the use of the multipliers
    accum_en_wire                   : out std_logic;  -- enables the use of the accumulatorss
    add_en_pending_wire             : out std_logic;  -- signal to preserve the request to access the adder "multhithreaded mode" only
    shift_en_pending_wire           : out std_logic;  -- signal to preserve the request to access the shifter "multhithreaded mode" only
    mul_en_pending_wire             : out std_logic;  -- signal to preserve the request to access the multiplier "multhithreaded mode" only
    accum_en_pending_wire           : out std_logic;  -- signal to preserve the request to access the accumulator "multhithreaded mode" only
    cmp_en_pending_wire             : out std_logic;  -- signal to preserve the request to access the ReLU "multhithreaded mode" only
    halt_hart                       : out std_logic; -- halts the thread when the requested functional unit is in use
    fu_req                          : out std_logic_vector(4 downto 0) -- Each threa has request bits equal to the total number of FUs
    );
end entity DSP_FU_Handler_MT_fu_enabler_comb;

architecture DSP_FU_Handler_MT_fu_enabler_comb_arch of DSP_FU_Handler_MT_fu_enabler_comb is
begin
DSP_FU_ENABLER_comb : process(all)
    begin

      shift_en_wire               <= shift_en; 
      add_en_wire                 <= add_en; 
      cmp_en_wire                 <= cmp_en; 
      accum_en_wire               <= accum_en; 
      mul_en_wire                 <= mul_en; 
      add_en_pending_wire         <= add_en_pending;
      shift_en_pending_wire       <= shift_en_pending;
      mul_en_pending_wire         <= mul_en_pending;
      accum_en_pending_wire       <= accum_en_pending;
      cmp_en_pending_wire         <= cmp_en_pending;
      fu_req                      <= (others => '0');
      halt_hart                   <= '0';


      if add_en = '1' and busy_DSP_internal = '0' then
        add_en_wire <= '0';
      end if;
      if mul_en = '1' and busy_DSP_internal = '0' then
        mul_en_wire <= '0';
      end if;
      if shift_en = '1' and busy_DSP_internal = '0' then
        shift_en_wire <= '0';
      end if;
      if accum_en = '1' and busy_DSP_internal = '0' then
        accum_en_wire <= '0';
      end if;
      if cmp_en = '1' and busy_DSP_internal = '0' then
        cmp_en_wire <= '0';
      end if;

      if dsp_instr_req = '1' or busy_DSP_internal_lat = '1' then

        case state_DSP is

          when dsp_init =>

            -- Set signals to enable correct virtual parallelism operation
            if decoded_instruction_DSP(KADDV_bit_position)    = '1' or 
               decoded_instruction_DSP(KSVADDSC_bit_position) = '1' or
               decoded_instruction_DSP(KSVADDRF_bit_position) = '1' or
               decoded_instruction_DSP(KSUBV_bit_position)    = '1' or
               decoded_instruction_DSP(KVCP_bit_position)     = '1' then
              if busy_add = '0' and add_en_pending = '0' then 
                add_en_wire <= '1';
              else
                add_en_pending_wire <= '1';
                halt_hart <= '1';
                fu_req(0) <= '1';
              end if;
            elsif decoded_instruction_DSP(KDOTP_bit_position) = '1' then
              if busy_mul = '0' and busy_acc = '0' and mul_en_pending = '0' and accum_en_pending = '0' then 
                mul_en_wire   <= '1';
                accum_en_wire <= '1';
              else
                mul_en_pending_wire   <= '1';
                accum_en_pending_wire <= '1';
                halt_hart <= '1';
                fu_req(2) <= '1';
                fu_req(3) <= '1';
              end if;
            elsif decoded_instruction_DSP(KDOTPPS_bit_position) = '1' then
              if busy_mul = '0' and busy_acc = '0' and busy_shf = '0'  and mul_en_pending = '0' and accum_en_pending = '0' and shift_en_pending = '0' then 
                mul_en_wire   <= '1';
                shift_en_wire <= '1';
                accum_en_wire <= '1';
              else
                mul_en_pending_wire   <= '1';
                shift_en_pending_wire <= '1';
                accum_en_pending_wire <= '1';
                halt_hart <= '1';
                fu_req(2) <= '1';
                fu_req(1) <= '1';
                fu_req(3) <= '1';
              end if;
            elsif decoded_instruction_DSP(KVRED_bit_position) = '1' then
              if busy_acc = '0' and accum_en_pending = '0' then 
                accum_en_wire <= '1';
              else
                accum_en_pending_wire <= '1';
                halt_hart <= '1';
                fu_req(3) <= '1';
              end if;
            elsif decoded_instruction_DSP(KSVMULRF_bit_position) = '1' or
                  decoded_instruction_DSP(KSVMULSC_bit_position) = '1' or
                  decoded_instruction_DSP(KVMUL_bit_position)    = '1' then
              if busy_mul = '0' and mul_en_pending = '0' then 
                mul_en_wire <= '1';
              else
                mul_en_pending_wire <= '1';
                halt_hart <= '1';
                fu_req(2) <= '1';
              end if;
            elsif decoded_instruction_DSP(KSRAV_bit_position) = '1' or
                  decoded_instruction_DSP(KSRLV_bit_position) = '1' then
              if busy_shf = '0' and shift_en_pending = '0' then 
                shift_en_wire <= '1';
              else
                shift_en_pending_wire <= '1';
                halt_hart <= '1';
                fu_req(1) <= '1';
              end if;
            elsif decoded_instruction_DSP(KRELU_bit_position) = '1' then
              if busy_cmp = '0' and cmp_en_pending = '0' then 
                cmp_en_wire <= '1';
              else
                cmp_en_pending_wire <= '1';
                halt_hart <= '1';
                fu_req(4) <= '1';
              end if;
            elsif decoded_instruction_DSP(KVSLT_bit_position)  = '1' or
                  decoded_instruction_DSP(KSVSLT_bit_position) = '1' then
              if busy_cmp = '0' and busy_add = '0' and cmp_en_pending = '0' and add_en_pending = '0' then 
                add_en_wire   <= '1';
                cmp_en_wire <= '1';
              else
                add_en_pending_wire <= '1';
                cmp_en_pending_wire <= '1';
                halt_hart <= '1';
                fu_req(0) <= '1';
                fu_req(4) <= '1';
              end if;
            end if;

          when dsp_halt_hart =>
  
            if fu_gnt(0) = '1' then
              add_en_wire <= '1';
              add_en_pending_wire <= '0';
            elsif add_en_pending = '1' and fu_gnt(0) = '0'  then
              halt_hart <= '1';
            end if;

            if fu_gnt(1) = '1' then
              shift_en_wire <= '1';
              shift_en_pending_wire <= '0';
            elsif shift_en_pending = '1' and fu_gnt(1) = '0' then
              halt_hart <= '1';
            end if;

            if fu_gnt(2) = '1' then
              mul_en_wire <= '1';
              mul_en_pending_wire <= '0';
            elsif mul_en_pending = '1' and fu_gnt(2) = '0'  then
              halt_hart <= '1';
            end if;

            if fu_gnt(3) = '1' then
              accum_en_wire <= '1';
              accum_en_pending_wire <= '0';
            elsif accum_en_pending = '1' and fu_gnt(3) = '0'  then
              halt_hart <= '1';
            end if;

            if fu_gnt(4) = '1' then
              cmp_en_wire <= '1';
              cmp_en_pending_wire <= '0';
            elsif cmp_en_pending = '1' and fu_gnt(4) = '0'  then
              halt_hart <= '1';
            end if;

          when others =>
            null;
        end case;
      end if;
  end process;
end architecture DSP_FU_Handler_MT_fu_enabler_comb_arch;