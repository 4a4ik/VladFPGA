library ieee; 
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all; -- Signed values are used
use ieee.std_logic_arith.all;
use ieee.math_real.all;


-- Test bench for bit_stuf_tb
entity bit_stuf_tb is
end    bit_stuf_tb;

architecture Behavioral of bit_stuf_tb is

   -- entity bit_stuf is
    -- Port ( ckMain : in STD_LOGIC;
           -- arst_n: in STD_LOGIC;   -- asynchronous reset
    
           -- modulation_mode:  in STD_LOGIC_VECTOR(2 downto 0);     -- modulation mode, QAM16="000", QAM32="001", QAM64="010", QAM128="011", QAM256="100", QAM512="101"
           -- send_data:        in std_logic;    
           
           -- rx_bit_stuf_send: out std_logic;                       -- send data pulse, according to current bandwidth
           -- rx_bit_stuf_tvalid: in STD_LOGIC;                      -- tvalid from framer
           -- rx_bit_stuf_tdata:  in STD_LOGIC_VECTOR(9 downto 0);   -- data from framer
           
           -- tx_bit_stuf_send: out std_logic;                       -- receive data pulse, according to current bandwidth
           -- tx_bit_stuf_tvalid: out STD_LOGIC;                     -- tvalid from framer
           -- tx_bit_stuf_tdata:  out STD_LOGIC_VECTOR(9 downto 0)   -- data from framer
       -- );
   -- end bit_stuf;


   constant Cs_Ck_Period : time:= 4 ns; -- Main clock period

   -- Clock signals
   signal ckCs : std_logic := '0'; -- Main System Clock
   
   -- Counters
   signal packet_count : integer range 0 to 2 = 0;
   
   -- Control signals
   signal modulation_mode : std_logic_vector(2 downto 0) := (others=>'0'); -- Modulation mode, QAM16="000", QAM32="001", QAM64="010", QAM128="011", QAM256="100", QAM512="101"
   
   -- LFSR
   signal PRBS : std_logic_vector(9 downto 0) := (others=>'1'); -- Length 10 LFSR (10) (7)
   
   -- Output data
   signal tx_bit_stuf_tdata : std_logic_vector(9 downto 0) := (others=>'0');
   signal tx_bit_ou : std_logic_vector(9 downto 0) := (others=>'0');
   
begin

   -- Main system clock signal generation
   Cs_Ck_process :process  
   begin
      ckCs <= not(ckCs);
      wait for Cs_Ck_Period/2;
   end process;
   
      -- Main process
   process(ckCs)
   begin
      if rising_edge(ckCs) then
         case packet_count is
                 when 0 => tx_bit_ou(9 downto 0) <= ext("1", 10); 
                 when 1 => tx_bit_ou(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0); 
            when others => tx_bit_ou(9 downto 0) <= ext("1", 10); 
         end case;
         
         -- Counter
         packet_count <= packet_count + 1;
         
         -- LFSR 10 bit
         PRBS(9 downto 0) <= PRBS(8 downto 0) & (PRBS(9 downto 9) XOR PRBS(7 downto 7));
         
         -- Sets the number of information bits in a packet
         case modulation_mode(2 downto 0) is
            when "000"  => tx_bit_stuf_tdata(9 downto 0) <= ("000000" & PRBS(3 downto 0)); -- QAM16
            when "001"  => tx_bit_stuf_tdata(9 downto 0) <= ("00000"  & PRBS(4 downto 0)); -- QAM32
            when "010"  => tx_bit_stuf_tdata(9 downto 0) <= ("0000"   & PRBS(5 downto 0)); -- QAM64
            when "011"  => tx_bit_stuf_tdata(9 downto 0) <= ("000"    & PRBS(6 downto 0)); -- QAM128
            when "100"  => tx_bit_stuf_tdata(9 downto 0) <= ("00"     & PRBS(7 downto 0)); -- QAM256
            when others => tx_bit_stuf_tdata(9 downto 0) <= ("0"      & PRBS(8 downto 0)); -- QAM512
         end case;
         
      end if;
   end process;

   
end Behavioral;