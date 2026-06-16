-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Shifters_comb is
  generic(
    SIMD                  : natural;
    --------------------------------
    SIMD_Width            : natural
  );
  port(
    -- inputs from DSP_pipeline_controller
    halt_dsp_lat                    : in std_logic;
    -- inputs from DSP_Exec_Unit
    MVTYPE_DSP                      : in std_logic_vector(1 downto 0);
    decoded_instruction_DSP_lat     : in std_logic_vector(DSP_UNIT_INSTR_SET_SIZE -1 downto 0);
    -- inputs from DSP_FU_Handler
    shift_en                        : in std_logic;  -- enables the use of the shifters
    -- inputs from DSP_Mapping
    dsp_in_shift_amount             : in std_logic_vector(4 downto 0);
    -- inputs from Shifter
    dsp_in_shifter_operand_lat      : in std_logic_vector(SIMD_Width-1 downto 0);

    -- outputs for shifter
    dsp_in_shifter_operand_lat_wire : out std_logic_vector(SIMD_Width-1 downto 0);
    dsp_shift_enabler               : out std_logic_vector(15 downto 0)
  );
end entity DSP_Shifters_comb;

architecture DSP_Shifters_comb_arch of DSP_Shifters_comb is
begin
fsm_DSP_shifter_comb : process(all)
  begin
    dsp_in_shifter_operand_lat_wire <= (others => '0');
    dsp_shift_enabler <= (others => '0');
    if shift_en = '1' and halt_dsp_lat = '0' then
      if MVTYPE_DSP = "01" then
        for i in 0 to dsp_shift_enabler'length - 1 loop
          if i < 15 - to_integer(unsigned(dsp_in_shift_amount(3 downto 0))) then
            dsp_shift_enabler(i) <= '1';
          else
            dsp_shift_enabler(i) <= '0';
          end if;
        end loop;
        --dsp_shift_enabler(15 - to_integer(unsigned(dsp_in_shift_amount(3 downto 0))) downto 0) <= (others => '1');
      elsif MVTYPE_DSP = "00" then
        for i in 0 to dsp_shift_enabler'length - 1 loop
          if i < 7 - to_integer(unsigned(dsp_in_shift_amount(2 downto 0))) then
            dsp_shift_enabler(i) <= '1';
          else
            dsp_shift_enabler(i) <= '0';
          end if;
        end loop;
        --dsp_shift_enabler(7 -  to_integer(unsigned(dsp_in_shift_amount(2 downto 0))) downto 0) <= (others => '1');
      end if;
      if (decoded_instruction_DSP_lat(KSRAV_bit_position) = '1' or decoded_instruction_DSP_lat(KDOTPPS_bit_position) = '1') and
          MVTYPE_DSP = "10" then    -- 32-bit sign extension for for srl in stage 1
        for i in 0 to SIMD-1 loop
          --dsp_in_shifter_operand_lat(31+32*(i) downto 31 - to_integer(unsigned(dsp_in_shift_amount(4 downto 0)))+32*(i))   <= (others => dsp_in_sign_bits(3+4*(i)));
          for j in 0 to 31 loop
            if j >= 31 - to_integer(unsigned(dsp_in_shift_amount(4 downto 0))) then
              dsp_in_shifter_operand_lat_wire(j+32*(i)) <= dsp_in_shifter_operand_lat(j+32*(i));
            end if;
          end loop;
            
          --dsp_in_shifter_operand_lat_wire(31+32*(i) downto 31 - to_integer(unsigned(dsp_in_shift_amount(4 downto 0)))+32*(i)) <= 
          --dsp_in_shifter_operand_lat(     31+32*(i) downto 31 - to_integer(unsigned(dsp_in_shift_amount(4 downto 0)))+32*(i));
        end loop;
      elsif (decoded_instruction_DSP_lat(KSRAV_bit_position) = '1' or decoded_instruction_DSP_lat(KDOTPPS_bit_position) = '1') and
              MVTYPE_DSP = "01" then -- 16-bit sign extension for for srl in stage 1
        for i in 0 to 2*SIMD-1 loop
          --dsp_in_shifter_operand_lat(15+16*(i) downto 15 - to_integer(unsigned(dsp_in_shift_amount(3 downto 0)))+16*(i))   <= (others => dsp_in_sign_bits(1+2*(i)));
          for j in 0 to 15 loop
            if j >= 15 - to_integer(unsigned(dsp_in_shift_amount(3 downto 0))) then
              dsp_in_shifter_operand_lat_wire(j+16*(i)) <= dsp_in_shifter_operand_lat(j+16*(i));
            end if;
          end loop;

          --dsp_in_shifter_operand_lat_wire(15+16*(i) downto 15 - to_integer(unsigned(dsp_in_shift_amount(3 downto 0)))+16*(i)) <= 
          --dsp_in_shifter_operand_lat(     15+16*(i) downto 15 - to_integer(unsigned(dsp_in_shift_amount(3 downto 0)))+16*(i));
        end loop;
      elsif (decoded_instruction_DSP_lat(KSRAV_bit_position) = '1'  or decoded_instruction_DSP_lat(KDOTPPS_bit_position) = '1') and
              MVTYPE_DSP = "00" then  -- 8-bit  sign extension for for srl in stage 1
        for i in 0 to 4*SIMD-1 loop
          --dsp_in_shifter_operand_lat(7+8*(i) downto 7 - to_integer(unsigned(dsp_in_shift_amount(2 downto 0)))+8*(i))    <= (others => dsp_in_sign_bits(i));
          for j in 0 to 7 loop
            if j >= 7 - to_integer(unsigned(dsp_in_shift_amount(2 downto 0))) then
              dsp_in_shifter_operand_lat_wire(j+8*(i)) <= dsp_in_shifter_operand_lat(j+8*(i));
            end if;
          end loop;

          --dsp_in_shifter_operand_lat_wire(7+8*(i) downto 7 - to_integer(unsigned(dsp_in_shift_amount(2 downto 0)))+8*(i)) <= 
          --dsp_in_shifter_operand_lat(     7+8*(i) downto 7 - to_integer(unsigned(dsp_in_shift_amount(2 downto 0)))+8*(i));
        end loop;
      end if;
    end if;
  end process; 
end architecture DSP_Shifters_comb_arch;