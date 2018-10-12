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
   
   -- Start of file, end of file constants
   constant SOF : std_logic_vector(7 downto 0) := "01111111";
   constant EOF : std_logic_vector(7 downto 0) := "01111111";
   
   -- Clock signals
   signal ckCs : std_logic := '0'; -- Main System Clock
   signal ckCe : std_logic := '1'; -- Main System Clock Enable
   signal ckPs : std_logic := '0'; -- Pulse
   
   -- Counters
   signal data_BW : integer := 10;
   signal count_range : integer := 4;
   signal packet_count : std_logic_vector(9 downto 0) := (others=>'0');
   signal packet_count_int :integer range 0 to count_range := 0;
   signal clock_count : std_logic_vector(4 downto 0) := (others=>'0');
   signal symbols_num : std_logic_vector(4 downto 0) := (others=>'1'); -- Number of data symbols
   signal current_data : std_logic_vector(data_BW-1 downto 0) := (others=>'0'); -- Data arriving now
   signal previous_data : std_logic_vector(data_BW-1 downto 0) := (others=>'0'); -- Previous data values
   signal data_mask : std_logic_vector(data_BW-1 downto 0) := (others=>'0');
   signal n : integer range 0 to 9 := 0;
   signal zeros_number : integer range 0 to data_BW := 0;
   signal zeros_number_2 : integer range 0 to data_BW := 0;
   signal ones_flag : std_logic_vector(0 downto 0) := "0";
   
   -- Control signals
   signal modulation_mode : std_logic_vector(2 downto 0) := (others=>'0'); -- Modulation mode, QAM16="000", QAM32="001", QAM64="010", QAM128="011", QAM256="100", QAM512="101"
   
   -- LFSR
   signal PRBS : std_logic_vector(9 downto 0) := (others=>'1'); -- Length 10 LFSR (10) (7)
   
   -- Output data
   signal tx_bit_stuf_tdata : std_logic_vector(9 downto 0) := (others=>'0');
   signal tx_bit_ou : std_logic_vector(9 downto 0) := (others=>'0');
   signal tx_bit_ou_conc : std_logic_vector(20 downto 0) := (others=>'0');
   signal tx_bit_ou_Rg : std_logic_vector(9 downto 0) := (others=>'0');
   
begin

   tx_bit_ou_conc(20 downto 0) <= ("0" & (tx_bit_ou_Rg(9 downto 0) & tx_bit_ou(9 downto 0)));
   
   -- Main system clock signal generation
   -- Cs_Ck_process :process  
   -- begin
      -- ckCs <= not(ckCs);
      -- wait for Cs_Ck_Period/2;
   -- end process;
      Cs_Ck_process : process  
   begin
      ckCs <= '1';
      wait for Cs_Ck_Period/2;
      ckCs <= '0';
      wait for Cs_Ck_Period/2;
   end process;

      -- Main system clock signal generation
   Ps_Ck_process : process  
   begin
      ckPs <= '1';
      wait for (Cs_Ck_Period/2);
      ckPs <= '0';
      wait for (5)*(Cs_Ck_Period/2); -- Duty cycle, 3 for 1/4, 5 for 1/6 
   end process;
 
      -- Main process
   process(ckCs)
      variable ones_count : integer range 0 to data_BW := 0; -- Stores the number of found 1s
      variable ones_count_2 : integer range 0 to 2*(data_BW-1) := 0;
   begin
      if rising_edge(ckCs) then
      if ckCe = '1' then
         ones_count := 0;
         for n in 0 to 9 loop
            if tx_bit_ou(n) = '1' then
               ones_count := ones_count + 1;
             else
               ones_count := ones_count;
            end if;
         end loop;
         
         ones_count_2 := 0;
         for n in 0 to 2*(data_BW) loop
            if tx_bit_ou_conc(n) = '1' then
               ones_count_2 := ones_count_2 + 1;
             else
               ones_count_2 := ones_count_2;
            end if;
         end loop;
         
         if ones_count >= 7 then
            ones_flag(0 downto 0) <= "1";
         else
            ones_flag(0 downto 0) <= "0";
         end if;

         --        Counter
         -- < "00" ><"01">< "10" >
         -- <100..0><DATA><100..0>
         if packet_count(9 downto 0) = conv_std_logic_vector(count_range-1,10)  then
            packet_count(9 downto 0) <= (others=>'0');
         else
            packet_count(9 downto 0) <= packet_count(9 downto 0) + ext("1",10);
         end if;
         
         -- Integer symbols counter
         if (packet_count_int = count_range-1) then
            packet_count_int <= 0;
         else
            packet_count_int <= packet_count_int + 1;
         end if;
         
         -- -- Choosing right output
         -- case packet_count is
            -- when  "00" => tx_bit_ou(9 downto 0) <= "1" & ext("0", 9); 
            -- when  "01" => tx_bit_ou(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0); 
            -- when others => tx_bit_ou(9 downto 0) <= "1" & ext("0", 9);  
         -- end case;
         
         -- -- Choosing right output
         -- case packet_count(9 downto 0) is
            -- when ext("0", 10) => tx_bit_ou(9 downto 0) <= "1" & ext("0", 9); 
            -- when conv_std_logic_vector(count_range,10) => tx_bit_ou(9 downto 0) <= "1" & ext("0", 9); 
            -- when others => tx_bit_ou(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0); 
         -- end case;
         
          -- Choosing right output
         if packet_count(9 downto 0) = ext("0", 10) then
            tx_bit_ou(9 downto 0) <= "1" & ext("0", 9);
         elsif packet_count(9 downto 0) = ext("0", 10) then            
            tx_bit_ou(9 downto 0) <= "1" & ext("0", 9); 
         else
            tx_bit_ou(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0); 
         end if;
         
         
         -- PRBS 10-bit
         if packet_count(1 downto 0) = "01" then
            -- LFSR 10 bit
            PRBS(9 downto 0) <= PRBS(8 downto 0) & (PRBS(9 downto 9) XOR PRBS(7 downto 7));
         else
            PRBS(9 downto 0) <= PRBS(9 downto 0);
         end if;
         
         -- Sets the number of information bits in a packet
         case modulation_mode(2 downto 0) is -- Change to any CE
            when "000"  => tx_bit_stuf_tdata(9 downto 0) <= ("000000" & PRBS(3 downto 0)); -- QAM16
            when "001"  => tx_bit_stuf_tdata(9 downto 0) <= ("00000"  & PRBS(4 downto 0)); -- QAM32
            when "010"  => tx_bit_stuf_tdata(9 downto 0) <= ("0000"   & PRBS(5 downto 0)); -- QAM64
            when "011"  => tx_bit_stuf_tdata(9 downto 0) <= ("000"    & PRBS(6 downto 0)); -- QAM128
            when "100"  => tx_bit_stuf_tdata(9 downto 0) <= ("00"     & PRBS(7 downto 0)); -- QAM256
            when others => tx_bit_stuf_tdata(9 downto 0) <= ("0"      & PRBS(8 downto 0)); -- QAM512
         end case;
         
         -- Output data registering
         tx_bit_ou_Rg(9 downto 0) <= tx_bit_ou(9 downto 0);
         
      end if;   
      end if;
      zeros_number <= ones_count;
      zeros_number_2 <= ones_count_2;
   end process;

   
end Behavioral;