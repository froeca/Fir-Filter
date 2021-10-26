----------------------------------------------------------------------------------
-- Company: 			Walla Walla University
-- Engineer: 			Caleb Froelich
-- 
-- Create Date:    	23:46:30 04/22/2021 
-- Module Name:    	shift_reg_16bit - Behavioral 
-- Project Name: 		Froelich Lab 3
-- Target Devices: 	Xilinx XC6SLX16 in a FTG256 package
-- Tool versions:  	ISE 14.7
-- Description: 		16-bit universal shift register with asynchronous reset.
--
-- Dependencies:  	WWU FPGA3 Board
--
-- Version:				1.0  4/22/21
--
-- Additional Comments: 
--							VHDL description based on design from RTL Hardware Design 
--							using VHDL written by Pong P. Chu found on page 477.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity shift_reg_16bit is
	port(
		clk, reset : in std_logic;
		ctrl : in std_logic_vector(1 downto 0);
		d : in std_logic_vector(15 downto 0);
		q : out std_logic_vector(15 downto 0)
	);
end shift_reg_16bit;

architecture Behavioral of shift_reg_16bit is
	signal r_reg : std_logic_vector(15 downto 0);
	signal r_next : std_logic_vector(15 downto 0);
begin
	-- register
	process(clk, reset)
	begin
		if(reset='1') then
			r_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			r_reg <= r_next;
		end if;
	end process;
	
	-- next state logic, perform arithemetic shifting
	with ctrl select
		r_next <=
			r_reg								when "00", 	 -- pause
			r_reg(14 downto 0) & d(0) 	when "01", 	 -- shift left;
			d(15) & r_reg(15 downto 1) when "10", 	 -- shift right;
			d 									when others; -- load
	-- output logic
	q <= r_reg;

end Behavioral;
