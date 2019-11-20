----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 25.08.2019 11:03:18
-- Design Name: 
-- Module Name: ads1110 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ads1110 is
GENERIC (address: STD_LOGIC_VECTOR (6 DOWNTO 0):="1001000");
PORT (
        sda: inout STD_LOGIC := 'Z';
        scl: IN  STD_LOGIC;
        reset_n: IN  STD_LOGIC
      );
end ads1110;

architecture Behavioral of ads1110 is
type ram_type is array (0 to 15) of integer range 0 to 2**15;
constant a0 : ram_type := (301,2001,4001,6001,8001,10001,12001,14001,16001,18001,20001,22001,24001,26001,28001,30001);
constant a1:  ram_type :=(1,64,126,189,251,314,376,439,501,564,626,689,751,814,876,939);
constant a2:  ram_type :=(1,1876,3751,5626,7501,9376,11251,13126,15001,16876,18751,20626,22501,24376,26251,28126);

SIGNAL conv_reg, config_reg: STD_LOGIC_VECTOR(15 DOWNTO 0);
signal sda_in_vector: std_logic_vector (7 downto 0):=(OTHERS=>'0');
SIGNAL current_reg: STD_LOGIC_VECTOR(15 DOWNTO 0):=(OTHERS=>'0');

--signal sda_data_in : std_logic;
--signal sda_ena : std_logic;
signal sda_in, sda_out : std_logic;

constant P1:STD_LOGIC_VECTOR(7 DOWNTO 0):="00000001";
constant P0:STD_LOGIC_VECTOR(7 DOWNTO 0):="00000000";

signal cont_tmp : integer range 0 to 7;

type t_state is (verif_addr, return_verif, ack, wr_mode,wr_mode_ack,wr_config_reg_1,wr_config_reg_ack_1,wr_config_reg_2,wr_config_reg_ack_2, rd_mode_1,rd_mode_ack_1,rd_mode_2);
signal state, next_state : t_state := verif_addr;

TYPE T_STATE_REG IS (IDLE,update_conv_reg, REG_CONV, REG_CONF);
SIGNAL STATE_REG : T_STATE_REG := IDLE;

begin
process (next_state)
begin
	state <= next_state;
end process;

PROCESS (STATE_REG)
variable cont_a0: integer range 0 to 15 := 0;
variable cont_a1: integer range 0 to 15 := 0;
variable cont_a2: integer range 0 to 15 := 0;
begin
	case STATE_REG IS
			WHEN IDLE =>
				current_reg <= current_reg;
				
			WHEN update_conv_reg =>
				if config_reg(14 downto 12)="100" then
					conv_reg <= std_LOGIC_VECTOR(to_unsigned(a0(cont_a0), conv_reg'length));
					cont_a0 := cont_a0+1;
				elsif config_reg(14 downto 12)="101" then
					conv_reg <= std_LOGIC_VECTOR(to_unsigned(a1(cont_a1), conv_reg'length));
					cont_a1 := cont_a1+1;
				elsif config_reg(14 downto 12)="110" then
					conv_reg <= std_LOGIC_VECTOR(to_unsigned(a2(cont_a2), conv_reg'length));
					cont_a2 := cont_a2+1;
				end if;
			
			WHEN reg_conv =>
				current_reg <= conv_reg;
				
			when reg_conf =>
				current_reg <= config_reg;
				
			end case;
end process;

process(scl)
begin
    if (scl'event and scl='0') then
        if (sda_out = '0') then
            sda <= '0';
        else
            sda <= 'Z';
        end if;
    end if;
end process;

sda_in <= '0' when sda = '0' else '1';

PROCESS(scl)
	variable cont : integer range 0 to 7:= 7;
	variable cont15: integer range 0 to 15:=15; 
	BEGIN
	cont_tmp <= cont;
	   if (reset_n='0')then
		    sda_in_vector<=(others=>'0');
		    sda_out <= '1';
		elsif(scl'event and scl='Z')then
			case state is
			    when verif_addr => 
                    sda_in_vector(cont) <= sda_in;
                    if (cont = 0) then
                        sda_out <= '0';
                        next_state <= ack;
                        cont := 7;
                    else
                        cont := cont - 1;
                    end if;
                    
                    state_reg <= idle;
    --------------------------------------Estado ack (confirmaci�n de la direcci�n)
                when ack => 
                    if sda_in_vector(7 downto 1) = address then 
                        if (sda_in_vector(0)='0')THEN
                            next_state<=wr_mode;
                            sda_out <= '1';
                        else
                            next_state<=rd_mode_1;
                            sda_out <= current_reg(cont15);
                            cont15 := cont15 - 1;
                        end if;
                    else
                        next_state <= verif_addr;
                        sda_out <= '1';
                    end if;
    -------------------------------------Estado wr_mode                    
                when wr_mode=>
                    sda_in_vector(cont) <= sda_in;
                    if cont = 0 then    
                        next_state <= wr_mode_ack;
                        sda_out <= '0';
                        cont := 7;
                    else            
                        next_state <= wr_mode; 
                        cont := cont-1;
                    end if;
                    
    ----------------------------------- Estado wr_mode_ack
                when wr_mode_ack =>
                    if sda_in_vector = P1 THEN 
                        sda_out <= '1';
                        next_state <= wr_config_reg_1;
                    elsif sda_in_vector = P0 THEN
                        sda_out<='1';
                        next_state <= return_verif;
                        state_reg <= reg_CONV;
                    else
                       next_state <= return_verif;
                       sda_out <= '1';
                    end if;
                    
    ----------------------------------- Estado wr_config_reg_1
                when wr_config_reg_1 =>
                    sda_in_vector(cont) <= sda_in;
                    
                    if cont = 0 then    
                        next_state <= wr_config_reg_ack_1;
                        sda_out <= '0';
                        cont := 7;
                    else            
                        next_state <= wr_config_reg_1; 
                        cont:=cont-1;
                
                    end if;
                
    ----------------------------------- Estado wr_config_reg_ack_1
                when wr_config_reg_ack_1 =>
                    config_reg(15 downto 8) <= sda_in_vector;
                    sda_out <= '1';
                    next_state <= wr_config_reg_2;
                    
--                    sda_in_vector(cont) <= sda_in;
--                    cont := cont-1;
    
    ----------------------------------- Estado wr_config_reg_2            
                    
                when wr_config_reg_2 => 
                    sda_in_vector(cont) <= sda_in;
                    
                    if cont = 0 then    
                        next_state <= wr_config_reg_ack_2;
                        sda_out <= '0';
                        cont := 7;
                    else            
                        next_state <= wr_config_reg_2; 
                        cont:=cont-1;
                    end if;
    
    ----------------------------------- Estado wr_config_reg_ack_2
                when wr_config_reg_ack_2 =>
                    config_reg(7 downto 0) <= sda_in_vector;
                    sda_out <= '1';
                    next_state <= return_verif;
                    state_reg <= update_conv_reg;
                                
                when return_verif =>
                    next_state <= verif_addr;
                    
    ----------------------------------------estado rd_mode_1
                when rd_mode_1=>
                
                    if cont15 = 8 THEN
                        sda_out <= '1';
                        next_state<=rd_mode_ack_1;
                    else
                        sda_out <= current_reg(cont15);
                        cont15:= cont15-1;
                    end if;
    ------------------------------------------- estado rd_mode_ack_1
                when rd_mode_ack_1 =>
                    if (sda = '0') then    
                        next_state<=rd_mode_2;
                        sda_out <= current_reg(cont15);
                        cont15:= cont15-1;
                    else 
                        sda_out <= current_reg(cont15);
                        cont15:= cont15-1;
                        next_state <= rd_mode_2;
                  --      sda_out <= '1';
                    end if;        
    ------------------------------------------estado rd_mode_2
                when rd_mode_2=>
                    if cont15 =0 THEN
                        sda_out <= '1';
                        next_state<=verif_addr;
                    else
                        sda_out <= current_reg(cont15);
                        cont15:= cont15-1;
                    end if;
                
    -----------------------------------------
                when others =>
                    next_state<=verif_addr;
            end case;
		end if;
    
    -- Define tri_state
--        if sda_ena = '0' then
--            sda_in <= sda;
--        else 
--            sda_in<='Z';
--        end if;
END PROCESS;
end Behavioral;

