-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;

library STD;
use STD.textio.all;
-- local packages -----------------
use work.riscv_klessydra.all;
use work.tb_config.all;
use ieee.math_real.all;

entity tb_RTL_DSP_TOP is
end entity tb_RTL_DSP_TOP;

architecture tb_RTL_DSP_TOP_arch of tb_RTL_DSP_TOP is 

type string_array is array (integer range <>) of string(1 to 30);

signal clk_i_tb, rst_ni_tb           : std_logic;
signal rs1_to_sc_tb                  : std_logic_vector(SPM_ADDR_WID-1 downto 0);
signal rs2_to_sc_tb                  : std_logic_vector(SPM_ADDR_WID-1 downto 0);
signal rd_to_sc_tb                   : std_logic_vector(SPM_ADDR_WID-1 downto 0);
-- CSR Signals
signal MVSIZE_tb                     : array_2d(THREAD_POOL_SIZE-1 downto 0)(Addr_Width downto 0);
signal MVTYPE_tb                     : array_2d(THREAD_POOL_SIZE-1 downto 0)(3 downto 0);
signal MPSCLFAC_tb                   : array_2d(THREAD_POOL_SIZE-1 downto 0)(4 downto 0);
signal dsp_except_data_tb            : array_2d(ACCL_NUM-1 downto 0)(31 downto 0);
-- Program Counter Signals
signal dsp_taken_branch_tb           : std_logic_vector(ACCL_NUM-1 downto 0);
signal dsp_except_condition_tb       : std_logic_vector(ACCL_NUM-1 downto 0);
-- ID_Stage Signals
signal decoded_instruction_DSP_tb    : std_logic_vector(DSP_UNIT_INSTR_SET_SIZE-1 downto 0);
signal harc_EXEC_tb                  : integer range THREAD_POOL_SIZE-1 downto 0;
signal pc_IE_tb                      : std_logic_vector(31 downto 0);
signal RS1_Data_IE_tb                : std_logic_vector(31 downto 0);
signal RS2_Data_IE_tb                : std_logic_vector(31 downto 0);
signal RD_Data_IE_tb                 : std_logic_vector(Addr_Width -1 downto 0);
signal dsp_instr_req_tb              : std_logic_vector(ACCL_NUM-1 downto 0);
signal spm_rs1_tb                    : std_logic;
signal spm_rs2_tb                    : std_logic;
signal vec_read_rs1_ID_tb            : std_logic;
signal vec_read_rs2_ID_tb            : std_logic;
signal vec_write_rd_ID_tb            : std_logic;
signal busy_dsp_tb                   : std_logic_vector(ACCL_NUM-1 downto 0);
-- Scratchpad Interface Signals
signal dsp_data_gnt_i_tb             : std_logic_vector(ACCL_NUM-1 downto 0);
signal dsp_sci_wr_gnt_tb             : std_logic_vector(ACCL_NUM-1 downto 0);
signal dsp_sc_data_read_tb           : array_3d(ACCL_NUM-1 downto 0)(1 downto 0)(SIMD_Width-1 downto 0);
signal dsp_we_word_tb                : array_2d(ACCL_NUM-1 downto 0)(SIMD-1 downto 0);
signal dsp_sc_read_addr_tb           : array_3d(ACCL_NUM-1 downto 0)(1 downto 0)(Addr_Width-1 downto 0);
signal dsp_to_sc_tb                  : array_3d(ACCL_NUM-1 downto 0)(SPM_NUM-1 downto 0)(1 downto 0);
signal dsp_sc_data_write_wire_tb     : array_2d(ACCL_NUM-1 downto 0)(SIMD_Width-1 downto 0);
signal dsp_sc_write_addr_tb          : array_2d(ACCL_NUM-1 downto 0)(Addr_Width-1 downto 0);
signal dsp_sci_we_tb                 : array_2d(ACCL_NUM-1 downto 0)(SPM_NUM-1 downto 0);
signal dsp_sci_req_tb                : array_2d(ACCL_NUM-1 downto 0)(SPM_NUM-1 downto 0);
-- tracer signals
signal state_DSP_tb                  : array_2d(ACCL_NUM-1 downto 0)(1 downto 0);



component RTL_DSP_TOP is
  generic(
    THREAD_POOL_SIZE      : integer;
    accl_en               : natural;
    replicate_accl_en     : natural;
    multithreaded_accl_en : natural;
    SPM_NUM               : natural; 
    Addr_Width            : natural;
    SIMD                  : natural;
    --------------------------------
    ACCL_NUM              : natural;
    FU_NUM                : natural;
    TPS_CEIL              : natural;
    TPS_BUF_CEIL          : natural;
    SPM_ADDR_WID          : natural;
    SIMD_BITS             : natural;
    Data_Width            : natural;
    SIMD_Width            : natural
  );
  port (
    -- Core Signals
    clk_i, rst_ni              : in std_logic;
    -- Processing Pipeline Signals
    rs1_to_sc                  : in  std_logic_vector(SPM_ADDR_WID-1 downto 0);
    rs2_to_sc                  : in  std_logic_vector(SPM_ADDR_WID-1 downto 0);
    rd_to_sc                   : in  std_logic_vector(SPM_ADDR_WID-1 downto 0);
  -- CSR Signals
    MVSIZE                     : in  array_2d(THREAD_POOL_SIZE-1 downto 0)(Addr_Width downto 0);
    MVTYPE                     : in  array_2d(THREAD_POOL_SIZE-1 downto 0)(3 downto 0);
    MPSCLFAC                   : in  array_2d(THREAD_POOL_SIZE-1 downto 0)(4 downto 0);
    dsp_except_data            : out array_2d(ACCL_NUM-1 downto 0)(31 downto 0);
  -- Program Counter Signals
    dsp_taken_branch           : out std_logic_vector(ACCL_NUM-1 downto 0);
    dsp_except_condition       : out std_logic_vector(ACCL_NUM-1 downto 0);
    -- ID_Stage Signals
    decoded_instruction_DSP    : in  std_logic_vector(DSP_UNIT_INSTR_SET_SIZE-1 downto 0);
    harc_EXEC                  : in  integer range THREAD_POOL_SIZE-1 downto 0;
    pc_IE                      : in  std_logic_vector(31 downto 0);
    RS1_Data_IE                : in  std_logic_vector(31 downto 0);
    RS2_Data_IE                : in  std_logic_vector(31 downto 0);
    RD_Data_IE                 : in  std_logic_vector(Addr_Width -1 downto 0);
    dsp_instr_req              : in  std_logic_vector(ACCL_NUM-1 downto 0);
    spm_rs1                    : in  std_logic;
    spm_rs2                    : in  std_logic;
    vec_read_rs1_ID            : in  std_logic;
    vec_read_rs2_ID            : in  std_logic;
    vec_write_rd_ID            : in  std_logic;
    busy_dsp                   : out std_logic_vector(ACCL_NUM-1 downto 0);
  -- Scratchpad Interface Signals
    dsp_data_gnt_i             : in  std_logic_vector(ACCL_NUM-1 downto 0);
    dsp_sci_wr_gnt             : in  std_logic_vector(ACCL_NUM-1 downto 0);
    dsp_sc_data_read           : in  array_3d(ACCL_NUM-1 downto 0)(1 downto 0)(SIMD_Width-1 downto 0);
    dsp_we_word                : out array_2d(ACCL_NUM-1 downto 0)(SIMD-1 downto 0);
    dsp_sc_read_addr           : out array_3d(ACCL_NUM-1 downto 0)(1 downto 0)(Addr_Width-1 downto 0);
    dsp_to_sc                  : out array_3d(ACCL_NUM-1 downto 0)(SPM_NUM-1 downto 0)(1 downto 0);
    dsp_sc_data_write_wire     : out array_2d(ACCL_NUM-1 downto 0)(SIMD_Width-1 downto 0);
    dsp_sc_write_addr          : out array_2d(ACCL_NUM-1 downto 0)(Addr_Width-1 downto 0);
    dsp_sci_we                 : out array_2d(ACCL_NUM-1 downto 0)(SPM_NUM-1 downto 0);
    dsp_sci_req                : out array_2d(ACCL_NUM-1 downto 0)(SPM_NUM-1 downto 0);
    -- tracer signals
    state_DSP                  : out array_2d(ACCL_NUM-1 downto 0)(1 downto 0)
  );
end component RTL_DSP_TOP;

begin
  -- Instantiate the DSP Top Level
  DUT: RTL_DSP_TOP
    generic map (
      THREAD_POOL_SIZE      => THREAD_POOL_SIZE,
      accl_en               => accl_en,
      replicate_accl_en     => replicate_accl_en,
      multithreaded_accl_en => multithreaded_accl_en,
      SPM_NUM               => SPM_NUM, 
      Addr_Width            => Addr_Width,
      SIMD                  => SIMD,
      --------------------------------
      ACCL_NUM              => ACCL_NUM,
      FU_NUM                => FU_NUM,
      TPS_CEIL              => TPS_CEIL,
      TPS_BUF_CEIL          => TPS_BUF_CEIL,
      SPM_ADDR_WID          => SPM_ADDR_WID,
      SIMD_BITS             => SIMD_BITS,
      Data_Width            => Data_Width,
      SIMD_Width            => SIMD_Width
    )
    port map (
      clk_i                   => clk_i_tb,
      rst_ni                  => rst_ni_tb,
      rs1_to_sc               => rs1_to_sc_tb,
      rs2_to_sc               => rs2_to_sc_tb,
      rd_to_sc                => rd_to_sc_tb,
      MVSIZE                  => MVSIZE_tb,
      MVTYPE                  => MVTYPE_tb,
      MPSCLFAC                => MPSCLFAC_tb,
      dsp_except_data         => dsp_except_data_tb,
      dsp_taken_branch        => dsp_taken_branch_tb,
      dsp_except_condition    => dsp_except_condition_tb,
      decoded_instruction_DSP => decoded_instruction_DSP_tb,
      harc_EXEC               => harc_EXEC_tb,
      pc_IE                   => pc_IE_tb,
      RS1_Data_IE             => RS1_Data_IE_tb,
      RS2_Data_IE             => RS2_Data_IE_tb,
      RD_Data_IE              => RD_Data_IE_tb,
      dsp_instr_req           => dsp_instr_req_tb,
      spm_rs1                 => spm_rs1_tb,
      spm_rs2                 => spm_rs2_tb,
      vec_read_rs1_ID         => vec_read_rs1_ID_tb,
      vec_read_rs2_ID         => vec_read_rs2_ID_tb,
      vec_write_rd_ID         => vec_write_rd_ID_tb,
      busy_dsp                => busy_dsp_tb,
      dsp_data_gnt_i          => dsp_data_gnt_i_tb,
      dsp_sci_wr_gnt          => dsp_sci_wr_gnt_tb,
      dsp_sc_data_read        => dsp_sc_data_read_tb,
      dsp_we_word             => dsp_we_word_tb,
      dsp_sc_read_addr        => dsp_sc_read_addr_tb,
      dsp_to_sc               => dsp_to_sc_tb,
      dsp_sc_data_write_wire  => dsp_sc_data_write_wire_tb,
      dsp_sc_write_addr       => dsp_sc_write_addr_tb,
      dsp_sci_we              => dsp_sci_we_tb,
      dsp_sci_req             => dsp_sci_req_tb,
      state_DSP               => state_DSP_tb
    );

  test_bench: process
  file text_file : TEXT open READ_MODE is "./test/conv_matmul_shift_comp.txt";  -- check this address during importing
  variable text_line : line;
  variable ok : boolean;
  variable data_name: string_array(0 to 100);
  variable collect_data : boolean := false;  -- flag to collect data
  variable signal_value : std_logic_vector(SIMD_Width downto 0);
  variable index : integer := 0;
  variable current_time, new_time : integer := 0;  -- current time in ns
  variable char : character;
  variable invalid_signal : boolean := false;  -- flag to detect invalid signal

  begin
    while not endfile(text_file) loop
      -- reading the line for the file and storing into the line.
      readline(text_file, text_line);

      --detect the start of the data collection
      if text_line.all(1 to 3) = "###" then
        collect_data := true;
        next;
      end if;
        
      -- Skip empty lines and single-line comments
      if text_line.all'length = 0 or text_line.all(1) = '#' then
        next;
      end if;

      -- if each signal is on a separate line
      if collect_data = false then
        index := index + 1;
        read(text_line, data_name(index)(1 to text_line.all'length), ok);
        assert ok
          report "Read 'data name' failed for index " & integer'image(index)
          severity failure;
        next;
      end if;

      -- -- read the line and store the words in the data_name array
      -- if text_line.all(1 to 4) = "time" then
      --   -- read the line and store the words in the data_name array
      --   while text_line.all'length > 0 loop
      --     index := index + 1;
      --     read(text_line, data_name(index), ok);
      --     assert ok
      --       report "Read 'data name' failed for index" & integer'image(index)
      --       severity failure;
      --   end loop;
      --   next;
      -- end if;

      if collect_data then
        --get the current time from the first word in the line
        read(text_line, new_time, ok);
        assert ok
          report "Read 'time' failed for line: " & text_line.all
          severity failure;
        wait for (new_time - current_time) * 1 ns;  -- wait for the time difference
        current_time := new_time;

        -- read the line and assign the values to the signals accordingly
        for i in 2 to index loop
          read(text_line, char, ok); -- skip the empty space
          invalid_signal := false;  -- reset the invalid signal flag
          while text_line.all'length > 0 and (text_line.all(1) = 'X' or text_line.all(1) = 'U') loop
            invalid_signal := true;  -- mark the signal as invalid
            read(text_line, char, ok);
            assert ok
              report "Read 'char' failed for line: " & text_line.all
              severity failure;
          end loop;
          if invalid_signal then
            report "Invalid signal detected, skipping: " & data_name(i) severity note;
            next;  -- skip to the next signal
          end if;
          --hread (text_line, signal_value, ok);
          --assert ok
          --  report "Read 'signal value' failed for line: " & text_line.all
          --  severity failure;
          --case data_name(i) is
            --when "clk_i" =>
            if data_name(i)(1 to 5) = "clk_i" then
              hread(text_line, signal_value(3 downto 0), ok);
              assert ok
                report "Read 'clk_i' failed for line: " & text_line.all
                severity failure;
              clk_i_tb <= signal_value(0);
            --when "rst_ni" =>
            elsif data_name(i)(1 to 6) = "rst_ni" then
              hread(text_line, signal_value(3 downto 0), ok);
              assert ok
                report "Read 'rst_ni' failed for line: " & text_line.all
                severity failure;
              rst_ni_tb <= signal_value(0);
            --when "rs1_to_sc" =>
            elsif data_name(i)(1 to 9) = "rs1_to_sc" then
              hread(text_line, signal_value((SPM_ADDR_WID-1)+4-(SPM_ADDR_WID mod 4) downto 0), ok);
              assert ok
                report "Read 'rs1_to_sc' failed for line: " & text_line.all
                severity failure;
              rs1_to_sc_tb <= signal_value(SPM_ADDR_WID-1 downto 0);
            --when "rs2_to_sc" =>
            elsif data_name(i)(1 to 9) = "rs2_to_sc" then
              hread(text_line, signal_value((SPM_ADDR_WID-1)+4-(SPM_ADDR_WID mod 4) downto 0), ok);
              assert ok
                report "Read 'rs2_to_sc' failed for line: " & text_line.all
                severity failure;
              rs2_to_sc_tb <= signal_value(SPM_ADDR_WID-1 downto 0);
            --when "rd_to_sc" =>
            elsif data_name(i)(1 to 8) = "rd_to_sc" then  
              hread(text_line, signal_value((SPM_ADDR_WID-1)+4-(SPM_ADDR_WID mod 4) downto 0), ok);
              assert ok
                report "Read 'rd_to_sc' failed for line: " & text_line.all
                severity failure;
              rd_to_sc_tb <= signal_value(SPM_ADDR_WID-1 downto 0);
            --when "MVSIZE" =>
            elsif data_name(i)(1 to 6) = "MVSIZE" then
              for j in 0 to (THREAD_POOL_SIZE-1) loop
                hread(text_line, signal_value((Addr_Width)+4-(Addr_Width+1 mod 4) downto 0), ok);
                assert ok
                  report "Read 'MVSIZE' failed for index: " & integer'image(j)
                  severity failure;
                MVSIZE_tb(j) <= signal_value(Addr_Width downto 0);
              end loop;
            --when "MVTYPE" =>
            elsif data_name(i)(1 to 6) = "MVTYPE" then
              for j in 0 to (THREAD_POOL_SIZE-1) loop
                hread(text_line, signal_value(3 downto 0), ok);
                assert ok
                  report "Read 'MVTYPE' failed for index: " & integer'image(j)
                  severity failure;
                MVTYPE_tb(j) <= signal_value(3 downto 0);
              end loop;
            --when "MPSCLFAC" =>
            elsif data_name(i)(1 to 8) = "MPSCLFAC" then
              for j in 0 to (THREAD_POOL_SIZE-1) loop
                hread(text_line, signal_value(7 downto 0), ok);
                assert ok
                  report "Read 'MPSCLFAC' failed for index: " & integer'image(j) & " with text: " & text_line.all
                  severity failure;
                MPSCLFAC_tb(j) <= signal_value(4 downto 0);
              end loop;
            --when "decoded_instruction_DSP" =>
            elsif data_name(i)(1 to 23) = "decoded_instruction_DSP" then
              hread(text_line, signal_value((DSP_UNIT_INSTR_SET_SIZE-1)+4-(DSP_UNIT_INSTR_SET_SIZE mod 4) downto 0), ok);
              assert ok
                report "Read 'decoded_instruction_DSP' failed for line: " & text_line.all
                severity failure;
              decoded_instruction_DSP_tb <= signal_value(DSP_UNIT_INSTR_SET_SIZE-1 downto 0);
            --when "harc_EXEC" =>
            elsif data_name(i)(1 to 9) = "harc_EXEC" then
              hread(text_line, signal_value(integer(ceil(log2(real(THREAD_POOL_SIZE+1))))+4-(integer(ceil(log2(real(THREAD_POOL_SIZE+1)))) mod 4) downto 0), ok);
              assert ok------------------------------------------------------------------------------------------------------------------------------------------
                report "Read 'harc_EXEC' failed for line: " & text_line.all
                severity failure;
              harc_EXEC_tb <= to_integer(unsigned(signal_value));
            --when "pc_IE" =>
            elsif data_name(i)(1 to 5) = "pc_IE" then
              hread(text_line, signal_value(31 downto 0), ok);
              assert ok
                report "Read 'pc_IE' failed for line: " & text_line.all
                severity failure;
              pc_IE_tb <= signal_value(31 downto 0);
            --when "RS1_Data_IE" =>
            elsif data_name(i)(1 to 11) = "RS1_Data_IE" then
              hread(text_line, signal_value(31 downto 0), ok);
              assert ok
                report "Read 'RS1_Data_IE' failed for line: " & text_line.all
                severity failure;
              RS1_Data_IE_tb <= signal_value(31 downto 0);
            --when "RS2_Data_IE" =>
            elsif data_name(i)(1 to 11) = "RS2_Data_IE" then
              hread(text_line, signal_value(31 downto 0), ok);
              assert ok
                report "Read 'RS2_Data_IE' failed for line: " & text_line.all
                severity failure;
              RS2_Data_IE_tb <= signal_value(31 downto 0);
            --when "RD_Data_IE" =>
            elsif data_name(i)(1 to 10) = "RD_Data_IE" then
              hread(text_line, signal_value((Addr_Width -1)+4-(Addr_Width mod 4) downto 0), ok);
              assert ok
                report "Read 'RD_Data_IE' failed for line: " & text_line.all
                severity failure;
              RD_Data_IE_tb <= signal_value(Addr_Width -1 downto 0);
            --when "dsp_instr_req" =>
            elsif data_name(i)(1 to 13) = "dsp_instr_req" then
              hread(text_line, signal_value((ACCL_NUM-1)+4-(ACCL_NUM mod 4) downto 0), ok);
              assert ok
                report "Read 'dsp_instr_req' failed for line: " & text_line.all
                severity failure;
              dsp_instr_req_tb <= signal_value(ACCL_NUM-1 downto 0);
            --when "spm_rs1" =>
            elsif data_name(i)(1 to 7) = "spm_rs1" then
              hread(text_line, signal_value(3 downto 0), ok);
              assert ok
                report "Read 'spm_rs1' failed for line: " & text_line.all
                severity failure;
              spm_rs1_tb <= signal_value(0);
            --when "spm_rs2" =>
            elsif data_name(i)(1 to 7) = "spm_rs2" then
              hread(text_line, signal_value(3 downto 0), ok);
              assert ok
                report "Read 'spm_rs2' failed for line: " & text_line.all
                severity failure;
              spm_rs2_tb <= signal_value(0);
            --when "vec_read_rs1_ID" =>
            elsif data_name(i)(1 to 15) = "vec_read_rs1_ID" then
              hread(text_line, signal_value(3 downto 0), ok);
              assert ok
                report "Read 'vec_read_rs1_ID' failed for line: " & text_line.all
                severity failure;
              vec_read_rs1_ID_tb <= signal_value(0);
            --when "vec_read_rs2_ID" =>
            elsif data_name(i)(1 to 15) = "vec_read_rs2_ID" then
              hread(text_line, signal_value(3 downto 0), ok);
              assert ok
                report "Read 'vec_read_rs2_ID' failed for line: " & text_line.all
                severity failure;
              vec_read_rs2_ID_tb <= signal_value(0);
            --when "vec_write_rd_ID" =>
            elsif data_name(i)(1 to 15) = "vec_write_rd_ID" then
              hread(text_line, signal_value(3 downto 0), ok);
              assert ok
                report "Read 'vec_write_rd_ID' failed for line: " & text_line.all
                severity failure;
              vec_write_rd_ID_tb <= signal_value(0);
            --when "dsp_data_gnt_i" =>
            elsif data_name(i)(1 to 14) = "dsp_data_gnt_i" then
              hread(text_line, signal_value((ACCL_NUM-1)+4-(ACCL_NUM mod 4) downto 0), ok);
              assert ok
                report "Read 'dsp_data_gnt_i' failed for line: " & text_line.all
                severity failure;
              dsp_data_gnt_i_tb <= signal_value(ACCL_NUM-1 downto 0);
            --when "dsp_sci_wr_gnt" =>
            elsif data_name(i)(1 to 14) = "dsp_sci_wr_gnt" then
              hread(text_line, signal_value((ACCL_NUM-1)+4-(ACCL_NUM mod 4) downto 0), ok);
              assert ok
                report "Read 'dsp_sci_wr_gnt' failed for line: " & text_line.all
                severity failure;
              dsp_sci_wr_gnt_tb <= signal_value(ACCL_NUM-1 downto 0);
            --when "dsp_sc_data_read" =>
            elsif data_name(i)(1 to 16) = "dsp_sc_data_read" then
              for j in 0 to (ACCL_NUM-1) loop
                for k in 0 to 1 loop
                  hread(text_line, signal_value((SIMD_Width-1)+4-(SIMD_Width mod 4) downto 0), ok);
                  assert ok
                    report "Read 'dsp_sc_data_read' failed for index: " & integer'image(j) & ", " & integer'image(k)
                    severity failure;
                  dsp_sc_data_read_tb(j)(k) <= signal_value(SIMD_Width-1 downto 0);
                end loop;
              end loop;
            --when others =>
            --  report "Unknown/ouyput signal name, ignoring: " & data_name(i) severity note;
          --end case;
            else 
              while text_line.all(1) /= ' ' loop
                read(text_line, char, ok);
                assert ok
                  report "Read 'char' failed for line: " & text_line.all
                  severity failure;
              end loop;
          end if;
        end loop;
      end if;

    end loop;
  end process test_bench;
end architecture tb_RTL_DSP_TOP_arch;