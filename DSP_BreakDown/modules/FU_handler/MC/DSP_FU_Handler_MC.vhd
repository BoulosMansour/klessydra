-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_FU_Handler_MC is
    port(
    --ID_Stage Signals
    dsp_instr_req                   : in  std_logic;    
    decoded_instruction_DSP         : in  std_logic_vector(DSP_UNIT_INSTR_SET_SIZE-1 downto 0);
    --inputs from DSP_FU_Enabler_Sync
    cmp_en                          : in std_logic;  -- enables the use of the shifters
    shift_en                        : in std_logic;  -- enables the use of the shifters
    add_en                          : in std_logic;  -- enables the use of the adders
    mul_en                          : in std_logic;  -- enables the use of the multipliers
    accum_en                        : in std_logic;  -- enables the use of the accumulator
    --inputs from DSP_Excpt_Cntrl_Unit_comb
    busy_dsp_internal               : std_logic;
    -- inputs from fsm_DSP_pipeline_controller
    busy_DSP_internal_lat           : std_logic;
    state_DSP                       : in std_logic_vector(1 downto 0);

    --OUTPUTS
    cmp_en_wire                     : out std_logic;  -- enables the use of the shifters
    shift_en_wire                   : out std_logic;  -- enables the use of the shifters
    add_en_wire                     : out std_logic;  -- enables the use of the adders
    mul_en_wire                     : out std_logic;  -- enables the use of the multipliers
    accum_en_wire                   : out std_logic;  -- enables the use of the accumulatorss
    halt_hart                       : out std_logic   -- halts the thread when the requested functional unit is in use
    );
end entity DSP_FU_Handler_MC;

architecture DSP_FU_Handler_MC_arch of DSP_FU_Handler_MC is
begin
  DSP_FU_ENABLER_comb : process(all)
  begin
      shift_en_wire <= shift_en; 
      add_en_wire   <= add_en; 
      cmp_en_wire   <= cmp_en; 
      accum_en_wire <= accum_en; 
      mul_en_wire   <= mul_en; 
      halt_hart     <= '0';

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
              add_en_wire <= '1';
            elsif decoded_instruction_DSP(KDOTP_bit_position) = '1' then
              mul_en_wire   <= '1';
              accum_en_wire <= '1';
            elsif decoded_instruction_DSP(KDOTPPS_bit_position) = '1' then
              mul_en_wire   <= '1';
              shift_en_wire <= '1';
              accum_en_wire <= '1';
            elsif decoded_instruction_DSP(KVSLT_bit_position)  = '1' or
                  decoded_instruction_DSP(KSVSLT_bit_position) = '1' then
              add_en_wire <= '1';
              cmp_en_wire <= '1';
            elsif decoded_instruction_DSP(KVRED_bit_position) = '1' then
              accum_en_wire <= '1';
            elsif decoded_instruction_DSP(KSVMULRF_bit_position) = '1' or
                  decoded_instruction_DSP(KSVMULSC_bit_position) = '1' or
                  decoded_instruction_DSP(KVMUL_bit_position)    = '1' then
              mul_en_wire <= '1';
            elsif decoded_instruction_DSP(KSRAV_bit_position) = '1' or
                  decoded_instruction_DSP(KSRLV_bit_position) = '1' then
              shift_en_wire <= '1';
            elsif decoded_instruction_DSP(KRELU_bit_position)  = '1' then
              cmp_en_wire <= '1';
            end if;
          when others =>
            null;
        end case;
      end if;
  end process;
end architecture DSP_FU_Handler_MC_arch;