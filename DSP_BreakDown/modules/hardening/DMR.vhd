-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;

entity DMR is
	port(
		in1, in2 : in std_logic;
		err_flag : out std_logic;
		result : out std_logic
	);
end entity DMR;

architecture DMR_arch of DMR is
begin
	process(in1, in2)
  begin
    if in1 = in2 then
      result <= in1;
      err_flag <= '0';  -- no error
    else
      result <= in1;     -- arbitrary choice
      err_flag <= '1';  -- error detected
    end if;
  end process;
end architecture DMR_arch;
