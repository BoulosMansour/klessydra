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
  file text_file : TEXT open READ_MODE is "./test/conv_and_mul_in.txt";  -- check this address during importing
  variable text_line : line;
  variable ok : boolean;
  variable data_name: string_array(0 to 100);
  variable collect_data : boolean := false;  -- flag to collect data
  variable signal_value : std_logic_vector((SIMD_Width-1)+4-(SIMD_Width mod 4) downto 0);
  variable index : integer := 0;
  variable current_time, new_time : integer := 0;  -- current time in ns
  variable char : character;
  variable invalid_signal : boolean := false;  -- flag to detect invalid signal

  variable clk_i_var, rst_ni_var           : std_logic;
  variable rs1_to_sc_var                  : std_logic_vector(SPM_ADDR_WID-1 downto 0);
  variable rs2_to_sc_var                 : std_logic_vector(SPM_ADDR_WID-1 downto 0);
  variable rd_to_sc_var                   : std_logic_vector(SPM_ADDR_WID-1 downto 0);
  -- CSR Signals
  variable MVSIZE_var                     : array_2d(THREAD_POOL_SIZE-1 downto 0)(Addr_Width downto 0);
  variable MVTYPE_var                     : array_2d(THREAD_POOL_SIZE-1 downto 0)(3 downto 0);
  variable MPSCLFAC_var                   : array_2d(THREAD_POOL_SIZE-1 downto 0)(4 downto 0);
  -- ID_Stage Signals
  variable decoded_instruction_DSP_var    : std_logic_vector(DSP_UNIT_INSTR_SET_SIZE-1 downto 0);
  variable harc_EXEC_var                  : unsigned(integer(ceil(log2(real(THREAD_POOL_SIZE-1)))) downto 0);
  variable pc_IE_var                      : std_logic_vector(31 downto 0);
  variable RS1_Data_IE_var                : std_logic_vector(31 downto 0);
  variable RS2_Data_IE_var                : std_logic_vector(31 downto 0);
  variable RD_Data_IE_var                 : std_logic_vector(Addr_Width -1 downto 0);
  variable dsp_instr_req_var              : std_logic_vector(ACCL_NUM-1 downto 0);
  variable spm_rs1_var                    : std_logic;
  variable spm_rs2_var                    : std_logic;
  variable vec_read_rs1_ID_var            : std_logic;
  variable vec_read_rs2_ID_var            : std_logic;
  variable vec_write_rd_ID_var            : std_logic;
  -- Scratchpad Interface Signals
  variable dsp_data_gnt_i_var             : std_logic_vector(ACCL_NUM-1 downto 0);
  variable dsp_sci_wr_gnt_var             : std_logic_vector(ACCL_NUM-1 downto 0);
  variable dsp_sc_data_read_var           : array_3d(ACCL_NUM-1 downto 0)(1 downto 0)(SIMD_Width-1 downto 0);

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
          -- invalid_signal := false;  -- reset the invalid signal flag
          -- while text_line.all'length > 0 and (text_line.all(1) = 'X' or text_line.all(1) = 'U') loop
          --   invalid_signal := true;  -- mark the signal as invalid
          --   read(text_line, char, ok);
          --   assert ok
          --     report "Read 'char' failed for line: " & text_line.all
          --     severity failure;
          -- end loop;
          -- if invalid_signal then
          --   report "Invalid signal detected, skipping: " & data_name(i) severity note;
          --   next;  -- skip to the next signal
          -- end if;
          --hread (text_line, signal_value, ok);
          --assert ok
          --  report "Read 'signal value' failed for line: " & text_line.all
          --  severity failure;
          --case data_name(i) is
            --when "clk_i" =>
            if data_name(i)(1 to 5) = "clk_i" then
              read(text_line, clk_i_var, ok);
              assert ok
                report "Read 'clk_i' failed for line: " & text_line.all
                severity failure;
              report "read clk_i, arrived to: " & text_line.all;
            --when "rst_ni" =>
            elsif data_name(i)(1 to 6) = "rst_ni" then
              read(text_line, rst_ni_var, ok);
              assert ok
                report "Read 'rst_ni' failed for line: " & text_line.all
                severity failure;
              report "read rst_nit_tb arrived to: " & text_line.all;
            --when "rs1_to_sc" =>
            elsif data_name(i)(1 to 9) = "rs1_to_sc" then
              hread(text_line, rs1_to_sc_var, ok);
              assert ok
                report "Read 'rs1_to_sc' failed for line: " & text_line.all
                severity failure;
              report "read rs1_to_sc arrived to: " & text_line.all;
            --when "rs2_to_sc" =>
            elsif data_name(i)(1 to 9) = "rs2_to_sc" then
              hread(text_line, rs2_to_sc_var, ok);
              assert ok
                report "Read 'rs2_to_sc' failed for line: " & text_line.all
                severity failure;
              report "read rs2_to_sc, arrived to: " & text_line.all;
            --when "rd_to_sc" =>
            elsif data_name(i)(1 to 8) = "rd_to_sc" then  
              hread(text_line, rd_to_sc_var, ok);
              assert ok
                report "Read 'rd_to_sc' failed for line: " & text_line.all
                severity failure;
              report "read 'rd_to_sc', arrived to: " & text_line.all;
            --when "MVSIZE" =>
            elsif data_name(i)(1 to 6) = "MVSIZE" then
              for j in 0 to (THREAD_POOL_SIZE-1) loop
                hread(text_line, MVSIZE_var(j), ok);
                assert ok
                  report "Read 'MVSIZE' failed for index: " & integer'image(j)
                  severity failure;
                report "read MVSIZE iteration" & integer'image(j) & ", arrived to: " & text_line.all;
              end loop;
            --when "MVTYPE" =>
            elsif data_name(i)(1 to 6) = "MVTYPE" then
              for j in 0 to (THREAD_POOL_SIZE-1) loop
                hread(text_line, MVTYPE_var(j), ok);
                assert ok
                  report "Read 'MVTYPE' failed for index: " & integer'image(j)
                  severity failure;
                report "read MVTYPE iteration" & integer'image(j) & ", arrived to: " & text_line.all;
              end loop;
            --when "MPSCLFAC" =>
            elsif data_name(i)(1 to 8) = "MPSCLFAC" then
              for j in 0 to (THREAD_POOL_SIZE-1) loop
                hread(text_line, MPSCLFAC_var(j), ok);
                assert ok
                  report "Read 'MPSCLFAC' failed for index: " & integer'image(j) & " with text: " & text_line.all
                  severity failure;
                report "read MPSCLFAC iteration" & integer'image(j) & ", arrived to: " & text_line.all;
              end loop;
            --when "decoded_instruction_DSP" =>
            elsif data_name(i)(1 to 23) = "decoded_instruction_DSP" then
              hread(text_line, decoded_instruction_DSP_var, ok);
              assert ok
                report "Read 'decoded_instruction_DSP' failed for line: " & text_line.all
                severity failure;
              report "read decoded_instruction_DSP, arrived to: " & text_line.all;
            --when "harc_EXEC" =>
            elsif data_name(i)(1 to 9) = "harc_EXEC" then
              hread(text_line, harc_EXEC_var, ok);
              assert ok------------------------------------------------------------------------------------------------------------------------------------------
                report "Read 'harc_EXEC' failed for line: " & text_line.all
                severity failure;
              report "read harc_EXEC, arrived to: " & text_line.all;
            --when "pc_IE" =>
            elsif data_name(i)(1 to 5) = "pc_IE" then
              hread(text_line, pc_IE_var, ok);
              assert ok
                report "Read 'pc_IE' failed for line: " & text_line.all
                severity failure;
              report "read pc_IE, arrived to: " & text_line.all;
            --when "RS1_Data_IE" =>
            elsif data_name(i)(1 to 11) = "RS1_Data_IE" then
              hread(text_line, RS1_Data_IE_var, ok);
              assert ok
                report "Read 'RS1_Data_IE' failed for line: " & text_line.all
                severity failure;
              report "read RS1_Data_IE, arrived to: " & text_line.all;
            --when "RS2_Data_IE" =>
            elsif data_name(i)(1 to 11) = "RS2_Data_IE" then
              hread(text_line, RS2_Data_IE_var, ok);
              assert ok
                report "Read 'RS2_Data_IE' failed for line: " & text_line.all
                severity failure;
              report "read RS2_Data_IE, arrived to: " & text_line.all;
            --when "RD_Data_IE" =>
            elsif data_name(i)(1 to 10) = "RD_Data_IE" then
              hread(text_line, RD_Data_IE_var, ok);
              assert ok
                report "Read 'RD_Data_IE' failed for line: " & text_line.all
                severity failure;
              report "read RD_Data_IE, arrived to: " & text_line.all;
            --when "dsp_instr_req" =>
            elsif data_name(i)(1 to 13) = "dsp_instr_req" then
              hread(text_line, dsp_instr_req_var, ok);
              assert ok
                report "Read 'dsp_instr_req' failed for line: " & text_line.all
                severity failure;
              report "read dsp_instr_req, arrived to: " & text_line.all;
            --when "spm_rs1" =>
            elsif data_name(i)(1 to 7) = "spm_rs1" then
              read(text_line, spm_rs1_var, ok);
              assert ok
                report "Read 'spm_rs1' failed for line: " & text_line.all
                severity failure;
            report "read spm_rs1, arrived to: " & text_line.all;
            --when "spm_rs2" =>
            elsif data_name(i)(1 to 7) = "spm_rs2" then
              read(text_line, spm_rs2_var, ok);
              assert ok
                report "Read 'spm_rs2' failed for line: " & text_line.all
                severity failure;
            report "read spm_rs2, arrived to: " & text_line.all;
            --when "vec_read_rs1_ID" =>
            elsif data_name(i)(1 to 15) = "vec_read_rs1_ID" then
              read(text_line, vec_read_rs1_ID_var, ok);
              assert ok
                report "Read 'vec_read_rs1_ID' failed for line: " & text_line.all
                severity failure;
            report "read vec_read_rs1_ID, arrived to: " & text_line.all;
            --when "vec_read_rs2_ID" =>
            elsif data_name(i)(1 to 15) = "vec_read_rs2_ID" then
              read(text_line, vec_read_rs2_ID_var, ok);
              assert ok
                report "Read 'vec_read_rs2_ID' failed for line: " & text_line.all
                severity failure;
            report "read vec_read_rs2_ID, arrived to: " & text_line.all;
            --when "vec_write_rd_ID" =>
            elsif data_name(i)(1 to 15) = "vec_write_rd_ID" then
              read(text_line, vec_write_rd_ID_var, ok);
              assert ok
                report "Read 'vec_write_rd_ID' failed for line: " & text_line.all
                severity failure;
            report "read vec_write_rd_ID, arrived to: " & text_line.all;
            --when "dsp_data_gnt_i" =>
            elsif data_name(i)(1 to 14) = "dsp_data_gnt_i" then
              hread(text_line, dsp_data_gnt_i_var, ok);
              assert ok
                report "Read 'dsp_data_gnt_i' failed for line: " & text_line.all
                severity failure;
            report "read dsp_data_gnt_i, arrived to: " & text_line.all;
            --when "dsp_sci_wr_gnt" =>
            elsif data_name(i)(1 to 14) = "dsp_sci_wr_gnt" then
              hread(text_line, dsp_sci_wr_gnt_var, ok);
              assert ok
                report "Read 'dsp_sci_wr_gnt' failed for line: " & text_line.all
                severity failure;
            report "read dsp_sci_wr_gnt, arrived to: " & text_line.all;
            --when "dsp_sc_data_read" =>
            elsif data_name(i)(1 to 16) = "dsp_sc_data_read" then
              for j in 0 to (ACCL_NUM-1) loop
                for k in 0 to 1 loop
                  hread(text_line, dsp_sc_data_read_var(j)(k), ok);
                  assert ok
                    report "Read 'dsp_sc_data_read' failed for index: " & integer'image(j) & ", " & integer'image(k)
                    severity failure;
                  report "read dsp_sc_data_read iteration " & integer'image(j) & ", " & integer'image(k) & ", arrived to: " & text_line.all;
                end loop;
              end loop;
            --when others =>
            --  report "Unknown/ouyput signal name, ignoring: " & data_name(i) severity note;
          --end case;
          end if;
        end loop;
      end if;

    end loop;
  end process test_bench;
end architecture tb_RTL_DSP_TOP_arch;