-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Mapping_IN_Unit_Multithread is
    generic (
        SIMD                  : natural;
        --------------------------------
        SIMD_Width            : natural
    );
    port(
        -- ID_Stage Signals
        dsp_instr_req                   : in  std_logic;
        -- Scratchpad Interface Signals
        dsp_sc_data_read                : in  array_2d_dsp_operands(1 downto 0);
        -- input from DSP_pipeline_controller
        busy_DSP_internal_lat           : in std_logic;
        state_DSP                       : in std_logic_vector(1 downto 0);
        -- input from DSP_Exec_Unit
        decoded_instruction_DSP_lat     : in std_logic_vector(DSP_UNIT_INSTR_SET_SIZE -1 downto 0);
        dsp_sc_data_read_mask           : in std_logic_vector(SIMD_Width-1 downto 0);
        vec_read_rs2_DSP                : in std_logic;  -- Indicates whether the operand being read is a vector or a scalar
        MVTYPE_DSP                      : in std_logic_vector(1 downto 0);
        MPSCLFAC_DSP                    : in std_logic_vector(4 downto 0);
        dotp                            : in std_logic;  -- indicator used in the pipeline handler to switch functional units
        dotpps                          : in std_logic;  -- indicator used in the pipeline handler to switch functional units
        rf_rs2                          : in std_logic;
        RS2_Data_IE_lat                 : in std_logic_vector(31 downto 0);
        -- input from multiplier stage 2
        dsp_out_mul_results             : in std_logic_vector(SIMD_Width-1 downto 0);
        -- input from shifter stage 2
        dsp_out_shifter_results         : in std_logic_vector(SIMD_Width-1 downto 0);
        -- input from adder stage 2
        dsp_out_adder_results           : in std_logic_vector(SIMD_Width-1 downto 0);

        -- output for ACCUMULATOR
        dsp_in_accum_operands           : out std_logic_vector(SIMD_Width-1 downto 0);
        -- output for adder 
        MSB_stage_1                     : out array_2d_MSB_stage(1 downto 0);
        dsp_in_adder_operands           : out array_2d_dsp_operands(1 downto 0);
        -- output for shifter
        dsp_in_shift_amount             : out std_logic_vector(4 downto 0);
        dsp_in_shifter_operand          : out std_logic_vector(SIMD_Width-1 downto 0);
        -- output for comparator
        dsp_in_cmp_operands             : out std_logic_vector(SIMD_Width-1 downto 0);
        -- output for multiplier stage 1
        dsp_in_mul_operands             : out array_2d_dsp_operands(1 downto 0)
    );
end entity DSP_Mapping_IN_Unit_Multithread;

architecture DSP_Mapping_IN_Unit_Multithread_arch of DSP_Mapping_IN_Unit_Multithread is
begin
DSP_MAPPING_IN_UNIT_comb : process(all)
  begin

    MSB_stage_1                    <= (others => (others => '0')); 
    dsp_in_mul_operands            <= (others => (others => '0'));
    dsp_in_adder_operands          <= (others => (others => '0'));
    dsp_in_shift_amount            <= (others => '0');
    dsp_in_shifter_operand         <= (others => '0');
    dsp_in_accum_operands          <= (others => '0');
    dsp_in_cmp_operands            <= (others => '0');

    if dsp_instr_req = '1' or busy_DSP_internal_lat = '1' then
      case state_DSP is

        when dsp_exec =>

          if (decoded_instruction_DSP_lat(KDOTP_bit_position)   = '1' or 
              decoded_instruction_DSP_lat(KDOTPPS_bit_position) = '1') and
              MVTYPE_DSP = "00" then
            for i in 0 to 2*SIMD-1 loop
                dsp_in_mul_operands(0)(15+16*(i) downto 16*(i)) <= (x"00" & (dsp_sc_data_read(0)(7+8*(i) downto 8*(i)) and dsp_sc_data_read_mask(7+8*(i) downto 8*(i))));
                dsp_in_mul_operands(1)(15+16*(i) downto 16*(i)) <= (x"00" & (dsp_sc_data_read(1)(7+8*(i) downto 8*(i)) and dsp_sc_data_read_mask(7+8*(i) downto 8*(i))));
              if dotp = '1' then
                dsp_in_accum_operands <= dsp_out_mul_results;
              elsif dotpps = '1' then
                dsp_in_shift_amount    <= MPSCLFAC_DSP;
                dsp_in_shifter_operand <= dsp_out_mul_results;
                dsp_in_accum_operands  <= dsp_out_shifter_results;
              end if;
            end loop;
          end if;

          if (decoded_instruction_DSP_lat(KDOTP_bit_position)   = '1'  or
              decoded_instruction_DSP_lat(KDOTPPS_bit_position) = '1') and
              (MVTYPE_DSP = "01" or MVTYPE_DSP = "10") then
            dsp_in_mul_operands(0) <= dsp_sc_data_read(0) and dsp_sc_data_read_mask;
            dsp_in_mul_operands(1) <= dsp_sc_data_read(1) and dsp_sc_data_read_mask;
            if dotp = '1' then
              dsp_in_accum_operands  <= dsp_out_mul_results;
            elsif dotpps = '1' then
              dsp_in_shift_amount    <= MPSCLFAC_DSP;
              dsp_in_shifter_operand <= dsp_out_mul_results;
              dsp_in_accum_operands  <= dsp_out_shifter_results;
            end if;
          end if;

          if (decoded_instruction_DSP_lat(KVMUL_bit_position)    = '1'  or  
              decoded_instruction_DSP_lat(KSVMULRF_bit_position) = '1'  or  
              decoded_instruction_DSP_lat(KSVMULSC_bit_position) = '1') and
              MVTYPE_DSP = "00" then
            for i in 0 to 2*SIMD-1 loop
              if vec_read_rs2_DSP = '0' then
                if rf_rs2 = '1' then
                  dsp_in_mul_operands(1)(15+16*(i) downto 16*(i)) <= x"00" & RS2_Data_IE_lat(7 downto 0); -- map the scalar value
                elsif rf_rs2 = '0' then
                  dsp_in_mul_operands(1)(15+16*(i) downto 16*(i)) <= x"00" & dsp_sc_data_read(1)(7 downto 0); -- map the scalar value
                end if;
              else
                dsp_in_mul_operands(1)(15+16*(i) downto 16*(i)) <= x"00" & dsp_sc_data_read(1)(7+8*(i) downto 8*(i));
              end if;
              dsp_in_mul_operands(0)(15+16*(i) downto 16*(i))  <= x"00" & dsp_sc_data_read(0)(7+8*(i) downto 8*(i));
            end loop;
          end if;

          if (decoded_instruction_DSP_lat(KVMUL_bit_position)    = '1'  or  
              decoded_instruction_DSP_lat(KSVMULRF_bit_position) = '1'  or  
              decoded_instruction_DSP_lat(KSVMULSC_bit_position) = '1') and
              MVTYPE_DSP = "01" then
            if vec_read_rs2_DSP = '0' then
              if rf_rs2 = '1' then
                for i in 0 to 2*SIMD-1 loop
                  dsp_in_mul_operands(1)(15+16*(i) downto 16*(i)) <= RS2_Data_IE_lat(15 downto 0); -- map the scalar value
                end loop;
              elsif rf_rs2 = '0' then
                for i in 0 to 2*SIMD-1 loop
                  dsp_in_mul_operands(1)(15+16*(i) downto 16*(i)) <= dsp_sc_data_read(1)(15 downto 0); -- map the scalar value
                end loop;         
              end if;
            else
              dsp_in_mul_operands(1) <= dsp_sc_data_read(1);
            end if;
            dsp_in_mul_operands(0)     <= dsp_sc_data_read(0);
          end if;

          if (decoded_instruction_DSP_lat(KVMUL_bit_position)    = '1'  or  
              decoded_instruction_DSP_lat(KSVMULRF_bit_position) = '1'  or  
              decoded_instruction_DSP_lat(KSVMULSC_bit_position) = '1') and
              MVTYPE_DSP = "10" then
            if vec_read_rs2_DSP = '0' then
              if rf_rs2 = '1' then
                for i in 0 to SIMD-1 loop
                  dsp_in_mul_operands(1)(31+32*(i) downto 32*(i)) <= RS2_Data_IE_lat(31 downto 0); -- map the scalar value
                end loop;
              elsif rf_rs2 = '0' then
                for i in 0 to SIMD-1 loop
                  dsp_in_mul_operands(1)(31+32*(i) downto 32*(i)) <= dsp_sc_data_read(1)(31 downto 0); -- map the scalar value
                end loop;
              end if;
            else
              dsp_in_mul_operands(1) <= dsp_sc_data_read(1);
            end if;
            dsp_in_mul_operands(0) <= dsp_sc_data_read(0);
          end if;

          if decoded_instruction_DSP_lat(KADDV_bit_position) = '1' then 
            dsp_in_adder_operands(0)   <= dsp_sc_data_read(0);
            dsp_in_adder_operands(1)   <= dsp_sc_data_read(1);
          end if;

          if decoded_instruction_DSP_lat(KSRAV_bit_position) = '1' or
              decoded_instruction_DSP_lat(KSRLV_bit_position) = '1' then 
            dsp_in_shifter_operand      <= dsp_sc_data_read(0);
            dsp_in_shift_amount         <= RS2_Data_IE_lat(4 downto 0); -- map the scalar value (shift amount)
          end if;

          if decoded_instruction_DSP_lat(KSVADDSC_bit_position)  = '1' and MVTYPE_DSP = "10" then
            dsp_in_adder_operands(0)   <= dsp_sc_data_read(0);
            for i in 0 to SIMD-1 loop
              dsp_in_adder_operands(1)(31+32*(i) downto 32*(i))   <= dsp_sc_data_read(1)(31 downto 0);
            end loop;
          end if;

          if decoded_instruction_DSP_lat(KSVADDSC_bit_position)  = '1' and MVTYPE_DSP = "01" then
            dsp_in_adder_operands(0)   <= dsp_sc_data_read(0);
            for i in 0 to 2*SIMD-1 loop
              dsp_in_adder_operands(1)(15+16*(i) downto 16*(i))   <= dsp_sc_data_read(1)(15 downto 0);
            end loop;
          end if;

          if decoded_instruction_DSP_lat(KSVADDSC_bit_position)  = '1' and MVTYPE_DSP = "00" then
            dsp_in_adder_operands(0) <= dsp_sc_data_read(0);
            for i in 0 to 4*SIMD-1 loop
              dsp_in_adder_operands(1)(7+8*(i) downto 8*(i)) <= dsp_sc_data_read(1)(7 downto 0);
            end loop;
          end if;

          if decoded_instruction_DSP_lat(KSVADDRF_bit_position) = '1' and MVTYPE_DSP = "10" then
            dsp_in_adder_operands(0)   <= dsp_sc_data_read(0);
            for i in 0 to SIMD-1 loop
              dsp_in_adder_operands(1)(31+32*(i) downto 32*(i))   <= RS2_Data_IE_lat(31 downto 0);
            end loop;
          end if;

          if decoded_instruction_DSP_lat(KSVADDRF_bit_position) = '1' and MVTYPE_DSP = "01" then
            dsp_in_adder_operands(0)   <= dsp_sc_data_read(0);
            for i in 0 to 2*SIMD-1 loop
              dsp_in_adder_operands(1)(15+16*(i) downto 16*(i))   <= RS2_Data_IE_lat(15 downto 0);
            end loop;
          end if;

          if decoded_instruction_DSP_lat(KSVADDRF_bit_position) = '1' and MVTYPE_DSP = "00" then
            dsp_in_adder_operands(0)   <= dsp_sc_data_read(0);
            for i in 0 to 4*SIMD-1 loop
              dsp_in_adder_operands(1)(7+8*(i) downto 8*(i))   <= RS2_Data_IE_lat(7 downto 0);
            end loop;
          end if;

          if decoded_instruction_DSP_lat(KSUBV_bit_position)  = '1' then
            dsp_in_adder_operands(0) <= dsp_sc_data_read(0);
            dsp_in_adder_operands(1) <= (not dsp_sc_data_read(1));
          end if;

          if decoded_instruction_DSP_lat(KVRED_bit_position)  = '1' and MVTYPE_DSP = "00" then
            for i in 0 to 2*SIMD-1 loop
              dsp_in_accum_operands(15+16*(i) downto 16*(i)) <= x"00" & (dsp_sc_data_read(0)(7+8*(i) downto 8*(i)) and dsp_sc_data_read_mask(7+8*(i) downto 8*(i)));
            end loop;
          end if;
          if decoded_instruction_DSP_lat(KVRED_bit_position) = '1' and (MVTYPE_DSP = "01" or MVTYPE_DSP = "10") then
            dsp_in_accum_operands <= dsp_sc_data_read(0) and dsp_sc_data_read_mask;
          end if;

          if decoded_instruction_DSP_lat(KRELU_bit_position)  = '1' then
            dsp_in_cmp_operands <= dsp_sc_data_read(0);
          end if;

          if decoded_instruction_DSP_lat(KVSLT_bit_position) = '1' then
            dsp_in_adder_operands(0) <= dsp_sc_data_read(0);
            dsp_in_adder_operands(1) <= (not dsp_sc_data_read(1));
            dsp_in_cmp_operands      <= dsp_out_adder_results;
            for i in 0 to 1 loop -- loops through both read busses for operands rs1, and rs2
              for j in 0 to 4*SIMD-1 loop -- loop transfers all the MSBs from the input to the output
                MSB_stage_1(i)(j) <= dsp_sc_data_read(i)(7+8*(j));
              end loop;
            end loop;
          end if;

          if decoded_instruction_DSP_lat(KSVSLT_bit_position) = '1'then
            dsp_in_adder_operands(0) <= dsp_sc_data_read(0);
            dsp_in_cmp_operands      <= dsp_out_adder_results;
            if MVTYPE_DSP = "10" then
              for i in 0 to SIMD-1 loop
                dsp_in_adder_operands(1)(31+32*(i) downto 32*(i)) <= not(RS2_Data_IE_lat(31 downto 0));
              end loop;
              for j in 0 to SIMD-1 loop -- this index loops throughout the SIMD lanes
                MSB_stage_1(1)(4*(j)+3) <= RS2_Data_IE_lat(31); -- Save the MSB in an array to be used for comparator results
              end loop;
            elsif MVTYPE_DSP = "01" then
              for i in 0 to 2*SIMD-1 loop
                dsp_in_adder_operands(1)(15+16*(i) downto 16*(i)) <= not(RS2_Data_IE_lat(15 downto 0));
              end loop;
              for i in 0 to 1 loop -- this index loops throughout the MSBs in the 8-bit subwords in the 32-bit word "RS2_Data_IE_lat"
                for j in 0 to SIMD-1 loop -- this index loops throughout the SIMD lanes
                  MSB_stage_1(1)(4*(j)+1+2*(i)) <= RS2_Data_IE_lat(15); -- Save the MSB in an array to be used for comparator results
                end loop;
              end loop;
            elsif MVTYPE_DSP = "00" then
              for i in 0 to 4*SIMD-1 loop
                dsp_in_adder_operands(1)(7+8*(i)   downto 8*(i))  <= not(RS2_Data_IE_lat(7 downto 0));
              end loop;
              for i in 0 to 3 loop -- this index loops throughout the MSBs in the 8-bit subwords in the 32-bit word "RS2_Data_IE_lat"
                for j in 0 to SIMD-1 loop -- this index loops throughout the SIMD lanes
                  MSB_stage_1(1)(4*(j)+i) <= RS2_Data_IE_lat(7); -- Save the MSB in an array to be used for comparator results
                end loop;
              end loop;
            end if;
            for i in 0 to 4*SIMD-1 loop -- loop transfers all the MSBs from the input to the output
              MSB_stage_1(0)(i) <= dsp_sc_data_read(0)(7+8*(i));
            end loop;
          end if;

          if decoded_instruction_DSP_lat(KVCP_bit_position) = '1' then
            dsp_in_adder_operands(0) <= dsp_sc_data_read(0);
          end if;

        when others =>
          null;
      end case;
    end if;
  end process;
end architecture DSP_Mapping_IN_Unit_Multithread_arch;
