-----------------------------------------------------------------------------
--        File: adc_driver_ip_ver3.vhd
--
-- Description:  A driver module to read data from a MCP3201 ADCI
--          by:  L.Aamodt
--         rev:  rev3.1, 5/25/20
--    hardware:  For use with the WWU Pmod A/D - D/A board
--       notes:  
--
--
-----------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

entity adc_driver_ip is
	Port (
		adc_data_word : out std_logic_vector(11 downto 0);
		adc_bit_data : in std_logic;
		adc_cs_bar : out std_logic;
		start : in std_logic;
		cnt17 : out std_logic;
		bclk : in std_logic
	);
end adc_driver_ip;

architecture behavioral of adc_driver_ip is
	type state_type is (st_a, st_b, st_c, st_d, st_e);
	signal adc_ctrl_reg, adc_next_state : state_type;
	signal five_bit_reg, five_bit_next : unsigned(4 downto 0);
	signal shift_reg, shift_next : std_logic_vector(11 downto 0);
	signal adc_data_reg : std_logic_vector(11 downto 0);
	signal cnt13 : std_logic;
	signal load_data_mem, reset_counter : std_logic;
	
begin
	------ ADC controller
	process(bclk)
	begin
		if (bclk'event and bclk='1') then
			adc_ctrl_reg <= adc_next_state;
		end if;
	end process;
	
	process(adc_ctrl_reg,start,cnt13)
	begin
		adc_next_state <= adc_ctrl_reg;
		adc_cs_bar <= '1';
		load_data_mem <='0';
		reset_counter <= '0';
		cnt17 <= '0';
		case adc_ctrl_reg is
			when st_a =>       -- data is received in this state
				if (cnt13='1') then   -- counter running
					adc_next_state <= st_b;
				end if;
				adc_cs_bar <='0';
			when st_b =>       -- counter running
				adc_next_state <= st_c;
				load_data_mem <='1'; 				
			when st_c =>       -- counter running
				adc_next_state <= st_d;
				adc_cs_bar <='1';
			when st_d =>       -- counter running
				adc_next_state <= st_e;
				adc_cs_bar <='1';
			when st_e =>       -- idle state. counter stopped
				if (start='1') then 
					adc_next_state <= st_a;
				end if;
				adc_cs_bar <='1';
				reset_counter <='1';
				cnt17 <= '1';
		end case;
	end process;
	
	
	------ 5 bit counter
	process(bclk)   -- memory for ADC state machine controller
	begin
		if (bclk'event and bclk='1') then
			five_bit_reg <= five_bit_next;	
		end if;
	end process;
	five_bit_next <= (others=>'0') when (five_bit_reg=17 or reset_counter='1')
	                               else  five_bit_reg + 1;
	cnt13 <= '1' when five_bit_reg = 13 else '0';
--	cnt17 <= '1' when five_bit_reg = 17 else '0';
	
	------ A/D shift register
	process(bclk)
	begin            -- clocked on falling edge bclk - middle of data bit
		if (bclk'event and bclk='0') then
			shift_reg <= shift_next;
		end if;
	end process;
	shift_next <= shift_reg(10 downto 0) & adc_bit_data;
	
	------ A/D data holding register
	process(bclk, load_data_mem)
	begin
		if (bclk'event and bclk='1') then
			if (load_data_mem = '1') then
				adc_data_reg <= shift_reg;
			end if;
		end if;
	end process;
	adc_data_word <= adc_data_reg;
end behavioral;
