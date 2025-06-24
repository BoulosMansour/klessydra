-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

-- local packages -----------------
use work.riscv_klessydra.all;
--use work.klessydra_parameters.all;

entity DSP_Excpt_Cntrl_unit is
    generic(
        THREAD_POOL_SIZE      : integer;
        Addr_Width            : natural;
        SPM_NUM               : natural;
        SIMD                  : natural;
        -----------------------------------
        SPM_ADDR_WID          : natural;
        SIMD_BITS             : natural
    );
    port(
      -- INPUTS
      RD_Data_IE_lat                  : in std_logic_vector(Addr_Width -1 downto 0);
      MVSIZE_WRITE                    : in std_logic_vector(Addr_Width downto 0);  -- Bytes remaining to write
      vec_read_rs2_DSP                : in std_logic;  -- Indicates whether the operand being read is a vector or a scalar
      vec_write_rd_DSP                : in std_logic;  -- Indicates whether the result being written is a vector or a scalar
      recover_state                   : in std_logic;
      dsp_rs1_to_sc                   : in std_logic_vector(SPM_ADDR_WID-1 downto 0);
      dsp_rs2_to_sc                   : in std_logic_vector(SPM_ADDR_WID-1 downto 0);
      dsp_rd_to_sc                    : in std_logic_vector(SPM_ADDR_WID-1 downto 0);
      RS1_Data_IE_lat                 : in std_logic_vector(31 downto 0);
      RS2_Data_IE_lat                 : in std_logic_vector(31 downto 0);
      MVSIZE_READ                     : in std_logic_vector(Addr_Width downto 0);  -- Bytes remaining to read
      accum_stage_3_en                : in std_logic;
      dsp_sci_wr_gnt                  : in std_logic;
      mul_stage_3_en                  : in std_logic;
      adder_stage_3_en                : in std_logic;
      dsp_except_data                 : in std_logic_vector(31 downto 0);
      busy_DSP_internal_lat           : in std_logic;
      state_DSP                       : in std_logic_vector(1 downto 0); -- tracer signals
      SIMD_RD_BYTES                   : in integer;
      rf_rs2                          : in std_logic;
      decoded_instruction_DSP_lat     : in std_logic_vector(DSP_UNIT_INSTR_SET_SIZE -1 downto 0);
      cmp_stage_2_en                  : in std_logic;
      shifter_stage_3_en              : in std_logic;
      rs1_to_sc                       : in std_logic_vector(SPM_ADDR_WID-1 downto 0);
      rs2_to_sc                       : in std_logic_vector(SPM_ADDR_WID-1 downto 0);
      rd_to_sc                        : in std_logic_vector(SPM_ADDR_WID-1 downto 0);
      MVSIZE                          : in array_2d(THREAD_POOL_SIZE-1 downto 0)(Addr_Width downto 0);
      MVTYPE                          : in array_2d(THREAD_POOL_SIZE-1 downto 0)(3 downto 0);
      harc_EXEC                       : in integer range THREAD_POOL_SIZE-1 downto 0;
      RS1_Data_IE                     : in std_logic_vector(31 downto 0);
      RS2_Data_IE                     : in std_logic_vector(31 downto 0);
      RD_Data_IE                      : in std_logic_vector(Addr_Width -1 downto 0);
      spm_rs1                         : in std_logic;
      spm_rs2                         : in std_logic;
      vec_read_rs1_ID                 : in std_logic;
      vec_read_rs2_ID                 : in std_logic;
      vec_write_rd_ID                 : in std_logic;
      dsp_instr_req                   : in std_logic;
      halt_hart                       : in std_logic; -- halts the thread when the requested functional unit is in use
  
      -- output signals
      nextstate_DSP                   : out std_logic_vector(1 downto 0);
      busy_dsp_internal               : out std_logic;
      wb_ready                        : out std_logic;
      dsp_sci_we                      : out std_logic_vector(SPM_NUM-1 downto 0);
      dsp_sc_write_addr               : out std_logic_vector(Addr_Width-1 downto 0);
      dsp_sc_read_addr                : out array_2d(1 downto 0)(Addr_Width-1 downto 0);
      dsp_sci_req                     : out std_logic_vector(SPM_NUM-1 downto 0);
      dsp_to_sc                       : out array_2d(SPM_NUM-1 downto 0)(1 downto 0);
      halt_dsp                        : out std_logic;
      recover_state_wires             : out std_logic;
      dsp_except_data_wire            : out std_logic_vector(31 downto 0);
      dsp_except_condition            : out std_logic;
      dsp_we_word                     : out std_logic_vector(SIMD-1 downto 0);
      dsp_taken_branch                : out std_logic   
    );
end entity DSP_Excpt_Cntrl_unit;

architecture DSP_Excpt_Cntrl_unit_arch of DSP_Excpt_Cntrl_unit is
  signal overflow_rs1_sc                 : std_logic_vector(Addr_Width downto 0);
  signal overflow_rs2_sc                 : std_logic_vector(Addr_Width downto 0);
  signal overflow_rd_sc                  : std_logic_vector(Addr_Width downto 0);
  
begin
------------ Combinational Stage of DSP Unit ----------------------------------------------------------------------
  DSP_Excpt_Cntrl_Unit_comb : process(all)

  variable busy_DSP_internal_wires : std_logic;
  variable dsp_except_condition_wires : std_logic;
  variable dsp_taken_branch_wires : std_logic; 

  -- variable overflow_rs1_sc                 : std_logic_vector(Addr_Width downto 0);
  -- variable overflow_rs2_sc                 : std_logic_vector(Addr_Width downto 0);
  -- variable overflow_rd_sc                  : std_logic_vector(Addr_Width downto 0);
      
  begin

    busy_DSP_internal_wires     := '0';  -- common internal, can be replaced with busy_DSP_internal_wires
    dsp_except_condition_wires  := '0';  -- excpt handling out internal, can be replaced with dsp_except_condition_wires
    dsp_taken_branch_wires      := '0';  -- excpt handling out internal, can be repalced with dsp_taken_branch_wires
    wb_ready                    <= '0';  -- cntrl handling signal & output
    halt_dsp                    <= '0';  -- cntrl handling out
    nextstate_DSP               <= dsp_init; --common out
    recover_state_wires         <= recover_state; --cntrl handling out
    dsp_except_data_wire        <= dsp_except_data; --excpt handling out
    overflow_rs1_sc             <= (others => '0');  --excpt handling, can be an internal variable
    overflow_rs2_sc             <= (others => '0');  --excpt handling, can be an internal variable
    overflow_rd_sc              <= (others => '0');  --excpt handling, can be an internal variable
    dsp_we_word                 <= (others => '0');  --cntrl handling out
    dsp_sci_req                 <= (others => '0');  --common out
    dsp_sci_we                  <= (others => '0');  --cntrl handling out
    dsp_sc_write_addr           <= (others => '0');  --cntrl handling out
    dsp_sc_read_addr            <= (others => (others => '0'));  --common out
    dsp_to_sc                   <= (others => (others => '0'));  --common out

    if dsp_instr_req = '1' or busy_DSP_internal_lat = '1' then
      case state_DSP is

        when dsp_init =>

          ---------------------------------------------------------------------------------------------------------------------
          --  ███████╗██╗  ██╗ ██████╗██████╗ ████████╗    ██╗  ██╗ █████╗ ███╗   ██╗██████╗ ██╗     ██╗███╗   ██╗ ██████╗   --
          --  ██╔════╝╚██╗██╔╝██╔════╝██╔══██╗╚══██╔══╝    ██║  ██║██╔══██╗████╗  ██║██╔══██╗██║     ██║████╗  ██║██╔════╝   --
          --  █████╗   ╚███╔╝ ██║     ██████╔╝   ██║       ███████║███████║██╔██╗ ██║██║  ██║██║     ██║██╔██╗ ██║██║  ███╗  --
          --  ██╔══╝   ██╔██╗ ██║     ██╔═══╝    ██║       ██╔══██║██╔══██║██║╚██╗██║██║  ██║██║     ██║██║╚██╗██║██║   ██║  -- 
          --  ███████╗██╔╝ ██╗╚██████╗██║        ██║       ██║  ██║██║  ██║██║ ╚████║██████╔╝███████╗██║██║ ╚████║╚██████╔╝  --
          --  ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝        ╚═╝       ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝   --
          ---------------------------------------------------------------------------------------------------------------------

          overflow_rs1_sc <= std_logic_vector('0' & unsigned(RS1_Data_IE(Addr_Width -1 downto 0)) + unsigned(MVSIZE(harc_EXEC)) -1);
          overflow_rs2_sc <= std_logic_vector('0' & unsigned(RS2_Data_IE(Addr_Width -1 downto 0)) + unsigned(MVSIZE(harc_EXEC)) -1);
          overflow_rd_sc  <= std_logic_vector('0' & unsigned(RD_Data_IE(Addr_Width  -1 downto 0)) + unsigned(MVSIZE(harc_EXEC)) -1);
          if MVSIZE(harc_EXEC) = (0 to Addr_Width => '0') then
            null;
          elsif MVSIZE(harc_EXEC)(1 downto 0) /= "00" and MVTYPE(harc_EXEC)(3 downto 2) = "10" then  -- Set exception if the number of bytes are not divisible by four
            dsp_except_condition_wires := '1';
            dsp_taken_branch_wires     := '1';    
            dsp_except_data_wire <= ILLEGAL_VECTOR_SIZE_EXCEPT_CODE;
          elsif MVSIZE(harc_EXEC)(0) /= '0' and MVTYPE(harc_EXEC)(3 downto 2) = "01" then            -- Set exception if the number of bytes are not divisible by two
            dsp_except_condition_wires := '1';
            dsp_taken_branch_wires     := '1';
            dsp_except_data_wire <= ILLEGAL_VECTOR_SIZE_EXCEPT_CODE;
          elsif (rs1_to_sc  = "100" and vec_read_rs1_ID = '1') or
            (rs2_to_sc  = "100" and vec_read_rs2_ID = '1') or
             rd_to_sc   = "100" then     -- Set exception for non scratchpad access
            dsp_except_condition_wires := '1';
            dsp_taken_branch_wires     := '1';    
            dsp_except_data_wire <= ILLEGAL_ADDRESS_EXCEPT_CODE;
          elsif rs1_to_sc = rs2_to_sc and vec_read_rs1_ID = '1' and vec_read_rs2_ID = '1' then               -- Set exception for same read access
            dsp_except_condition_wires := '1';
            dsp_taken_branch_wires     := '1';    
            dsp_except_data_wire <= READ_SAME_SCARTCHPAD_EXCEPT_CODE;    
          elsif (overflow_rs1_sc(Addr_Width) = '1' and vec_read_rs1_ID = '1') or (overflow_rs2_sc(Addr_Width) = '1' and  vec_read_rs2_ID = '1') then -- Set exception if reading overflows the scratchpad's address
            dsp_except_condition_wires := '1';
            dsp_taken_branch_wires     := '1';    
            dsp_except_data_wire <= SCRATCHPAD_OVERFLOW_EXCEPT_CODE;
          elsif overflow_rd_sc(Addr_Width) = '1'  and vec_write_rd_ID = '1' then           -- Set exception if reading overflows the scratchpad's address, scalar writes are excluded
            dsp_except_condition_wires := '1';
            dsp_taken_branch_wires     := '1';    
            dsp_except_data_wire <= SCRATCHPAD_OVERFLOW_EXCEPT_CODE;
          else
            if halt_hart = '0' then
              nextstate_DSP <= dsp_exec;
            else
              nextstate_DSP <= dsp_halt_hart;
            end if;
            busy_DSP_internal_wires := '1';
          end if;

          if rs1_to_sc /= "100" and spm_rs1 = '1' and halt_hart = '0' then
            dsp_sci_req(to_integer(unsigned(rs1_to_sc))) <= '1';
            dsp_to_sc(to_integer(unsigned(rs1_to_sc)))(0) <= '1';
            dsp_sc_read_addr(0) <= RS1_Data_IE(Addr_Width-1 downto 0);
          end if;
          if rs2_to_sc /= "100" and spm_rs2 = '1' and rs1_to_Sc /= rs2_to_sc and halt_hart = '0' then   -- Do not send a read request if the second operand accesses the same spm as the first, 
            dsp_sci_req(to_integer(unsigned(rs2_to_sc))) <= '1';
            dsp_to_sc(to_integer(unsigned(rs2_to_sc)))(1) <= '1';
            dsp_sc_read_addr(1) <= RS2_Data_IE(Addr_Width-1 downto 0);
          end if;
        
         when dsp_halt_hart =>

           if halt_hart = '0' then
             nextstate_DSP <= dsp_exec;
           else
             nextstate_DSP <= dsp_halt_hart;
           end if;
           busy_DSP_internal_wires := '1';

         when dsp_exec =>

           -----------------------------------------------------------------------------------------------------------------------
           --   ██████╗███╗   ██╗████████╗██████╗ ██╗         ██╗  ██╗ █████╗ ███╗   ██╗██████╗ ██╗     ██╗███╗   ██╗ ██████╗   --
           --  ██╔════╝████╗  ██║╚══██╔══╝██╔══██╗██║         ██║  ██║██╔══██╗████╗  ██║██╔══██╗██║     ██║████╗  ██║██╔════╝   --
           --  ██║     ██╔██╗ ██║   ██║   ██████╔╝██║         ███████║███████║██╔██╗ ██║██║  ██║██║     ██║██╔██╗ ██║██║  ███╗  --
           --  ██║     ██║╚██╗██║   ██║   ██╔══██╗██║         ██╔══██║██╔══██║██║╚██╗██║██║  ██║██║     ██║██║╚██╗██║██║   ██║  --
           --  ╚██████╗██║ ╚████║   ██║   ██║  ██║███████╗    ██║  ██║██║  ██║██║ ╚████║██████╔╝███████╗██║██║ ╚████║╚██████╔╝  --
           --   ╚═════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝╚══════╝    ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝   --
           -----------------------------------------------------------------------------------------------------------------------

           ------ SMP BANK ENABLER --------------------------------------------------------------------------------------------------
           -- the following enables the appropriate banks to write the SIMD output, depending whether the result is a vector or a  --
           -- scalar, and adjusts the enabler appropriately based on the SIMD size. If the bytes to write are greater than SIMD*4  --
           -- then all banks are enabaled, else we perform the selective bank enabling as shown below under the 'elsif' clause     --
           --------------------------------------------------------------------------------------------------------------------------

           if (dsp_sci_wr_gnt = '0' and wb_ready = '1') then
             halt_dsp <= '1';
             recover_state_wires <= '1';
           elsif unsigned(MVSIZE_WRITE) <= SIMD_RD_BYTES then
             recover_state_wires <= '0';
           end if;

           if vec_write_rd_DSP = '1' and  dsp_sci_we(to_integer(unsigned(dsp_rd_to_sc))) = '1' then
             if unsigned(MVSIZE_WRITE) >= (SIMD)*4+1 then  -- 
               dsp_we_word <= (others => '1');
             elsif  unsigned(MVSIZE_WRITE) >= 1 then
               for i in 0 to SIMD-1 loop
                 if i <= to_integer(unsigned(MVSIZE_WRITE)-1)/4 then -- Four because of the number of bytes per word
                   if to_integer(unsigned(dsp_sc_write_addr(SIMD_BITS+1 downto 0))/4 + i) < SIMD then
                     dsp_we_word(to_integer(unsigned(dsp_sc_write_addr(SIMD_BITS+1 downto 0))/4 + i)) <= '1';
                   elsif to_integer(unsigned(dsp_sc_write_addr(SIMD_BITS+1 downto 0))/4 + i) >= SIMD then
                     dsp_we_word(to_integer(unsigned(dsp_sc_write_addr(SIMD_BITS+1 downto 0))/4 + i - SIMD)) <= '1';
                   end if;
                 end if;
               end loop;
             end if;
           elsif vec_write_rd_DSP = '0' and  dsp_sci_we(to_integer(unsigned(dsp_rd_to_sc))) = '1' then
             dsp_we_word(to_integer(unsigned(dsp_sc_write_addr(SIMD_BITS+1 downto 0))/4)) <= '1';
           end if;
           -------------------------------------------------------------------------------------------------------------------------


           if decoded_instruction_DSP_lat(KBCAST_bit_position)  = '1' then
             -- KBCAST signals are handeled here
             if MVSIZE_WRITE > (0 to Addr_Width => '0') then
               nextstate_DSP <= dsp_exec;
               busy_DSP_internal_wires := '1';
             end if;
             wb_ready <= '1';
             dsp_sci_we(to_integer(unsigned(dsp_rd_to_sc))) <= '1';
             dsp_sc_write_addr <= RD_Data_IE_lat;
           end if;

           if decoded_instruction_DSP_lat(KVCP_bit_position)  = '1' then
             -- KVCP signals are handeled here
             if adder_stage_3_en = '1' then
               wb_ready <= '1';
             elsif recover_state = '1' then
               wb_ready <= '1';  
             end if;
             if MVSIZE_READ > (0 to Addr_Width => '0') then
               dsp_to_sc(to_integer(unsigned(dsp_rs1_to_sc)))(0) <= '1';
               dsp_sci_req(to_integer(unsigned(dsp_rs1_to_sc)))  <= '1';
               dsp_sc_read_addr(0) <= RS1_Data_IE_lat(Addr_Width - 1 downto 0);
             end if;
             if MVSIZE_WRITE > (0 to Addr_Width => '0') then
               nextstate_DSP <= dsp_exec;
               busy_DSP_internal_wires := '1';
             end if;
             if wb_ready = '1' then
               dsp_sci_we(to_integer(unsigned(dsp_rd_to_sc))) <= '1';
               dsp_sc_write_addr <= RD_Data_IE_lat;
             end if;
           end if;

           if decoded_instruction_DSP_lat(KRELU_bit_position) = '1' then
             -- KRELU signals are handeled here
             if cmp_stage_2_en = '1' then
               wb_ready <= '1';
             elsif recover_state = '1' then
               wb_ready <= '1';  
             end if;
             if MVSIZE_READ > (0 to Addr_Width => '0') then
               dsp_to_sc(to_integer(unsigned(dsp_rs1_to_sc)))(0) <= '1';
               dsp_sci_req(to_integer(unsigned(dsp_rs1_to_sc)))  <= '1';
               dsp_sc_read_addr(0) <= RS1_Data_IE_lat(Addr_Width - 1 downto 0);
             end if;
             if MVSIZE_WRITE > (0 to Addr_Width => '0') then
               nextstate_DSP <= dsp_exec;
               busy_DSP_internal_wires := '1';
             end if;
             if wb_ready = '1' then
               dsp_sci_we(to_integer(unsigned(dsp_rd_to_sc))) <= '1';
               dsp_sc_write_addr <= RD_Data_IE_lat;
             end if;
           end if;
            ---------------------------------------------------------------------------------------------------
           if decoded_instruction_DSP_lat(KVSLT_bit_position)  = '1' then  --combine with the next conditions
             -- KADDV and KSUBV signals are handeled here
             if cmp_stage_2_en = '1' then
               wb_ready <= '1';
             elsif recover_state = '1' then
               wb_ready <= '1';  
             end if;
             if MVSIZE_READ > (0 to Addr_Width => '0') then
               dsp_to_sc(to_integer(unsigned(dsp_rs1_to_sc)))(0) <= '1';
               dsp_to_sc(to_integer(unsigned(dsp_rs2_to_sc)))(1) <= '1';
               dsp_sci_req(to_integer(unsigned(dsp_rs1_to_sc)))  <= '1';
               dsp_sci_req(to_integer(unsigned(dsp_rs2_to_sc)))  <= '1';
               dsp_sc_read_addr(0)  <= RS1_Data_IE_lat(Addr_Width - 1 downto 0);
               dsp_sc_read_addr(1)  <= RS2_Data_IE_lat(Addr_Width - 1 downto 0);
             end if;
             if MVSIZE_WRITE > (0 to Addr_Width => '0') then
               nextstate_DSP <= dsp_exec;
               busy_DSP_internal_wires := '1';
             end if;
             if wb_ready = '1' then
               dsp_sci_we(to_integer(unsigned(dsp_rd_to_sc))) <= '1';
               dsp_sc_write_addr <= RD_Data_IE_lat;
             end if;
           end if;

           if decoded_instruction_DSP_lat(KSVSLT_bit_position) = '1' then
             -- KADDV and KSUBV signals are handeled here
             if cmp_stage_2_en = '1' then
               wb_ready <= '1';
             elsif recover_state = '1' then
               wb_ready <= '1';  
             end if;
             if MVSIZE_READ > (0 to Addr_Width => '0') then
               dsp_to_sc(to_integer(unsigned(dsp_rs1_to_sc)))(0) <= '1';
               dsp_sci_req(to_integer(unsigned(dsp_rs1_to_sc)))  <= '1';
               dsp_sc_read_addr(0)  <= RS1_Data_IE_lat(Addr_Width - 1 downto 0);
             end if;
             if MVSIZE_WRITE > (0 to Addr_Width => '0') then
               nextstate_DSP <= dsp_exec;
               busy_DSP_internal_wires := '1';
             end if;
             if wb_ready = '1' then
               dsp_sci_we(to_integer(unsigned(dsp_rd_to_sc))) <= '1';
               dsp_sc_write_addr <= RD_Data_IE_lat;
             end if;
           end if;

           if decoded_instruction_DSP_lat(KADDV_bit_position)  = '1' or
              decoded_instruction_DSP_lat(KSUBV_bit_position)  = '1' then
             -- KADDV and KSUBV signals are handeled here
             if adder_stage_3_en = '1' then
               wb_ready <= '1';
             elsif recover_state = '1' then
               wb_ready <= '1';  
             end if;
             if MVSIZE_READ > (0 to Addr_Width => '0') then
               dsp_to_sc(to_integer(unsigned(dsp_rs1_to_sc)))(0) <= '1';
               dsp_to_sc(to_integer(unsigned(dsp_rs2_to_sc)))(1) <= '1';
               dsp_sci_req(to_integer(unsigned(dsp_rs1_to_sc)))  <= '1';
               dsp_sci_req(to_integer(unsigned(dsp_rs2_to_sc)))  <= '1';
               dsp_sc_read_addr(0)  <= RS1_Data_IE_lat(Addr_Width - 1 downto 0);
               dsp_sc_read_addr(1)  <= RS2_Data_IE_lat(Addr_Width - 1 downto 0);
             end if;
             if MVSIZE_WRITE > (0 to Addr_Width => '0') then
               nextstate_DSP <= dsp_exec;
               busy_DSP_internal_wires := '1';
             end if;
             if wb_ready = '1' then
               dsp_sci_we(to_integer(unsigned(dsp_rd_to_sc)))    <= '1';
               dsp_sc_write_addr <= RD_Data_IE_lat;
             end if;
           end if;
          ---------------------------------------------------------------------------------------------

           if decoded_instruction_DSP_lat(KSRAV_bit_position)  = '1' or
              decoded_instruction_DSP_lat(KSRLV_bit_position)  = '1' then
             -- KSRAV signals are handeled here
             if shifter_stage_3_en = '1' then
               wb_ready <= '1';
             elsif recover_state = '1' then
               wb_ready <= '1';  
             end if;
             if MVSIZE_READ > (0 to Addr_Width => '0') then
               dsp_to_sc(to_integer(unsigned(dsp_rs1_to_sc)))(0) <= '1';
               dsp_sci_req(to_integer(unsigned(dsp_rs1_to_sc)))  <= '1';
               dsp_sc_read_addr(0)  <= RS1_Data_IE_lat(Addr_Width - 1 downto 0);
             end if;
             if MVSIZE_WRITE > (0 to Addr_Width => '0') then
               nextstate_DSP <= dsp_exec;
               busy_DSP_internal_wires := '1';
             end if;
             if wb_ready = '1' then
               dsp_sci_we(to_integer(unsigned(dsp_rd_to_sc))) <= '1';
               dsp_sc_write_addr <= RD_Data_IE_lat;
             end if;
           end if;
    
           if decoded_instruction_DSP_lat(KVRED_bit_position)   = '1' or
              decoded_instruction_DSP_lat(KDOTP_bit_position)   = '1' or
              decoded_instruction_DSP_lat(KDOTPPS_bit_position) = '1' then
             -- KDOTP signals are handeled here
             if accum_stage_3_en = '1' then
               wb_ready <= '1';
             elsif recover_state = '1' then
               wb_ready <= '1';  
             end if;
             if MVSIZE_READ > (0 to Addr_Width => '0') then
               if vec_read_rs2_DSP = '1' then
                 dsp_sci_req(to_integer(unsigned(dsp_rs2_to_sc))) <= '1';
                 dsp_to_sc(to_integer(unsigned(dsp_rs2_to_sc)))(1) <= '1';
                 dsp_sc_read_addr(1)  <= RS2_Data_IE_lat(Addr_Width - 1 downto 0);
               end if;
               dsp_sci_req(to_integer(unsigned(dsp_rs1_to_sc))) <= '1';
               dsp_to_sc(to_integer(unsigned(dsp_rs1_to_sc)))(0) <= '1';
               dsp_sc_read_addr(0)  <= RS1_Data_IE_lat(Addr_Width - 1 downto 0);
               nextstate_DSP <= dsp_exec;
               busy_DSP_internal_wires := '1';
             elsif MVSIZE_WRITE = (0 to Addr_Width => '0') then
               nextstate_DSP <= dsp_init;
             else
               nextstate_DSP <= dsp_exec;
               busy_DSP_internal_wires := '1';
             end if;
             if wb_ready = '1' then
               dsp_sci_we(to_integer(unsigned(dsp_rd_to_sc)))    <= '1';
               dsp_sc_write_addr <= RD_Data_IE_lat;
             end if;
           end if;

           if decoded_instruction_DSP_lat(KVMUL_bit_position)    = '1' or 
              decoded_instruction_DSP_lat(KSVMULSC_bit_position) = '1' or 
              decoded_instruction_DSP_lat(KSVMULRF_bit_position) = '1' or 
              decoded_instruction_DSP_lat(KSVADDSC_bit_position) = '1' or 
              decoded_instruction_DSP_lat(KSVADDRF_bit_position) = '1' then
             -- KMUL signals are handeled here
             if mul_stage_3_en = '1' or adder_stage_3_en = '1' then 
               wb_ready <= '1';
             elsif recover_state = '1' then
               wb_ready <= '1';
             end if;
             if MVSIZE_READ > (0 to Addr_Width => '0') then
               dsp_sci_req(to_integer(unsigned(dsp_rs1_to_sc))) <= '1';
               if rf_rs2 = '0' then -- if the scalar does not come from the regfile
                 dsp_sci_req(to_integer(unsigned(dsp_rs2_to_sc))) <= '1';
                 dsp_to_sc(to_integer(unsigned(dsp_rs2_to_sc)))(1) <= '1';
                 dsp_sc_read_addr(1)  <= RS2_Data_IE_lat(Addr_Width - 1 downto 0);
               end if;
               dsp_to_sc(to_integer(unsigned(dsp_rs1_to_sc)))(0) <= '1';
               dsp_sc_read_addr(0)  <= RS1_Data_IE_lat(Addr_Width - 1 downto 0);
               nextstate_DSP <= dsp_exec;
               busy_DSP_internal_wires := '1';
             elsif MVSIZE_WRITE = (0 to Addr_Width => '0') then
               nextstate_DSP <= dsp_init;
             else
               nextstate_DSP <= dsp_exec;
               busy_DSP_internal_wires := '1';
             end if;
             if wb_ready = '1' then
               dsp_sci_we(to_integer(unsigned(dsp_rd_to_sc))) <= '1';
               dsp_sc_write_addr <= RD_Data_IE_lat;
             end if;
           end if;

         when others =>
           null;
       end case;
     end if;
    busy_DSP_internal    <= busy_DSP_internal_wires;
    dsp_except_condition <= dsp_except_condition_wires;
    dsp_taken_branch     <= dsp_taken_branch_wires;
  end process;
end architecture DSP_Excpt_Cntrl_unit_arch;