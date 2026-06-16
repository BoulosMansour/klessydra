-- Activity Monitor Sensor  --  IEEE 1687 (IJTAG) instrument
--
-- Counts rising-edge toggle events on a single std_logic signal and exposes
-- {alert, activity_count} through a proper IJTAG Test Data Register (TDR).
--
-- The IJTAG client interface is the standard 1687 set of signals driven by the
-- network (a SIB/host inserted by Tessent): tck, reset, sel, ce, se, ue, si, so.
-- All IJTAG *inputs* carry default values so the instance may be left with the
-- ports open in RTL -- Tessent connects them when it inserts the scan network,
-- and Design Compiler accepts the open associations.
--
-- TDR layout (WINDOW_WIDTH+1 bits):  bit[WINDOW_WIDTH] = alert,
--                                    bit[WINDOW_WIDTH-1 .. 0] = activity_count.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity activity_sensor is
    generic (
        SENSOR_ID    : integer := 0;
        WINDOW_WIDTH : integer := 8
    );
    port (
        -- Functional interface
        clk            : in  std_logic;
        rst_n          : in  std_logic;
        signal_in      : in  std_logic;
        activity_count : out std_logic_vector(WINDOW_WIDTH-1 downto 0);
        alert          : out std_logic;

        -- IEEE 1687 client interface (connected by the IJTAG network)
        ijtag_tck      : in  std_logic := '0';   -- scan clock
        ijtag_reset    : in  std_logic := '0';   -- async TDR reset, active high
        ijtag_sel      : in  std_logic := '0';   -- instrument selected
        ijtag_ce       : in  std_logic := '0';   -- capture enable
        ijtag_se       : in  std_logic := '0';   -- shift enable
        ijtag_si       : in  std_logic := '0';   -- scan in
        ijtag_so       : out std_logic           -- scan out
    );
end entity activity_sensor;

architecture rtl of activity_sensor is
    constant TDR_WIDTH : integer := WINDOW_WIDTH + 1;

    -- Functional activity counter (clk domain)
    signal signal_prev : std_logic;
    signal count_reg   : unsigned(WINDOW_WIDTH-1 downto 0);
    signal alert_reg   : std_logic;

    -- IJTAG Test Data Register (tck domain)
    signal tdr : std_logic_vector(TDR_WIDTH-1 downto 0);

    -- Value presented to the TDR at capture time: {alert, count}
    signal capture_value : std_logic_vector(TDR_WIDTH-1 downto 0);
begin

    -- ---------------------------------------------------------------------
    -- Functional activity counter
    -- ---------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            signal_prev <= '0';
            count_reg   <= (others => '0');
            alert_reg   <= '0';
        elsif rising_edge(clk) then
            signal_prev <= signal_in;
            -- Saturating increment on each rising edge of the monitored signal
            if signal_in = '1' and signal_prev = '0' then
                if count_reg /= (count_reg'range => '1') then
                    count_reg <= count_reg + 1;
                end if;
            end if;
            -- Alert fires once the counter passes half scale
            if count_reg(WINDOW_WIDTH-1) = '1' then
                alert_reg <= '1';
            else
                alert_reg <= '0';
            end if;
        end if;
    end process;

    activity_count <= std_logic_vector(count_reg);
    alert          <= alert_reg;

    capture_value <= alert_reg & std_logic_vector(count_reg);

    -- ---------------------------------------------------------------------
    -- IEEE 1687 Test Data Register: capture / shift on tck when selected
    -- ---------------------------------------------------------------------
    process(ijtag_tck, ijtag_reset)
    begin
        if ijtag_reset = '1' then
            tdr <= (others => '0');
        elsif rising_edge(ijtag_tck) then
            if ijtag_sel = '1' then
                if ijtag_ce = '1' then
                    -- Capture the current sensor state
                    tdr <= capture_value;
                elsif ijtag_se = '1' then
                    -- Shift towards so (LSB out first)
                    tdr <= ijtag_si & tdr(TDR_WIDTH-1 downto 1);
                end if;
            end if;
        end if;
    end process;

    ijtag_so <= tdr(0);

end architecture rtl;
