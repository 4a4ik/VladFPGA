library ieee; 
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all; 
use ieee.std_logic_arith.all;
use ieee.math_real.all;

-- Test bench for bit stuffer

entity bit_stuf_tb is
end    bit_stuf_tb;

architecture Behavioral of bit_stuf_tb is

   constant Cs_Ck_Period : time:= 4 ns; -- Main clock period
   
   -- Start of file, end of file constants
   signal SOF_const : std_logic_vector(9 downto 0) := "0000000001";
   signal EOF_const : std_logic_vector(9 downto 0) := "0000001111";
   signal Data_const_1 : std_logic_vector(9 downto 0) := "0000000111";
   signal Data_const_2 : std_logic_vector(9 downto 0) := "0000001110";
   
   -- Clock signals
   signal ckCs : std_logic := '0'; -- Main System Clock
   signal ckCe : std_logic := '1'; -- Main System Clock Enable
   signal ckPs : std_logic := '0'; -- Pulse
   
   -- LFSR
   signal lfsr_ou : std_logic_vector(9 downto 0) := (others=>'1'); -- Length 49 LFSR (49) (40)
   
   -- Control signals
   signal modulation_mode : std_logic_vector(2 downto 0) := "111"; -- Modulation mode, QAM16="000", QAM32="001", QAM64="010", QAM128="011", QAM256="100", QAM512="101"
   signal transf_err : std_logic_vector(0 downto 0):="0";
   signal transf_flag : std_logic_vector(0 downto 0):="0";
   signal transf_flag_Rg1 : std_logic_vector(0 downto 0):="0";
   signal transf_flag_Rg2 : std_logic_vector(0 downto 0):="0";
   signal flag : std_logic_vector(0 downto 0):="0";
   signal flag1 : std_logic_vector(0 downto 0):="0";
   signal flag_cnt : std_logic_vector(0 downto 0):="0";
   signal error_ou : std_logic_vector(0 downto 0):="0"; -- Error output
   signal SOF_error : std_logic_vector(0 downto 0):="0"; -- Error at SOF
   signal mode_ou : std_logic_vector(0 downto 0):="0"; -- Controls output values
   
   -- Input data
   signal tx_bit_in : std_logic_vector(9 downto 0) := (others=>'0'); -- Input data
   signal tx_bit_in_Rg1 : std_logic_vector(9 downto 0) := (others=>'0'); -- Registered input data
   signal tx_bit_in_Rg2 : std_logic_vector(9 downto 0) := (others=>'0'); -- Registered input data
   signal tx_bit_in_Rg3 : std_logic_vector(9 downto 0) := (others=>'0'); -- Registered input data
   signal tx_bit_in_Conc : std_logic_vector(19 downto 0) := (others=>'0'); -- Storing previous & current values
   signal tx_bit_in_Conc_Rg1 : std_logic_vector(19 downto 0) := (others=>'0'); -- Storing previous & current values
   signal tx_bit_in_Conc_Rg2 : std_logic_vector(19 downto 0) := (others=>'0'); -- Storing previous & current values
   
   -- Output data
   signal tx_bit_ou : std_logic_vector(9 downto 0) := (others=>'0'); -- Output data
   signal tx_bit_stuf_tdata : std_logic_vector(9 downto 0) := (others=>'0');
   
   
   ----------- State Machine Hardware ------------
   type FSMstates is (wait_st, sof_st, transf_st, stuff_st); -- FSM
   signal StVar : FSMstates := wait_st;
   
   component bit_stuf is
      Port ( ckMain : in STD_LOGIC;
           arst_n: in STD_LOGIC;   -- asynchronous reset
    
           modulation_mode:  in STD_LOGIC_VECTOR(2 downto 0);     -- modulation mode, QAM16="000", QAM32="001", QAM64="010", QAM128="011", QAM256="100", QAM512="101"
           send_data:        in std_logic;    
           
           rx_bit_stuf_send: out std_logic;                       -- send data pulse, according to current bandwidth
           rx_bit_stuf_tvalid: in STD_LOGIC;                      -- tvalid from framer
           rx_bit_stuf_tdata:  in STD_LOGIC_VECTOR(9 downto 0);   -- data from framer
           
           tx_bit_stuf_send: out std_logic;                       -- receive data pulse, according to current bandwidth
           tx_bit_stuf_tvalid: out STD_LOGIC;                     -- tvalid from framer
           tx_bit_stuf_tdata:  out STD_LOGIC_VECTOR(9 downto 0)   -- data from framer
            );
   end component;

   
begin
   
   -- Main system clock signal generation
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
      wait for (3)*(Cs_Ck_Period/2); -- Duty cycle, 3 for 1/4, 5 for 1/6 
   end process;
   
      -- Main process, input analysis
   process(ckCs)
   begin
      if rising_edge(ckCs) then
      if ckCe = '1' then
      
         case modulation_mode(2 downto 0) is 
            when "000"  => Data_const_1(9 downto 0) <= "0000000111"; -- QAM16
                           Data_const_2(9 downto 0) <= "0000001110"; -- QAM16
            when "001"  => Data_const_1(9 downto 0) <= "0000000111"; -- QAM32 
                           Data_const_2(9 downto 0) <= "0000001110"; -- QAM32
            when "010"  => Data_const_1(9 downto 0) <= "0000000111"; -- QAM64 
                           Data_const_2(9 downto 0) <= "0000001110"; -- QAM64
            when "011"  => Data_const_1(9 downto 0) <= "0000000111"; -- QAM128
                           Data_const_2(9 downto 0) <= "0000001110"; -- QAM128
            when "100"  => Data_const_1(9 downto 0) <= "0000000111"; -- QAM256
                           Data_const_2(9 downto 0) <= "0000001110"; -- QAM256
            when others => Data_const_1(9 downto 0) <= "0000000111"; -- QAM512
                           Data_const_2(9 downto 0) <= "0000001110"; -- QAM512            
         end case;
         
         --------------------------------------------- FSM ------------------------------------------------------
         case StVar is
            when wait_st => -- Waiting for SOF to arrive
            
                  if tx_bit_in(9 downto 0) = ext("0",10) then
                  SOF_error(0 downto 0) <= SOF_error(0 downto 0);
                  StVar <= StVar;
               elsif tx_bit_in(9 downto 0) = SOF_const(9 downto 0) then
                  SOF_error(0 downto 0) <= SOF_error(0 downto 0);               
                  StVar <= sof_st;
               else
                  SOF_error(0 downto 0) <= "1";
                  StVar <= StVar;
               end if;
               
            when sof_st => -- Start of frame state
               
               if tx_bit_in_conc(19 downto 0) = (SOF_const(9 downto 0) & EOF_const(9 downto 0)) then
                  StVar <= transf_st;
               else
                  StVar <= StVar;
               end if;
               
            when transf_st => -- Data transfer state
               
               if tx_bit_in_conc(19 downto 0) = (SOF_const(9 downto 0) & EOF_const(9 downto 0)) then
                  StVar <= wait_st;
               else
                  StVar <= StVar;
               end if;
               
            when others =>
            
               StVar <= wait_st;
               
         end case;
         --------------------------------------------------------------------------------------------------------

      transf_err(0 downto 0) <= flag_cnt(0 downto 0) and transf_flag_Rg2(0 downto 0);
      
      -- Checking for mean number of constants          
      if tx_bit_in_conc(19 downto 0) = (Data_const_1(9 downto 0) & Data_const_2(9 downto 0)) then -- After finding (Const1&Const2) check for next 2 symbols
         flag_cnt(0 downto 0) <= not(flag_cnt(0 downto 0));
         transf_flag(0 downto 0) <= "1"; -- Not mean at the moment
      else
         transf_flag(0 downto 0) <= "0"; -- Mean number of constants
         flag_cnt(0 downto 0) <= flag_cnt(0 downto 0);
      end if; 
      
      flag1(0 downto 0) <= transf_flag(0 downto 0) and flag_cnt(0 downto 0);
      
      if flag1(0 downto 0) = "1" then
         if tx_bit_in_Conc(19 downto 0) = tx_bit_in_Conc_Rg2(19 downto 0) then
            error_ou(0 downto 0) <= "0";
         else
            error_ou(0 downto 0) <= "1";
         end if;
      else
         error_ou(0 downto 0) <= error_ou(0 downto 0);
      end if;
  
      -- Input data registering
      tx_bit_in_Rg1(9 downto 0) <= tx_bit_in(9 downto 0);
      tx_bit_in_Rg2(9 downto 0) <= tx_bit_in_Rg1(9 downto 0);
      tx_bit_in_Rg3(9 downto 0) <= tx_bit_in_Rg2(9 downto 0);
      
      transf_flag_Rg1(0 downto 0) <= transf_flag(0 downto 0);
      transf_flag_Rg2(0 downto 0) <= transf_flag_Rg1(0 downto 0);
     
      tx_bit_in_Conc(19 downto 0) <= tx_bit_in_Rg1(9 downto 0) &  tx_bit_in(9 downto 0); -- SOF&EOF combination
      tx_bit_in_Conc_Rg1(19 downto 0) <= tx_bit_in_Conc(19 downto 0);
      tx_bit_in_Conc_Rg2(19 downto 0) <= tx_bit_in_Conc_Rg1(19 downto 0);
      
      end if;   
      end if;

   end process;
   
   --------------------------------------- Output data generation ------------------------------------------------
   process(ckCs) begin
      if rising_edge(ckCs) then
      if ckCe = '1' then
      
         lfsr_ou(9 downto 0) <= lfsr_ou(8 downto 0) & (lfsr_ou(9 downto 9) xor lfsr_ou(6 downto 6));
         
         -- Sets the number of information bits in a packet
         case modulation_mode(2 downto 0) is -- Change to any CE
            when "000"  => tx_bit_stuf_tdata(9 downto 0) <= ("000000" & lfsr_ou(3 downto 0)); -- QAM16
            when "001"  => tx_bit_stuf_tdata(9 downto 0) <= ("00000"  & lfsr_ou(4 downto 0)); -- QAM32
            when "010"  => tx_bit_stuf_tdata(9 downto 0) <= ("0000"   & lfsr_ou(5 downto 0)); -- QAM64
            when "011"  => tx_bit_stuf_tdata(9 downto 0) <= ("000"    & lfsr_ou(6 downto 0)); -- QAM128
            when "100"  => tx_bit_stuf_tdata(9 downto 0) <= ("00"     & lfsr_ou(7 downto 0)); -- QAM256
            when others => tx_bit_stuf_tdata(9 downto 0) <= ("0"      & lfsr_ou(8 downto 0)); -- QAM512
         end case;
         
         -- Output control
         case mode_ou(0 downto 0) is
            when "0"    => tx_bit_ou(9 downto 0) <= ("1" & ext("0", 9)); -- 0s
            when others => tx_bit_ou(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0); -- PRBS
         end case;
         
      end if;
      end if;
   end process;
   ---------------------------------------------------------------------------------------------------------------  
  
   DataInput_process: process 
   begin
   
      wait for (Cs_Ck_Period*10);
      
      tx_bit_in(9 downto 0) <= (others=>'0');
      tx_bit_in(9 downto 0) <= (others=>'1');
      wait for (Cs_Ck_Period*10);
      
      -- SOF
      tx_bit_in(9 downto 0) <= SOF_const(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= EOF_const(9 downto 0);
      wait for Cs_Ck_Period;
      
      -- Random data
      tx_bit_in(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0);
      wait for Cs_Ck_Period;

      -- Incoming constants
      tx_bit_in(9 downto 0) <= Data_const_1(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= Data_const_2(9 downto 0);
      wait for Cs_Ck_Period;
      -- Duplicated, error should be 0
      tx_bit_in(9 downto 0) <= Data_const_1(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= Data_const_2(9 downto 0);
      wait for Cs_Ck_Period;
      
      -- Random data
      tx_bit_in(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0);
      wait for Cs_Ck_Period;
      
      -- Incoming constants
      tx_bit_in(9 downto 0) <= Data_const_1(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= Data_const_2(9 downto 0);
      wait for Cs_Ck_Period;
      -- Duplicated, error should be 0
      tx_bit_in(9 downto 0) <= Data_const_1(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= Data_const_2(9 downto 0);
      wait for Cs_Ck_Period;
      
      -- Random data
      tx_bit_in(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0);
      wait for Cs_Ck_Period;

      -- Incoming constants, not duplicated, error should be 1
      tx_bit_in(9 downto 0) <= Data_const_1(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= Data_const_2(9 downto 0);
      wait for Cs_Ck_Period;

      -- Random data
      tx_bit_in(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0);
      wait for Cs_Ck_Period;

      -- EOF
      tx_bit_in(9 downto 0) <= SOF_const(9 downto 0);
      wait for Cs_Ck_Period; 
      tx_bit_in(9 downto 0) <= EOF_const(9 downto 0);
      wait for Cs_Ck_Period;  
      tx_bit_in(9 downto 0) <= (others=>'0');
      wait for (Cs_Ck_Period*10);
      
      wait;
      
   end process;
   
   
   DataOutput_process: process 
   begin
   
      wait for (Cs_Ck_Period*10);
      
      -- Waiting
      mode_ou <= "0";
      wait for (Cs_Ck_Period*10);
      
      -- SOF
      mode_ou <= "1";
      wait for (Cs_Ck_Period*100);
      
      -- Waiting
      mode_ou <= "0";
      wait for (Cs_Ck_Period*10);
      
      wait;
      
   end process;
   
end Behavioral;