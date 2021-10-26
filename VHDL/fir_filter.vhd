----------------------------------------------------------------------------------
-- Company: 	  Walla Walla University
-- Engineer: 	  Caleb Froelich
-- 
-- Create Date:    16:15:12 05/13/2021 
-- Design Name: 	  Fir Filter Design
-- Module Name:    fir_filter - Behavioral 
-- Project Name:   Froelich_Lab5
-- Target Devices: Xilinx XC6SLX16 in a FTG256 package
-- Tool versions:  ISE 14.7
-- Description:	  A 32-tap FIR filter design.
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity fir_filter is
	port (
		mclk : in std_logic;
		-- FROM ADC
		adc_bit_data : in std_logic;   -- pmod(3)
		-- TO ADC
		adc_cs_bar : out std_logic;	 -- pmod(1)
		adc_sclk : out std_logic;  	 -- pmod(4)
		-- TO DAC
		pmod1 : out std_logic_vector(8 downto 5);
		-- SELECTOR
		sw0, sw1, sw6, sw7, sw2 : in std_logic;
		-- DEBUGGING
		-- extout : out std_logic_vector(8 downto 0);
		-- tek1 : out std_logic_vector(7 downto 0);
		-- tek2 : out std_logic_vector(7 downto 0)
	);
end fir_filter;

architecture Behavioral of fir_filter is
	-- ############## COMPONENT DECLARATION ##############
	component counter_5bit is
		port ( 
			clk 	: in std_logic;
			en    : in std_logic;
			reset	: in std_logic;
			q 		: out unsigned(4 downto 0);
			tc 	: out std_logic
		);
	end component;
	
	component adc_driver_ip is
		port (
			adc_data_word : out std_logic_vector(11 downto 0);
			adc_bit_data  : in std_logic;
			adc_cs_bar 	  : out std_logic;
			start 		  : in std_logic;
			cnt17 		  : out std_logic;
			bclk 			  : in std_logic
		);
	end component;
	
	component coef_rom is
		generic(
			ADDR_WIDTH : integer := 7;
			DATA_WIDTH : integer := 12
		);
		port(
			clk    : in std_logic;
			en 	 : in std_logic;
			addr_r : in std_logic_vector(ADDR_WIDTH-1 downto 0);
			dout   : out std_logic_vector(DATA_WIDTH-1 downto 0)
		);
	end component;
	
	component reg_29bit is
		port ( 
			clk   : in std_logic;
			en   	: in std_logic;
			reset	: in std_logic;
			d 		: in signed(28 downto 0);
			q 		: out signed(28 downto 0)
		);
	end component;
	
	component dac_driver_ip is
		port (
			bclk : in std_logic;
			dac_data : in std_logic_vector(11 downto 0);
			send_en : in std_logic;
			channel_select : in std_logic;
			dac_sdi, dac_cs_bar, dac_ldac_bar : out std_logic
		);
	end component;
	
	-- ############## SIGNAL DECLARATION ##############
	-- CLOCK DIVIDER : 3.571 MHz and 892.8 kHz clocks
	signal sclk_next, sclk_reg : unsigned(4 downto 0);	-- 892.8 kHz
	signal cclk_next, cclk_reg : unsigned(2 downto 0);	-- 3.571 MHz

	signal t_sclk_reg, t_sclk_next : std_logic; -- 892.8 kHz
	signal t_cclk_reg, t_cclk_next : std_logic; -- 3.571 MHz
	
	signal sclk, bclk, cclk, dclk : std_logic;	-- dclk is a buffered clock signal
	
	-- STATE MACHINE MEM
	type state_type is (s_0, s_1, s_2, s_3, s_4, s_5, s_6, s_7, s_8, s_9);
	signal state_reg, next_state : state_type;
	
	-- COMBINATIONAL CALCS
	signal product : signed(23 downto 0);
--	signal product_vec : std_logic_vector(23 downto 0);
	
	-- 5-BIT COUNTER : ADDRESS
	signal en_cntr : std_logic;
	signal addr_count : unsigned(4 downto 0);  -- TODO : check type.
	signal tc : std_logic;
	
	-- 5-BIT COUNTER : OFFSET
	signal addr_offset : unsigned(4 downto 0);  -- TODO : check type.

	-- SOP 29-BIT REGISTER
	signal d_reg, q_reg : signed(28 downto 0);
	signal clear_reg : std_logic;
	
	-- COEFFICIENT RAM
	signal en_RAM_c : std_logic;
	signal addr : std_logic_vector(6 downto 0);	-- address for RAM coeff
	--signal cdata : signed(11 downto 0);
	--signal cdata_vec : std_logic_vector(11 downto 0);
	
	-- DATA RAM
	signal en_RAM_d : std_logic;
	type data_array is array (0 to 31) of std_logic_vector(11 downto 0);
	signal data_RAM : data_array;
	
	type coeff_array is array (0 to 127) of std_logic_vector (11 downto 0);
   constant coeff_ROM : coeff_array:=( -- 127 x 12 bits
----  A set of coefficients with a bunch of ones
----  Useful in debugging to TODO --->
      x"000", x"000", x"000", x"000", x"000", x"000", x"000", x"000",
      x"000", x"000", x"000", x"000", x"000", x"000", x"000", x"000",
      x"000", x"000", x"000", x"000", x"000", x"000", x"000", x"000",
      x"000", x"000", x"000", x"000", x"000", x"000", x"000", x"001",
----  Set of coefficients to make sure that output FFs are not 0
      x"FFF", x"000", x"000", x"000", x"000", x"000", x"000", x"000",
      x"000", x"000", x"000", x"000", x"000", x"000", x"000", x"000",
      x"000", x"000", x"000", x"000", x"000", x"000", x"000", x"000",
      x"000", x"000", x"000", x"000", x"000", x"000", x"000", x"000",
----  A set of coefficients with a bunch of ones
----  Useful in debugging to TODO --->
--    x"001", x"001", x"001", x"001", x"001", x"001", x"001", x"001",
--    x"001", x"001", x"001", x"001", x"001", x"001", x"001", x"001",
--    x"001", x"001", x"001", x"001", x"001", x"001", x"001", x"001",
--    x"001", x"001", x"001", x"001", x"001", x"001", x"001", x"001", 
----  Low-pass filter coefficients, cutoff frequency = 300Hz
---- 	Sampling frequency = 50 kHz
      x"094", x"0C9", x"106", x"148", x"18F", x"1DA", x"226", x"273",
      x"2BE", x"306", x"347", x"381", x"3B2", x"3D7", x"3F1", x"3FE",
      x"3FE", x"3F1", x"3D7", x"3B2", x"381", x"347", x"306", x"2BE",
      x"273", x"226", x"1DA", x"18F", x"148", x"106", x"0C9", x"094",
---- 	Low-pass filter coefficients, cutoff frequency = 5kHz
----  Sampling frequency = 50 kHz
		x"F9E", x"F62", x"F2D", x"F0C", x"F0A", x"F32", x"F8C", x"01A",
      x"0D9", x"1C0", x"2C0", x"3C5", x"4BA", x"589", x"61F", x"66E",
      x"66E", x"61F", x"589", x"4BA", x"3C5", x"2C0", x"1C0", x"0D9",
      x"01A", x"F8C", x"F32", x"F0A", x"F0C", x"F2D", x"F62", x"F9E");
---- 	Low-pass filter coefficients, cutoff frequency = 400Hz
----  Sampling frequency = 20 kHz
--		x"F9E", x"F62", x"F2D", x"F0C", x"F0A", x"F32", x"F8C", x"01A",
--    x"0D9", x"1C0", x"2C0", x"3C5", x"4BA", x"589", x"61F", x"66E",
--    x"66E", x"61F", x"589", x"4BA", x"3C5", x"2C0", x"1C0", x"0D9",
--    x"01A", x"F8C", x"F32", x"F0A", x"F0C", x"F2D", x"F62", x"F9E",
----  A set of coefficients with sequencial values 0 to 31
----  Useful in debugging to confirm correct coefficient selection
--    x"000", x"001", x"002", x"003", x"004", x"005", x"006", x"007",
--    x"008", x"009", x"00A", x"00B", x"00C", x"00D", x"00E", x"00F",
--    x"010", x"011", x"012", x"013", x"014", x"015", x"016", x"017",
--    x"018", x"019", x"01A", x"01B", x"01C", x"01D", x"01E", x"01F" );
	
	-- ADC DRIVER IP
	-- TODO : check these signals
	signal adata : std_logic_vector(11 downto 0);
	signal adata_no_offset : std_logic_vector(11 downto 0);
	signal cnt17 : std_logic;
	
	-- DAC DRIVER
	alias cs : std_logic is pmod1(5);
	alias sdata : std_logic is pmod1(6);
	alias load : std_logic is pmod1(7);
	alias dac_sclk : std_logic is pmod1(8);
	
	-- ACCUMULATOR SELECT
	signal sw76 : std_logic_vector(1 downto 0);
	signal FIR_data : signed(11 downto 0);
	signal FIR_data_shifted : signed(11 downto 0);
	signal FIR_data_vec : std_logic_vector(11 downto 0);
	
	-- Debugging
	signal load_dac : std_logic;
	signal start_adc_dac : std_logic;
--	signal data : std_logic_vector(11 downto 0);
--	signal ram_c_data : std_logic_vector(11 downto 0);
	
begin
	----------- OUTPUT SIGNALS -------------
	extout <= (
		others => '0'
	);

------- DEBUGGING #1
--	tek1 <= (
--		0 => cclk, 
--		1 => en_RAM_d,
--		2 => en_RAM_c,
--		3 => std_logic(addr_count(0)),
--		4 => tc,
--		5 => std_logic(addr_offset(0)),
--		6 => std_logic(q_reg(0)),
--		others => '0'
--	);
--	
--	tek2 <= (
--		0 => sclk, 
--		1 => bclk, 
--		2 => cnt17,
--		3 => clear_reg,
--		4 => addr_count(4),
--		5 => tc,
--		6 => '0',
--		others => '0'
--	);

------- DEBUGGING #2
--	tek1 <= (
--		0 => cclk, 
--		1 => en_RAM_d, 
--		2 => en_RAM_c,
--		3 => std_logic(addr_count(0)),
--		4 => std_logic(addr_count(1)),
--		5 => std_logic(addr_count(2)),
--		6 => std_logic(addr_count(3)),
--		7 => std_logic(addr_count(4))
--	);
--	
--	tek2 <= (
--		0 => tc, 
--		1 => std_logic(addr_offset(0)), 
--		2 => std_logic(addr_offset(1)),
--		3 => std_logic(addr_offset(2)),
--		4 => std_logic(addr_offset(3)),
--		5 => std_logic(addr_offset(4)),
--		6 => sclk,
--		7 => cnt17
--	);

------- DEBUGGING #3
--	tek1 <= (
--		0 => cclk, 
--		1 => en_RAM_d,
--		2 => std_logic(addr_count(0)),
--		3 => ram_c_data(0),
--		4 => ram_c_data(1),
--		5 => ram_c_data(2),
--		6 => ram_c_data(3),
--		7 => ram_c_data(4)
--	);
--	tek2 <= (
--		0 => data(0),
--		1 => data(1),
--		2 => data(2),
--		3 => data(3),
--		4 => data(4),
--		5 => tc,
--		6 => cnt17,
--		7 => cnt17
--	);

------- DEBUGGING #4
--	tek1 <= (
--		0 => cclk, 
--		1 => en_RAM_d,
--		2 => en_RAM_c,
--		3 => data(0),
--		4 => data(1),
--		5 => data(2),
--		6 => data(3),
--		7 => data(4)
--	);
--	
--	tek2 <= (
--		0 => cdata_vec(0),
--		1 => product_vec(0),
--		2 => product_vec(1),
--		3 => product_vec(2),
--		4 => product_vec(3),
--		5 => product_vec(4),
--		6 => data(11),
--		7 => cnt17
--	);

------- DEBUGGING #5
--	tek1 <= (
--		0 => sclk, 
--		1 => load_dac, --en_RAM_d,
--		2 => en_RAM_c,
--		3 => cnt17,
--		4 => FIR_data_vec(0),
--		5 => FIR_data_vec(1),
--		6 => FIR_data_vec(2),
--		7 => FIR_data_vec(3)
--	);
--	
--	tek2 <= (
--		0 => FIR_data_vec(4),
--		1 => FIR_data_vec(5),
--		2 => FIR_data_vec(6),
--		3 => FIR_data_vec(7),
--		4 => FIR_data_vec(8),
--		5 => FIR_data_vec(9),
--		6 => FIR_data_vec(10),
--		7 => clear_reg
--	);

-- Debugging signals:
--	product_vec <= std_logic_vector(product);
--	ram_c_data <= coeff_ROM(to_integer(sw1 & sw0 & addr_count));
--	data <= data_RAM(to_integer(addr_count + addr_offset));
--	FIR_data_vec <= std_logic_vector(FIR_data_shifted);

	----------- END OUTPUT SIGNALS ---------
	
	----------- COMBINATIONAL CALCS --------
	
	product <= signed(coeff_ROM(to_integer(sw1 & sw0 & addr_count))) * signed(data_RAM(to_integer(addr_count + addr_offset)));
	d_reg <= resize(product + q_reg, 29);  -- resize the vector and maintain the sign bit.
	
	----------- END COMBINATIONAL CALCS ----
	
	----------- 5-BIT COUNTER --------------
	--         (ADDRESS COUNT)     		  --
	-- port map (clk, en, reset, q<5>, tc);
	U1 : counter_5bit
		port map ( 
			clk 	=> cclk,
			en 	=> en_cntr,
			reset	=> '0',
			q 		=> addr_count,
			tc 	=> tc
		);
	----------- END 5-BIT COUNTER ----------
	
	----------- 5-BIT COUNTER --------------
	--         (OFFSET COUNT)     		  --
	-- port map (clk, en, reset, q<5>, tc);
	U2 : counter_5bit
		port map ( 
			clk 	=> cclk,
			en 	=> en_RAM_d, -- offset is the location of the oldest data.
			reset	=> '0',
			q 		=> addr_offset,
			tc 	=> open
		);
	----------- END 5-BIT COUNTER ----------
	
	----------- SOP 29-BIT REGISTER --------
	-- port map (clk, en, reset, d<30>, q<30>);
	U3 : reg_29bit
		port map (
			clk 	=> cclk,
			en 	=> en_RAM_c, --tc,
			reset	=> clear_reg,
			d 		=> d_reg,
			q 		=> q_reg
		);
	----------- END SOP 29-BIT REGISTER ----
	
	----------- DATA RAM -------------------
	process(cclk, en_RAM_d)
	begin
		-- write the new data
		if(cclk'event and cclk='1') then
			if(en_RAM_d = '1') then
				data_RAM(to_integer(addr_offset)) <= adata_no_offset;
			end if;
		end if;
	end process;
	----------- END DATA RAM ---------------
	
	----------- ADC DRIVER IP --------------
	-- port map (adc_data_word<12>, adc_bit_data, adc_cs_bar, start, cnt17, bclk);
	U5 : adc_driver_ip
		port map (
			adc_data_word => adata,
			adc_bit_data  => adc_bit_data,
			adc_cs_bar 	  => adc_cs_bar,
			start 		  => '1',  				-- continuous conversions
			cnt17 		  => cnt17,
			bclk 			  => bclk
		);
	adc_sclk <= sclk; -- defined in .ucf, pmod1(4)
	
	-- remove the offset from the adc data
	adata_no_offset <= std_logic_vector(signed(adata) + to_signed(2048,12));
	----------- END ADC DRIVER IP ----------
	
	----------- DAC DRIVER -----------------
	-- port map (bclk, dac_data<12>, send_en, channel_select, dac_sdi, dac_cs_bar, dac_ldac_bar);
	U6 : dac_driver_ip
		port map (
			bclk 				=> bclk,  	-- 892.8 kHz
			dac_data 		=> std_logic_vector(FIR_data_shifted),
			send_en  		=> cnt17,		-- continuously sending data
			channel_select => sw2,		-- channel B (TODO: implement as a switch)
			dac_sdi 			=> sdata, 	-- alias of pmod1(6);
			dac_cs_bar 		=> cs,	 	-- alias of pmod1(5);
			dac_ldac_bar	=> load_dac -- alias of pmod1(7);
		);
		
	load <= load_dac; -- DEBUGGING
	dac_sclk <= sclk; -- alias of pmod1(8)
	----------- END DAC DRIVER -------------
	
	----------- ACCUMULATOR SELECT ---------
	-- select the data
	sw76 <= sw7 & sw6;
	FIR_data <= (q_reg(28) & q_reg(10 downto 0)) when (sw76="00") else
					(q_reg(28) & q_reg(15 downto 5)) when (sw76="01") else
					(q_reg(28) & q_reg(20 downto 10)) when (sw76="10") else
					(q_reg(28) & q_reg(25 downto 15));
					
	FIR_data_shifted <= FIR_data + to_signed(2047, 12);
	----------- END ACCUMULATOR SELECT -----

	----------- CLOCK DIVIDER --------------
	process(mclk)
	begin
		if (mclk'event and mclk='1') then
			sclk_reg <= sclk_next;
			cclk_reg <= cclk_next;
			t_sclk_reg <= t_sclk_next;
			t_cclk_reg <= t_cclk_next;
		end if;
	end process;
	
	-- next state register values
	sclk_next <= (others=>'0') when sclk_reg=27 else sclk_reg+1;  	-- divide by 56.
	cclk_next <= (others=>'0') when cclk_reg=6 else cclk_reg+1;	  	-- divide by 14.
	-- toggle flip-flops
	t_sclk_next <= not t_sclk_reg when sclk_reg=27 else t_sclk_reg;
	t_cclk_next <= not t_cclk_reg when cclk_reg=6 else t_cclk_reg;
	
	sclk <= t_sclk_reg;		-- 892.8 kHz derived clock.
	cclk <= t_cclk_reg;		-- 3.571 MHz derived clock.
	bclk <= not sclk;			-- bclk is inverse of sclk, but not buffered.
	
	Clk_Buffer: BUFG       	-- Put sclk on a buffered clock line
		port map ( I => sclk, O => dclk);
	----------- END CLOCK DIVIDER ----------
	
	
-- ############## FINITE STATE MACHINE ##############

	----------- STATE MACHINE MEM ----------
	process(cclk)
	begin
		if (cclk'event and cclk='1') then
			state_reg <= next_state;
		end if;
	end process;
	----------- END STATE MACHINE MEM ------
	
	----------- NEXT STATE LOGIC -----------
	-------------- (and OFL) ---------------

	process(state_reg, cnt17, tc)
	begin
		-- default values
		en_RAM_d <= '0';
		en_RAM_c <= '0';
		en_cntr <= '0';
		clear_reg <= '0';
		-- start_adc_dac <= '0';
		
		case state_reg is
			when s_0 =>
				if (cnt17 = '1') then
					next_state <= s_1;
				else
					next_state <= s_0;
				end if;
				-- OFL
				-- no output values
			when s_1 => 
				next_state <= s_2;
				-- start_adc_dac <= '1';
			when s_2 => 
				next_state <= s_3;
				-- OFL
				en_RAM_d <= '1';
			when s_3 =>
				next_state <= s_4;
			when s_4 =>
				next_state <= s_5;
			when s_5 =>
				next_state <= s_6;
			when s_6 =>
				next_state <= s_7;
				clear_reg <= '1';
			when s_7 =>
				if (tc = '1') then
					next_state <= s_0;
				else
					next_state <= s_7;
				end if;
				-- OFL
				en_RAM_c <= '1';
				en_cntr <= '1';
			when others =>
				next_state <= s_0;
		end case;
	end process;
	----------- END NEXT STATE LOGIC -------
	---------------- (and OFL) -------------
	
end Behavioral;

