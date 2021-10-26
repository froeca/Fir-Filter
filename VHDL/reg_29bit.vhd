----------------------------------------------------------------------------------
-- Company: 			Walla Walla University
-- Engineer: 			Caleb Froelich
-- 
-- Create Date:    	00:08:30 05/20/2021 
-- Module Name:    	reg_29bit
-- Project Name: 		Froelich_Lab5
-- Target Devices: 	Xilinx XC6SLX16 in a FTG256 package
-- Tool versions:  	ISE 14.7
-- Description: 		29-bit register with enable and asynchronous reset.
--
-- Dependencies:  	WWU FPGA3 Board
--
-- Version:				1.0  05/20/21
--
-- Additional Comments: 
--							VHDL description based on design from RTL Hardware Design 
--							using VHDL written by Pong P. Chu found on page 477.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity reg_29bit is
	port ( 
		clk   : in std_logic;
		en   	: in std_logic;
		reset	: in std_logic;
		d 		: in signed(28 downto 0);
		q 		: out signed(28 downto 0)
	);
end reg_29bit;

architecture Behavioral of reg_29bit is
begin
	process(clk, reset, en)
	begin
		if reset = '1' then
			q <= (others=>'0');
		elsif (clk'event and clk='1') then
			if (en = '1') then
				q <= d;
			end if;
		end if;
	end process;
end Behavioral;