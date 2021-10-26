-----------------------------------------------------------------------------
--        File: dac_driver_ip_ver4.vhd
--
-- Description:  A driver module to send data to a MCP4822 DAC
--          by:  L.Aamodt
--         rev:  rev4, 6/07/20 state 0 removed from controller state machine
--               rev3, 5/19/20 prior version
--    hardware:  For use with the WWU Pmod A/D - D/A board
--       notes:  Clock frequency maximum is 10 Mhz
--               channel_select = "0" for channel A, "1" for channel B
--
----------------------------------------------------------------------------- 
library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;

entity dac_driver_ip is
	port(
		bclk : in std_logic;
		dac_data : in std_logic_vector(11 downto 0);
		send_en : in std_logic;
		channel_select : in std_logic;
	   dac_sdi, dac_cs_bar, dac_ldac_bar : out std_logic
		);
end dac_driver_ip;

architecture behavioral of dac_driver_ip is
	type state_type is (st_a, st_b, st_c, st_d);
	signal control_reg : state_type;
	signal control_next_state: state_type;
	signal dac_state_reg, dac_next_state : unsigned(4 downto 0);
	signal dac_data_reg, dac_data_next : std_logic_vector(15 downto 0);
	signal load_dac_register, cs_bar, reset_counter, clk15 : std_logic;

begin
	------ DAC controller
	process(bclk)
	begin
		if (bclk'event and bclk='1') then
			control_reg <= control_next_state;
		end if;
	end process;
	
	process(control_reg,send_en,clk15)
	begin
		control_next_state <= control_reg;
		dac_cs_bar <= '1';
		dac_ldac_bar <='1';
		load_dac_register <='0';
		reset_counter <= '0';
		case control_reg is
			when st_a =>       -- idle state
				if (send_en='1') then 
					control_next_state <= st_b;
				end if;
				reset_counter <='1';
				load_dac_register <='1';
			when st_b =>       -- data is sent in this state
				if (clk15='1') then
					control_next_state <= st_c;
				end if;
				dac_cs_bar <='0';
			when st_c =>       -- dac_cs_bar is de-asserted in this state
				control_next_state <= st_d;
			when st_d =>       -- dac register loaded
				if (send_en='1')then 
					control_next_state <= st_b;
				else
					control_next_state <= st_d;
				end if;
				dac_ldac_bar <='0';
				load_dac_register <='1';
		end case;
	end process;
	
	------ DAC state machine (counter) counts clock ticks
	process(bclk)
	begin
		if (bclk'event and bclk='1') then
			dac_state_reg <= dac_next_state;
		end if;
	end process;
	dac_next_state <= (others=>'0') when (dac_state_reg=17 or reset_counter='1')
	                                else dac_state_reg+1;
	clk15 <= '1' when dac_state_reg=15 else '0';

	------ DAC data shift register
	process(bclk, load_dac_register)
	begin
		if (bclk'event and bclk='1') then
			if (load_dac_register = '1') then
				dac_data_reg <= channel_select & "111" & dac_data;
			else
				dac_data_reg <= dac_data_next;
			end if;
		end if;
	end process;
	dac_data_next <= dac_data_reg(14 downto 0) & '0';
	dac_sdi <= dac_data_reg(15);
end Behavioral;

