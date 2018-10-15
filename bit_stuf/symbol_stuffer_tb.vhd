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
   
   -- Input data
   signal tx_bit_in : std_logic_vector(9 downto 0) := (others=>'0'); -- Input data
   signal tx_bit_in_Rg1 : std_logic_vector(9 downto 0) := (others=>'0'); -- Registered input data
   signal tx_bit_in_Rg2 : std_logic_vector(9 downto 0) := (others=>'0'); -- Registered input data
   signal tx_bit_in_Rg3 : std_logic_vector(9 downto 0) := (others=>'0'); -- Registered input data
   signal tx_bit_in_Conc : std_logic_vector(19 downto 0) := (others=>'0'); -- Storing previous & current values
   signal tx_bit_in_Conc_Rg1 : std_logic_vector(19 downto 0) := (others=>'0'); -- Storing previous & current values
   signal tx_bit_in_Conc_Rg2 : std_logic_vector(19 downto 0) := (others=>'0'); -- Storing previous & current values
   
   ----------- State Machine Hardware ------------
   type FSMstates is (wait_st, sof_st, transf_st, stuff_st); -- FSM
   signal StVar : FSMstates := wait_st;
   
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
      wait for (5)*(Cs_Ck_Period/2); -- Duty cycle, 3 for 1/4, 5 for 1/6 
   end process;
   
      -- Main process
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
            
               if tx_bit_in(9 downto 0) = SOF_const(9 downto 0) then 
                  StVar <= sof_st;
               else
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
   
   DataInput_process: process 
   begin
   
      wait for (Cs_Ck_Period*10);
      
      tx_bit_in(9 downto 0) <= (others=>'0');
      wait for (Cs_Ck_Period*10);
      
      -- SOF
      tx_bit_in(9 downto 0) <= SOF_const(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= EOF_const(9 downto 0);
      wait for Cs_Ck_Period;
      
      -- Random data
      tx_bit_in(9 downto 0) <= "0000111000";
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= "0010110010";
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= "0001100100";
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= "1111001000";
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
      tx_bit_in(9 downto 0) <= "0000111000";
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= "0010110010";
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= "0001100100";
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= "1111001000";
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
      tx_bit_in(9 downto 0) <= "0000111000";
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= "0010110010";
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= "0001100100";
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= "1111001000";
      wait for Cs_Ck_Period;

      -- Incoming constants, not duplicated, error should be 1
      tx_bit_in(9 downto 0) <= Data_const_1(9 downto 0);
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= Data_const_2(9 downto 0);
      wait for Cs_Ck_Period;

      -- Random data
      tx_bit_in(9 downto 0) <= "0000111000";
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= "0010110010";
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= "0001100100";
      wait for Cs_Ck_Period;
      tx_bit_in(9 downto 0) <= "1111001000";
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
end Behavioral;