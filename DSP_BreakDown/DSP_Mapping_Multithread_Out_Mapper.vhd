-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Mapping_Multithread_Out_Mapper is
    generic(
        THREAD_POOL_SIZE      : integer;
        SIMD                  : natural;
        --------------------------------
        Data_Width            : natural;
        SIMD_Width            : natural
    );
    port(-- IN THE TOP ENTITY CONNECT ONLY INDEX (0) FOR ALL SIGNALS HAVING SIZE OF fu_range
        -- CSR Signals
        MVTYPE                          : in  array_2d(THREAD_POOL_SIZE-1 downto 0)(3 downto 0);
        -- ID_Stage Signals
        dsp_instr_req                   : in  std_logic;
        decoded_instruction_DSP         : in  std_logic_vector(DSP_UNIT_INSTR_SET_SIZE-1 downto 0);
        -- input from ACCUMULATOR
        dsp_out_accum_results           : in std_logic_vector(31 downto 0);
        -- input from DSP_pipeline_controller
        busy_DSP_internal_lat           : in std_logic;
        state_DSP                       : in std_logic_vector(1 downto 0);
        halt_dsp_lat                    : std_logic;
        -- input from DSP_Exec_Unit
        decoded_instruction_DSP_lat     : in std_logic_vector(DSP_UNIT_INSTR_SET_SIZE -1 downto 0);
        MVTYPE_DSP                      : in std_logic_vector(1 downto 0);
        RS1_Data_IE_lat                 : in std_logic_vector(31 downto 0);
        dsp_sc_data_write_int           : in std_logic_vector(SIMD_Width-1 downto 0);
        -- input from DSP_Excpt_Unit
        halt_dsp                        : in std_logic;
        -- input from multiplier stage 2
        dsp_out_mul_results             : in std_logic_vector(SIMD_Width-1 downto 0);
        -- input from shifter stage 2
        dsp_out_shifter_results         : in std_logic_vector(SIMD_Width-1 downto 0);
        -- input from adder stage 2
        dsp_out_adder_results           : in std_logic_vector(SIMD_Width-1 downto 0);
        -- input from comparators
        dsp_out_cmp_results             : in std_logic_vector(SIMD_Width-1 downto 0);

        --output for DSP_Exec_Unit
        dsp_sc_data_write_wire_int      : out std_logic_vector(SIMD_Width-1 downto 0);
        SIMD_RD_BYTES_wire              : out integer;
        -- Scratchpad Interface Signals
        dsp_sc_data_write_wire          : out std_logic_vector(SIMD_Width-1 downto 0)
    );
end entity DSP_Mapping_Multithread_Out_Mapper;

architecture DSP_Mapping_Multithread_Out_Mapper_arch of DSP_Mapping_Multithread_Out_Mapper is
begin
  MAPPING_OUT_UNIT_comb : process(all)
  begin
      dsp_sc_data_write_wire_int  <= (others => '0');
      dsp_sc_data_write_wire      <= dsp_sc_data_write_wire_int;
      SIMD_RD_BYTES_wire <= SIMD*(Data_Width/8);

      if dsp_instr_req = '1' or busy_DSP_internal_lat = '1' then
        case state_DSP is
          when dsp_init =>

            -- Set signals to enable correct virtual parallelism operation
            if (decoded_instruction_DSP(KDOTP_bit_position)    = '1'  or
                decoded_instruction_DSP(KDOTPPS_bit_position)  = '1'  or
                decoded_instruction_DSP(KVRED_bit_position)    = '1'  or
                decoded_instruction_DSP(KSVMULRF_bit_position) = '1'  or
                decoded_instruction_DSP(KVMUL_bit_position)    = '1'  or
                decoded_instruction_DSP(KSVMULSC_bit_position) = '1') and
                MVTYPE(3 downto 2) = "00" then
              SIMD_RD_BYTES_wire <= SIMD*(Data_Width/8)/2;
            end if; 

          when dsp_exec =>

           -- Set signals to enable correct virtual parallelism operation
            if (decoded_instruction_DSP_lat(KDOTP_bit_position)    = '1'  or
                decoded_instruction_DSP_lat(KDOTPPS_bit_position)  = '1'  or
                decoded_instruction_DSP_lat(KVRED_bit_position)    = '1'  or
                decoded_instruction_DSP_lat(KSVMULRF_bit_position) = '1'  or
                decoded_instruction_DSP_lat(KVMUL_bit_position)    = '1'  or
                decoded_instruction_DSP_lat(KSVMULSC_bit_position) = '1') and
                MVTYPE_DSP = "00" then
              SIMD_RD_BYTES_wire <= SIMD*(Data_Width/8)/2;
            end if; 

            if decoded_instruction_DSP_lat(KDOTP_bit_position)   = '1' or 
               decoded_instruction_DSP_lat(KDOTPPS_bit_position) = '1' or
               decoded_instruction_DSP_lat(KVRED_bit_position)   = '1' then
              dsp_sc_data_write_wire_int(31 downto 0) <= dsp_out_accum_results;  -- AAA add a mask in order to store the lower half word when 16-bit or entire word when 32-bit
            end if;

            if (decoded_instruction_DSP_lat(KVMUL_bit_position)    = '1'  or  
                decoded_instruction_DSP_lat(KSVMULRF_bit_position) = '1'  or  
                decoded_instruction_DSP_lat(KSVMULSC_bit_position) = '1') and
                MVTYPE_DSP = "00" then
              for i in 0 to 2*SIMD-1 loop
                dsp_sc_data_write_wire_int(7+8*(i) downto 8*(i)) <= dsp_out_mul_results(7+8*(2*i) downto 8*(2*i));
              end loop;
            end if;

            if (decoded_instruction_DSP_lat(KVMUL_bit_position)    = '1'  or  
                decoded_instruction_DSP_lat(KSVMULRF_bit_position) = '1'  or  
                decoded_instruction_DSP_lat(KSVMULSC_bit_position) = '1') and
               (MVTYPE_DSP = "01" or MVTYPE_DSP = "10") then
              dsp_sc_data_write_wire_int <= dsp_out_mul_results;
            end if;

            if decoded_instruction_DSP_lat(KSRAV_bit_position)   = '1' or
               decoded_instruction_DSP_lat(KSRLV_bit_position)   = '1' then
              dsp_sc_data_write_wire_int  <= dsp_out_shifter_results;
            end if;

            if decoded_instruction_DSP_lat(KSVADDSC_bit_position)   = '1' or
               decoded_instruction_DSP_lat(KSVADDRF_bit_position)   = '1' or
               decoded_instruction_DSP_lat(KADDV_bit_position)      = '1' or
               decoded_instruction_DSP_lat(KSUBV_bit_position)      = '1' or
               decoded_instruction_DSP_lat(KVCP_bit_position)        = '1' then
              dsp_sc_data_write_wire_int <= dsp_out_adder_results;
            end if;


            if decoded_instruction_DSP_lat(KRELU_bit_position)  = '1' or
               decoded_instruction_DSP_lat(KVSLT_bit_position)  = '1' or
               decoded_instruction_DSP_lat(KSVSLT_bit_position) = '1' then
              dsp_sc_data_write_wire_int <= dsp_out_cmp_results;
            end if;

            if decoded_instruction_DSP_lat(KBCAST_bit_position) = '1' and MVTYPE_DSP = "10" then
              for i in 0 to SIMD-1 loop
                dsp_sc_data_write_wire_int(31+32*(i) downto 32*(i)) <= RS1_Data_IE_lat;
              end loop;
            elsif decoded_instruction_DSP_lat(KBCAST_bit_position) = '1' and MVTYPE_DSP = "01" then
              for i in 0 to 2*SIMD-1 loop
                dsp_sc_data_write_wire_int(15+16*(i) downto 16*(i)) <= RS1_Data_IE_lat(15 downto 0);
              end loop;
            elsif decoded_instruction_DSP_lat(KBCAST_bit_position)  = '1' and MVTYPE_DSP = "00" then
              for i in 0 to 4*SIMD-1 loop
                dsp_sc_data_write_wire_int(7+8*(i)   downto 8*(i))  <= RS1_Data_IE_lat(7 downto 0);
              end loop;
            end if;

            if halt_dsp = '0' and halt_dsp_lat = '1' then
              dsp_sc_data_write_wire <= dsp_sc_data_write_int;
            end if;
          when others =>
            null;
        end case;
      end if;
  end process;
end architecture DSP_Mapping_Multithread_Out_Mapper_arch;