-- Thermal Sensor Entity with Complex Port Definitions
-- Tests: multiple generics, nested vectors, mixed modes, default assignments

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity thermal_sensor is
    generic (
        DATA_WIDTH       : integer := 8;
        THRESHOLD        : integer := 100;
        SENSOR_ID        : integer := 1;
        ENABLE_FILTERING : boolean := true
    );
    port (
        -- Clock and Reset (standard IJTAG ports)
        clk  : in  std_logic;
        rst_n : in  std_logic;

        -- Temperature Input (vector with expression)
        temp_in : in  std_logic_vector((DATA_WIDTH - 1) downto 0);

        -- Status and Control Outputs
        temp_out : out std_logic_vector((DATA_WIDTH - 1) downto 0);
        alert    : out std_logic;
        status   : out std_logic_vector(2 downto 0);

        -- IJTAG interface ports — must be connected to parent entity IJTAG ports
        ijtag_tdi : in  std_logic;
        ijtag_tdo : out std_logic;
        ijtag_tck : in  std_logic;
        ijtag_tms : in  std_logic;

        -- Bidirectional diagnostic port
        diag_in_out : inout std_logic_vector(7 downto 0);

        -- Buffer output (test edge case)
        buffered_out : buffer std_logic := '0'
    );
end thermal_sensor;

architecture rtl of thermal_sensor is
    signal temp_reg  : std_logic_vector((DATA_WIDTH - 1) downto 0);
    signal alert_reg : std_logic;

begin

    process(clk, rst_n)
    begin
        if rst_n = '0' then
            temp_reg  <= (others => '0');
            alert_reg <= '0';
        elsif rising_edge(clk) then
            temp_reg <= temp_in;
            -- Simple threshold detection
            if unsigned(temp_in) > to_unsigned(THRESHOLD, DATA_WIDTH) then
                alert_reg <= '1';
            else
                alert_reg <= '0';
            end if;
        end if;
    end process;

    temp_out     <= temp_reg;
    alert        <= alert_reg;
    status       <= "00" & alert_reg;
    buffered_out <= temp_reg(0);
    ijtag_tdo    <= '0';

end rtl;
