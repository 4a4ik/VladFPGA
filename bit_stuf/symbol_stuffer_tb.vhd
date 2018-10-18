library ieee; 
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all; 
use ieee.std_logic_arith.all;
use ieee.math_real.all;

-- Test bench for symbol stuffer

-- To do, take tx_bit_stuf_send, delay by 3 cycles, use as CE and send as ex_bit_stuf_tvalid

entity bit_stuf_tb is
end    bit_stuf_tb;

architecture Behavioral of bit_stuf_tb is

   constant Cs_Ck_Period : time:= 4 ns; -- Main clock period

   -- Start of file, end of file constants
   signal SOF1 : std_logic_vector(9 downto 0) := "0000000111";
   signal SOF2 : std_logic_vector(9 downto 0) := "0000000111";
   signal Data_const_1 : std_logic_vector(9 downto 0) := "0000000111";
   signal Data_const_2 : std_logic_vector(9 downto 0) := "0000001110";
   
   -- Clock signals
   signal ckCs : std_logic := '1'; -- Main System Clock
   signal ckCe : std_logic := '1'; -- Main System Clock Enable
   signal Data_pulse : std_logic := '0'; -- Pulse
   
   -- LFSR
   signal lfsr_ou : std_logic_vector(9 downto 0) := (others=>'1'); -- Length 49 LFSR (49) (40)
   signal lfsr_ou_check : std_logic_vector(9 downto 0) := (others=>'1'); -- Length 49 LFSR (49) (40)
   
   -- Control signals
   signal modulation_mode : std_logic_vector(2 downto 0) := "000"; -- Modulation mode, QAM16="000", QAM32="001", QAM64="010", QAM128="011", QAM256="100", QAM512="101"
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
   signal data_error: std_logic_vector(0 downto 0):="0";
   
   -- TB data
   signal tb_current_data : std_logic_vector(9 downto 0):=(others=>'0'); -- Saving current data value
   signal current_data : std_logic_vector(9 downto 0):=(others=>'0');   -- Saving current data value -- old one, remove!!
   -- 
   signal tb_tvalid : std_logic_vector(0 downto 0):="0"; -- Output data generation enable
   
      -- Output data
   signal tb_data_ou : std_logic_vector(9 downto 0):=(others=>'0');     -- Output data, generated by tb
   signal tb_data_ou_Rg1 : std_logic_vector(9 downto 0):=(others=>'0'); -- Output data, generated by tb
   signal tb_data_ou_Rg2 : std_logic_vector(9 downto 0):=(others=>'0'); -- Output data, generated by tb
   signal tb_data_ou_Rg3 : std_logic_vector(9 downto 0):=(others=>'0'); -- Output data, generated by tb
   
   -- Input data
   signal tx_bit_in : std_logic_vector(9 downto 0) := (others=>'0'); -- Input data
   signal tx_bit_in_Rg1 : std_logic_vector(9 downto 0) := (others=>'0'); -- Registered input data
   signal tx_bit_in_Rg2 : std_logic_vector(9 downto 0) := (others=>'0'); -- Registered input data
   signal tx_bit_in_Rg3 : std_logic_vector(9 downto 0) := (others=>'0'); -- Registered input data
   signal tx_bit_in_Conc : std_logic_vector(19 downto 0) := (others=>'0'); -- Storing previous & current values
   signal tx_bit_in_Conc_Rg1 : std_logic_vector(19 downto 0) := (others=>'0'); -- Storing previous & current values
   signal tx_bit_in_Conc_Rg2 : std_logic_vector(19 downto 0) := (others=>'0'); -- Storing previous & current values
   
   -- Output data
   signal tx_bit_ou : std_logic_vector(9 downto 0) := (9 => '1', others=>'0'); -- Output data
   signal tx_bit_stuf_tdata : std_logic_vector(9 downto 0) := (others=>'0');
   signal tx_bit_stuf_send : std_logic := '1';
   -- Test1
   signal tx_tb_data : std_logic_vector(9 downto 0) := ("1" & ext("0", 9));
   
   -- UUT
   signal rx_bit_stuf_tdata : std_logic_vector(9 downto 0) := (others=>'0'); -- Output data
   signal arst_n : std_logic := '1';
   signal rx_bit_stuf_tvalid : std_logic := '1';
   signal rx_bit_stuf_send : std_logic := '0';
   signal rx_bit_stuf_send_Rg1 : std_logic := '0';
   signal rx_bit_stuf_send_Rg2 : std_logic := '0';
   signal rx_bit_stuf_send_Rg3 : std_logic := '0';

   signal rx_send_delayed : std_logic_vector(2 downto 0) := (others=>'0'); -- delayed ex_bit_stuf_tvalid, 3 cycles
   signal tx_bit_stuf_tvalid : std_logic := '1';
   
   signal tb_out: std_logic_vector(9 downto 0):=(others=>'0');
   ----------- State Machine Hardware ------------
   type FSMstates is (wait_st, sof_st, transf_st, stuff_st); -- FSM
   signal StVar : FSMstates := wait_st;
   
begin

   --tx_bit_stuf_send <= Data_pulse;
   -- Clock generation
   ckCs <= not ckCs after Cs_Ck_Period/2;
   
      -- Main system clock signal generation
   Ps_Ck_process : process  
   begin
      Data_pulse <= '1';
      wait for (Cs_Ck_Period);
      Data_pulse <= '0';
      wait for (1)*(Cs_Ck_Period); -- Duty cycle, 3 for 1/4, 5 for 1/6 
   end process;
   
      -- Main process, input analysis
   process(ckCs)
   begin
      if rising_edge(ckCs) then
      if tx_bit_stuf_tvalid = '1' then
         rx_send_delayed(2 downto 0) <= rx_send_delayed(1 downto 0) & rx_bit_stuf_send; -- Used for delaying rx_send_delayed by 3 clock cycles
     -- if tx_send_delayed(2 downto 2) = "1" then

      
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
               elsif tx_bit_in(9 downto 0) = SOF1(9 downto 0) then
                  SOF_error(0 downto 0) <= SOF_error(0 downto 0);               
                  StVar <= sof_st;
               else
                  SOF_error(0 downto 0) <= "1";
                  StVar <= StVar;
               end if;
               
            when sof_st => -- Start of frame state
               
               if tx_bit_in_conc(19 downto 0) = (SOF1(9 downto 0) & SOF2(9 downto 0)) then
                  StVar <= transf_st;
               else
                  StVar <= StVar;
               end if;
               
            when transf_st => -- Data transfer state
               
               if tx_bit_in_conc(19 downto 0) = (SOF1(9 downto 0) & SOF2(9 downto 0)) then
                  StVar <= wait_st;
               else
                  StVar <= StVar;
               end if;
               
               -- <1000......><Data><1000......> - Compares data
               -- <SOF1><SOF2><Data><SOF1><SOF2>
               if tx_bit_stuf_tvalid = '1' then -- Data are being sent
                  lfsr_ou_check(9 downto 0) <= lfsr_ou_check(8 downto 0) & (lfsr_ou_check(9 downto 9) xor lfsr_ou_check(6 downto 6)); -- Symbol generation for input analysis
                  if (tx_bit_in_Rg2(9 downto 0) & tx_bit_in_Rg1(9 downto 0)) = (SOF1 & SOF2) then -- Checking if data is right
                    -- if tx_bit_in(9 downto 0) =  lfsr_ou_check(9 downto 0) then
                     if tx_bit_in(9 downto 0) =  "0000000011" then
                    -- if tx_bit_in(9 downto 0) =  tb_current_data(9 downto 0) then
                    -- if tx_bit_in(9 downto 0) =  tb_data_ou_Rg3(9 downto 0) then
                        data_error(0 downto 0) <= "0";
                     else
                        data_error(0 downto 0) <= "1";
                     end if;
                  else
                     data_error(0 downto 0) <= data_error(0 downto 0);
                  end if;
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
     
      current_data(9 downto 0) <= tx_bit_in(9 downto 0);
      
      -- Input data registering
      tx_bit_in_Rg1(9 downto 0) <= tx_bit_in(9 downto 0);
      tx_bit_in_Rg2(9 downto 0) <= tx_bit_in_Rg1(9 downto 0);
      tx_bit_in_Rg3(9 downto 0) <= tx_bit_in_Rg2(9 downto 0);
      
      transf_flag_Rg1(0 downto 0) <= transf_flag(0 downto 0);
      transf_flag_Rg2(0 downto 0) <= transf_flag_Rg1(0 downto 0);
     
      tx_bit_in_Conc(19 downto 0) <= tx_bit_in_Rg1(9 downto 0) &  tx_bit_in(9 downto 0); -- SOF&EOF combination
      tx_bit_in_Conc_Rg1(19 downto 0) <= tx_bit_in_Conc(19 downto 0);
      tx_bit_in_Conc_Rg2(19 downto 0) <= tx_bit_in_Conc_Rg1(19 downto 0);
      rx_bit_stuf_send_Rg1 <= rx_bit_stuf_send;
      rx_bit_stuf_send_Rg2 <= rx_bit_stuf_send_Rg1;
      rx_bit_stuf_send_Rg3 <= rx_bit_stuf_send_Rg2;
      
      end if;   
      end if;

   end process;
   
   --------------------------------------- Output data generation ------------------------------------------------
   process(ckCs) begin
      if rising_edge(ckCs) then
    --  if ckCe = '1' then
         if rx_send_delayed(2 downto 2) = "1" then
         if Data_pulse = '0' then
            lfsr_ou(9 downto 0) <= lfsr_ou(8 downto 0) & (lfsr_ou(9 downto 9) xor lfsr_ou(6 downto 6)); -- Output symbol generation
         --   tb_current_data(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0);
            
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
            case mode_ou(0 downto 0) is -- change to tb_tvalid(0 downto 0)!!
               when "0"    => tx_bit_ou(9 downto 0) <= ("1" & ext("0", 9)); -- 0s
               when others => tx_bit_ou(9 downto 0) <= tx_bit_stuf_tdata(9 downto 0); -- PRBS
            end case;
         
         -- Output data registering
         tb_data_ou(9 downto 0) <= tx_bit_ou(9 downto 0);
         tb_data_ou_Rg1(9 downto 0) <= tb_data_ou(9 downto 0);
         tb_data_ou_Rg2(9 downto 0) <= tb_data_ou_Rg1(9 downto 0);
         tb_data_ou_Rg3(9 downto 0) <= tb_data_ou_Rg2(9 downto 0);
         
         tx_tb_data(9 downto 0) <= tx_bit_ou(9 downto 0); -- Test 1 output signal
      
      end if;
      end if;
      end if;
   end process;
   ---------------------------------------------------------------------------------------------------------------  
  
   DataOutput_process: process 
   begin

      wait for 10*(Cs_Ck_Period);
      
      -- Test 1
      rx_bit_stuf_send <= '1';
      wait until rx_bit_stuf_send_Rg3 = '1';
      tb_out <= "1000000000";
      wait for (Cs_Ck_Period);
      tb_out <= "0000000011";
      wait for (Cs_Ck_Period);
      tb_out <= "1000000000";     
      wait for 12*(Cs_Ck_Period);
      
      -- -- Test 2
      -- tb_out <= "0000000011";     
      -- wait for (Cs_Ck_Period);
      -- tb_out <= "0000001100";
      -- wait for (Cs_Ck_Period);
      -- tb_out <= "1000000000"; 
      -- wait for 12*(Cs_Ck_Period); 
      
      -- -- Test 3
      -- tb_out <= "0000000011";     
      -- wait for (Cs_Ck_Period);
      -- tb_out <= "0000001100";
      -- wait for (Cs_Ck_Period);
      -- tb_out <= "0000110000";
      -- wait for (Cs_Ck_Period);
      -- tb_out <= "1000000000";        
      -- wait for 12*(Cs_Ck_Period);  
      
   end process;
   
   -- DataOutput_process: process 
   -- begin
     

      
   -- end process;
   

   -- symbol_stuffer_wrk: entity work.symbol_stuffer   
   -- port map (
             -- -- Rx
             -- ckMain => ckCs,
             -- arst_n => arst_n,                                   -- asynchronous reset
             -- modulation_mode => modulation_mode,                 -- modulation mode, QAM16="000", QAM32="001", QAM64="010", QAM128="011", QAM256="100", QAM512="101"
             -- send_data => Data_pulse,    
             
             -- rx_bit_stuf_send => rx_bit_stuf_send,               -- => send data pulse, according to current bandwidth
             -- rx_bit_stuf_tvalid  => tx_send_delayed(2),          -- tvalid from framer
             -- rx_bit_stuf_tdata => tb_out,                     -- data from framer    
            -- -- rx_bit_stuf_tdata => tx_bit_ou,                     -- data from framer    
             -- -- Tx
             -- tx_bit_stuf_tvalid => tx_bit_stuf_tvalid,           -- tvalid to modem
             -- tx_bit_stuf_tdata =>  tx_bit_in(9 downto 0));       -- data to modem

 
end Behavioral;