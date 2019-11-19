LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

entity tb_i2c is
generic(	clk_freq : integer := 100_000_000;
			i2c_clk  : integer :=     500_000);
end entity;

architecture arch of tb_i2c is
------------------------------------------
COMPONENT final
PORT (
     clk       : IN     STD_LOGIC;                    --system clock
     reset_n   : IN     STD_LOGIC;                    --active low reset
	 start     : IN     STD_LOGIC;                   --señal para comenzar el proceso
	 ch        : IN     STD_LOGIC_VECTOR(2 DOWNTO 0); --canal de transmisión a utilizar datasheet
	 pga       : IN     STD_LOGIC_VECTOR(2 DOWNTO 0); -- configuración de los valores de pga (programing gain amplifier)datasheet
     dr        : IN     STD_LOGIC_VECTOR(2 DOWNTO 0); -- entrada del valor de muestras por segundo datasheet
	 addr_i2c  : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --entrada de la dirección del modulo ads    
	 os        : IN     STD_LOGIC;                    --valor del operational status datasheet
	 mode      : IN     STD_LOGIC;                    --valor del modo de operación datasheet
	 comp_mode : IN     STD_LOGIC;						  --valor del modo de comparador datasheet
	 comp_pol  : IN 	  STD_LOGIC;                    --polarity comparador datasheet
	 comp_lat  : IN     STD_LOGIC;                    --comparador latching datasheet
	 comp_que  : IN     STD_LOGIC_VECTOR(1 DOWNTO 0);  -- comparador que datasheet
	 en_i2c_in : IN     STD_LOGIC;
	 a00	   : OUT 	  STD_LOGIC_VECTOR(15 DOWNTO 0);
	 a11	   : OUT 	  STD_LOGIC_VECTOR(15 DOWNTO 0);
	 a22	   : OUT 	  STD_LOGIC_VECTOR(15 DOWNTO 0);
	 a33	   : OUT 	  STD_LOGIC_VECTOR(15 DOWNTO 0);
	 sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
     scl       : INOUT  STD_LOGIC;                   --serial clock output of i2c bus
	 ready     : OUT    STD_LOGIC;
	 ack_error : BUFFER STD_LOGIC 
		);
END COMPONENT;
------------------------------------------

signal clk       : STD_LOGIC;                    --system clock
signal reset_n   : STD_LOGIC;                    --active low reset
signal start     : STD_LOGIC;                    --latch in command
signal ch        : STD_LOGIC_VECTOR(2 DOWNTO 0); --address of target slave
signal pga       : STD_LOGIC_VECTOR(2 DOWNTO 0);                    --'0' is write, '1' is read
signal dr        : STD_LOGIC_VECTOR(2 DOWNTO 0);
signal addr_i2c  : STD_LOGIC_VECTOR(6 DOWNTO 0);
signal os        : STD_LOGIC;                    --indicates transaction in progress
signal mode      : STD_LOGIC;  
signal comp_mode : STD_LOGIC;  
signal comp_pol  : STD_LOGIC; 
signal aa1       : STD_LOGIC;
signal aa2       : STD_LOGIC;
signal comp_lat  : STD_LOGIC; 
signal comp_que  : STD_LOGIC_VECTOR(1 DOWNTO 0); --data read from slave
signal ack_error : STD_LOGIC;                    --flag if improper acknowledge from slave
signal sda       : STD_LOGIC;                    --serial data output of i2c bus
signal scl       : STD_LOGIC;                   --serial clock output of i2c bus
signal a0  		  : STD_LOGIC_VECTOR(15 DOWNTO 0);
signal a1 		  : STD_LOGIC_VECTOR(15 DOWNTO 0);
signal a2  		  : STD_LOGIC_VECTOR(15 DOWNTO 0);
signal a3 		  : STD_LOGIC_VECTOR(15 DOWNTO 0);
SIGNAL ready      : STD_LOGIC;
SIGNAL en_i2c_in  : STD_LOGIC;
-----------------------------------------------------
constant PERIOD     : time :=	1 ns;
constant DUTY_CYCLE : real := 0.5;
constant OFFSET     : time := 10 ns;
----------------------------------------------------
begin
-----------------------
dut: final
PORT MAP
	(
	 clk    =>clk,
    reset_n   =>reset_n,
	 start     =>start,
	 ch        =>ch,
	 pga       =>pga,
    dr        =>dr,
	 addr_i2c  =>addr_i2c,   
	 os        =>os,
	 mode      =>mode,
	 comp_mode =>comp_mode,
	 comp_pol  =>comp_pol,
	 comp_lat  =>comp_lat,
	 comp_que  =>comp_que,
	 en_i2c_in=>en_i2c_in,
	 a00		  =>a0,
	 a11		  =>a1,
	 a22		  =>a2,
	 a33		  =>a3,
	 sda       =>sda,
    scl       =>scl,
	 ready     =>ready,
	 ack_error =>ack_error 	
	);
-----------------------------------------------------
clk_proc: PROCESS    -- clk process for clk
  BEGIN
    WAIT for OFFSET;
        clk_LOOP : LOOP
        clk <= '0';
        WAIT FOR (PERIOD/2);
        clk <= '1';
        WAIT FOR (PERIOD/2);
     END LOOP clk_LOOP;
END PROCESS;
------------------------------------------------------
reset_n<='0','1' AFTER 80ns;
------------------------------------------------------
start<='0','1' AFTER 20ns,
            '0' AFTER 1370ns,
            '1' AFTER 11.9us,
            '0' AFTER 12.3us;
------------------------------------------------------ 
ch<="000", "001" AFTER 11.5us; 
-----------------------------------------------
pga<="010";
-----------------------------------------
dr<="111";
----------
aa1<='0';
------------
aa2<='0';
-------------------------------------------------
addr_i2c<="10010"&aa1&aa2;
---------------------------------------------
os<='1';
----------------------------------------
mode<='1';
----------------------------------------
comp_mode<='0';
--------------------------
comp_pol<='0';
-------------------------------
comp_lat<='0';
-------------------------------
comp_que<="11";
-------------------------------
en_i2c_in<='0','1' AFTER 1000ns,              
               '0' AFTER 11us,
               '1' AFTER 12us,
               '0' AFTER 22us;
-----------------------------------
end arch;