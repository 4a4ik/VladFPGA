library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity symbol_stuffer is
    Port ( ckMain : in STD_LOGIC;
           arst_n: in STD_LOGIC;   -- asynchronous reset
    
           modulation_mode:  in STD_LOGIC_VECTOR(2 downto 0);     -- modulation mode, QAM16="000", QAM32="001", QAM64="010", QAM128="011", QAM256="100", QAM512="101"
           send_data:        in std_logic;    
           
           rx_bit_stuf_send: out std_logic;                       -- send data pulse, according to current bandwidth
           rx_bit_stuf_tvalid: in STD_LOGIC;                      -- tvalid from framer
           rx_bit_stuf_tdata:  in STD_LOGIC_VECTOR(9 downto 0);   -- data from framer
           
           tx_bit_stuf_tvalid: out STD_LOGIC;                     -- tvalid from framer
           tx_bit_stuf_tdata:  out STD_LOGIC_VECTOR(9 downto 0)   -- data from framer
     );
end symbol_stuffer;

architecture Behavioral of symbol_stuffer is

constant QAM16:   STD_LOGIC_VECTOR(2 downto 0) := "000";
constant QAM32:   STD_LOGIC_VECTOR(2 downto 0) := "001";
constant QAM64:   STD_LOGIC_VECTOR(2 downto 0) := "010";
constant QAM128:  STD_LOGIC_VECTOR(2 downto 0) := "011";
constant QAM256:  STD_LOGIC_VECTOR(2 downto 0) := "100";
constant QAM512:  STD_LOGIC_VECTOR(2 downto 0) := "101";

constant SOF0_QAM16: std_logic_vector(rx_bit_stuf_tdata'range) := "0000001111";
constant SOF1_QAM16: std_logic_vector(rx_bit_stuf_tdata'range) := "0000001111";

signal Reg1: std_logic_vector(rx_bit_stuf_tdata'range) := (others => '0');
signal Reg2: std_logic_vector(rx_bit_stuf_tdata'range) := (others => '0');
signal Reg3: std_logic_vector(rx_bit_stuf_tdata'range) := (others => '0');

signal out_data_reg: std_logic_vector(tx_bit_stuf_tdata'range) := (others => '0');

signal modulation_mode_Lt: std_logic_vector(modulation_mode'range) := (others => '0');

signal SOF0: std_logic_vector(rx_bit_stuf_tdata'range) := (others => '0');
signal SOF1: std_logic_vector(rx_bit_stuf_tdata'range) := (others => '0');

signal tready_sig: std_logic := '1';
signal send_data_Lt: std_logic := '0';
signal send_data_Lt2: std_logic := '0';


signal rx_bit_stuf_send_sig: std_logic := '0';



signal input_data_Lt: std_logic_vector(rx_bit_stuf_tdata'range) := (others => '0');

signal state: integer range 0 to 50 := 0;


begin

rx_send_gen: process(ckMain, arst_n)
begin
if arst_n = '0' then
   rx_bit_stuf_send_sig <= '0';

elsif rising_edge(ckMain) then

   if    tready_sig = '1' and rx_bit_stuf_send_sig = '0' then
      rx_bit_stuf_send_sig <= '1';
   elsif tready_sig = '1' and rx_bit_stuf_send_sig = '1' then
      rx_bit_stuf_send_sig <= '0';
   else
      rx_bit_stuf_send_sig <= '0';
   end if;

end if;
end process;

process(ckMain, arst_n)
begin
if arst_n = '0' then

   Reg1 <= (others => '0');
   Reg2 <= (others => '0');
   Reg3 <= (others => '0');
   input_data_Lt <= (others => '0');
   out_data_reg <= (others => '0');
   modulation_mode_Lt <= (others => '0');
   tready_sig <= '1';
   send_data_Lt <= '0';
   send_data_Lt2 <= '0';


elsif rising_edge(ckMain) then

   input_data_Lt <= rx_bit_stuf_tdata;
   send_data_Lt <= send_data;
   send_data_Lt2 <= send_data_Lt;
   modulation_mode_Lt <= modulation_mode;
   
   case modulation_mode_Lt is
   when QAM16 => SOF0 <= SOF0_QAM16;
                 SOF1 <= SOF1_QAM16;
   when others =>
   end case;
                  
   case state is
   when 0 => 
      out_data_reg <= (others => '0'); -- send something between frames
      if rx_bit_stuf_tvalid = '1' and rx_bit_stuf_tdata(rx_bit_stuf_tdata'high) = '0' then  -- Data
         state <= 1;
      end if;
   when 1 =>
      Reg3 <= input_data_Lt;
         tready_sig <= '0';
         state <= 2;
   when 2 =>
      Reg2 <= Reg3;
      if rx_bit_stuf_tvalid = '1' and rx_bit_stuf_tdata(rx_bit_stuf_tdata'high) = '1' then  -- Frame Delimeter
         state <= 3;
      elsif rx_bit_stuf_tvalid = '1' and rx_bit_stuf_tdata(rx_bit_stuf_tdata'high) = '0' then  -- Data
         state <= 20;
      end if;
   when 3 =>
      Reg1 <= Reg2;
         state <= 4;
   when 4 =>
      if rx_bit_stuf_tdata(rx_bit_stuf_tdata'high) = '1' then  -- Frame Delimeter
         state <= 5;
      elsif rx_bit_stuf_tdata(rx_bit_stuf_tdata'high) = '0' then  -- Data
         state <= 11;
      end if;
   when 5 =>
      if send_data_Lt = '1' then  -- modem asks for data
         state <= 6;
      end if;
   when 6 =>
      out_data_reg <= SOF0;
      if send_data_Lt = '1' then  -- modem asks for data
         state <= 7;
      end if;
   when 7 =>
      out_data_reg <= SOF1;
      if send_data_Lt = '1' then  -- modem asks for data
         state <= 8;
      end if;
   when 8 =>
      out_data_reg <= Reg1;
      if send_data_Lt = '1' then  -- modem asks for data
         state <= 9;
      end if;
   when 9 =>
      out_data_reg <= SOF0;
      if send_data_Lt = '1' then  -- modem asks for data
         state <= 10;
      end if;
   when 10 =>
      out_data_reg <= SOF1;
         state <= 18;
   when 11 =>
      Reg3 <= input_data_Lt;
         state <= 12;
   when 12 =>
      Reg3 <= input_data_Lt;
      if send_data_Lt = '1' then  -- modem asks for data
         state <= 13;
      end if;
   when 13 =>
      out_data_reg <= SOF0;
      if send_data_Lt = '1' then  -- modem asks for data
         state <= 14;
      end if;
   when 14 =>
      out_data_reg <= SOF1;
      if send_data_Lt = '1' then  -- modem asks for data
         state <= 15;
      end if;
   when 15 =>
      out_data_reg <= Reg1;
      if send_data_Lt = '1' then  -- modem asks for data
         state <= 16;
      end if;
   when 16 =>
      out_data_reg <= SOF0;
      if send_data_Lt = '1' then  -- modem asks for data
         state <= 17;
      end if;
   when 17 =>
      out_data_reg <= SOF1;
      if send_data_Lt = '1' then  -- modem asks for data
         state <= 18;
      end if;
   when 18 =>
      tready_sig <= '1';  -- stuffer is ready for new data
         state <= 0;
   when others =>
   end case;

end if;

end process;

tx_bit_stuf_tdata <= out_data_reg;
tx_bit_stuf_tvalid <= send_data_Lt2;
rx_bit_stuf_send <= rx_bit_stuf_send_sig and tready_sig;

end Behavioral;
