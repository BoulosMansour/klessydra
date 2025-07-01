-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;

entity TMR is
	port(
		in1, in2, in3 : in std_logic;
		result : out std_logic
	);
end entity TMR;

architecture TMR_arch of TMR is
begin
	result <= (in1 and in2) or (in2 and in3) or (in1 and in3);
end architecture TMR_arch;
