----------------------------------------------------------------------------------
-- Company: 			Walla Walla University
-- Engineer: 			Caleb Froelich
-- 
-- Create Date:    	23:51:45 05/19/2021 
-- Module Name:    	counter_5bit 
-- Project Name: 		Froelich Lab 5
-- Target Devices: 	Xilinx XC6SLX16 in a FTG256 package
-- Tool versions:  	ISE 14.7
-- Description: 		A 5-bit binary counter counting from 0 to 31. Includes enable 
--						 	and asynchronous reset.
--
-- Dependencies:  	WWU FPGA3 Board
--
-- Version:				1.0  05/19/21
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

entity counter_5bit is
	port ( clk, en, reset : in std_logic;
			 q : out unsigned(4 downto 0);
			 tc : out std_logic
		  );
end counter_5bit;

architecture Behavioral of counter_5bit is
	signal r_reg : unsigned (4 downto 0) ;
	signal r_next : unsigned(4 downto 0);
	constant TOP : integer:= 32;
	
begin
	-- register
	process(clk, reset)
	begin
		if (reset='1') then
			r_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			r_reg <= r_next;
		end if;
	end process;
	
	-- next-state logic
	process(en, r_reg)
	begin
		r_next <= r_reg;
		if (en='1') then
			if r_reg=(TOP-1) then
				r_next <= (others=>'0');
			else
				r_next <= r_reg + 1;
			end if;
		end if;
	end process;
	
	-- output logic
	q <= r_reg;
	tc <= '1' when r_reg = (TOP-1) else '0';
	
end Behavioral;