library ieee; 
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all; -- Signed values are used
use ieee.std_logic_arith.all;
use ieee.math_real.all;
library UNISIM;
use UNISIM.vcomponents.all; -- DSP48e1 is used

-- Test bench for CsGnV1p2
entity CsGnV1p2_tb is
end    CsGnV1p2_tb;

architecture Simulation of bit_stuf_tb is

   constant ckMain_Period : time:= 5 ns; -- Main clock period

   -- Clock signals
   signal ckMain : std_logic := '0';   -- Main System Clock
   
   -- Reset
   signal arst_n : std_logic := '0';   -- Asynchronous reset
   
   -- Sending Data 
   signal modulation_mode : std_logic_vector(2 downto 0) := (others=>'0'); -- Modulation mode, QAM16="000", QAM32="001", QAM64="010", QAM128="011", QAM256="100", QAM512="101"
   signal rx_bit_stuf_tdata : std_logic_vector(2 downto 0) := (others=>'0'); -- Data for sending
   
   -- LFSR
   signal PRBS : std_logic_vector(9 downto 0) := (others=>'1'); -- Length 10 LFSR (10) (7)
   
   -- Component under test

component bit_stuf 
    Port ( 
                ckMain: in std_logic;
                arst_n: in std_logic;   -- asynchronous reset
    
      modulation_mode:  in std_logic_vector(2 downto 0);  -- modulation mode, QAM16="000", QAM32="001", QAM64="010", QAM128="011", QAM256="100", QAM512="101"
      send_data:        in std_logic;    
   
     rx_bit_stuf_send: out std_logic;                     -- send data pulse, according to current bandwidth
    rx_bit_stuf_tvalid: in std_logic;                     -- tvalid from framer
    rx_bit_stuf_tdata:  in std_logic_vector(9 downto 0);  -- data from framer
   
     tx_bit_stuf_send: out std_logic;                     -- receive data pulse, according to current bandwidth
   tx_bit_stuf_tvalid: out std_logic;                     -- tvalid from framer
    tx_bit_stuf_tdata: out std_logic_vector(9 downto 0));   -- data from framer

 end component;
 
begin

   -- Main system clock signal generation
   ckMain_process :process  
   begin
      ckMain <= not(ckMain);
      wait for ckMain_Period/2;
   end process;
   
   -- Main process
   LFSR_process: process
   begin
      if rising_edge(ckMain) then
         -- LFSR 10 bit
         PRBS(9 downto 0) <= PRBS(8 downto 0) & (PRBS(9 downto 9) XOR PRBS(7 downto 7));
      end if;
   end process;
   
   
-- DSP_test_MAC: entity work.bit_stuf

 -- port map (
 -- -- Input ports
   -- Ck => ckMain);    -- <inp| Main system clock
   
end Simulation;