LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE ieee.std_logic_unsigned.all;
--------------------------------
ENTITY final IS 
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
	 comp_pol  : IN 	STD_LOGIC;                    --polarity comparador datasheet
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

END ENTITY;
--------------------------------
ARCHITECTURE rtl OF final IS
---------------------------------------------------------------------------------------------------------------------
COMPONENT a_i2c
	PORT
	(
	 scl       : IN     STD_LOGIC;                   --etrada del scl del modulo i2c
     clk       : IN     STD_LOGIC;                    --system clock
     reset_n   : IN     STD_LOGIC;                    --active low reset
	 start     : IN     STD_LOGIC;                   --señal para comenzar el proceso
	 ch        : IN     STD_LOGIC_VECTOR(2 DOWNTO 0); --canal de transmisión a utilizar datasheet
	 pga       : IN     STD_LOGIC_VECTOR(2 DOWNTO 0); -- configuración de los valores de pga (programing gain amplifier)datasheet
     dr        : IN     STD_LOGIC_VECTOR(2 DOWNTO 0); -- entrada del valor de muestras por segundo datasheet
	 busy_i2c  : IN     STD_LOGIC;                    --entrada del busy del modulo i2c.
	 addr_i2c  : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --entrada de la dirección del modulo ads    
	 data_rd   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data a leer del modulo ads
	 os        : IN     STD_LOGIC;                    --valor del operational status datasheet
	 mode      : IN     STD_LOGIC;                    --valor del modo de operación datasheet
	 comp_mode : IN     STD_LOGIC;						  --valor del modo de comparador datasheet
	 comp_pol  : IN 	  STD_LOGIC;                    --polarity comparador datasheet
	 comp_lat  : IN     STD_LOGIC;                    --comparador latching datasheet
	 comp_que  : IN     STD_LOGIC_VECTOR(1 DOWNTO 0); -- comparador que datasheet
     en_i2c_in : IN     STD_LOGIC;
     en_i2c    : OUT    STD_LOGIC;                    --indicates transaction in progress
	 addr_i2c2 : OUT    STD_LOGIC_VECTOR(6 DOWNTO 0); --salida de la dirección del ads
	 rw_i2c    : OUT    STD_LOGIC;                    --'0' is write, '1' is read         
     data_rw   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data escrivir en el modulo ads
	 ready     : OUT    STD_LOGIC;                    --latch in command
	 a00		  : OUT 	  STD_LOGIC_VECTOR(15 DOWNTO 0);
	 a11		  : OUT 	  STD_LOGIC_VECTOR(15 DOWNTO 0);
	 a22		  : OUT 	  STD_LOGIC_VECTOR(15 DOWNTO 0);
	 a33		  : OUT 	  STD_LOGIC_VECTOR(15 DOWNTO 0);
    ack_error : BUFFER STD_LOGIC );           
END COMPONENT;
--------------------------------------------------------------------------------------------------
COMPONENT i2c_master
  GENERIC(
    input_clk : INTEGER := 50_000_000; --input clock speed from user logic in Hz
    bus_clk   : INTEGER := 400_000);   --speed the i2c bus (scl) will run at in Hz
  PORT(
    clk       : IN     STD_LOGIC;                    --system clock
    reset_n   : IN     STD_LOGIC;                    --active low reset
    ena       : IN     STD_LOGIC;                    --latch in command
    addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
    rw        : IN     STD_LOGIC;                    --'0' is write, '1' is read
    data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
    busy      : OUT    STD_LOGIC;                    --indicates transaction in progress
    data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
    ack_error : BUFFER STD_LOGIC;                    --flag if improper acknowledge from slave
    sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
    scl       : INOUT  STD_LOGIC);                   --serial clock output of i2c bus
END COMPONENT;
-----------------------------------------------------------------------------------------
COMPONENT ads1110
	GENERIC (ADDRESS: STD_LOGIC_VECTOR (6 DOWNTO 0):="1001000");
	PORT (
        sda: inout STD_LOGIC := 'Z';
        scl: IN  STD_LOGIC;
        reset_n: IN  STD_LOGIC
      );
END COMPONENT;
-------------------------------------------------
--SIGNAL sclm: STD_LOGIC='0';
SIGNAL busy_i2cm: STD_LOGIC:='0';
SIGNAL data_rdm: STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL en_i2cm: STD_LOGIC;
SIGNAL addr_i2c2m:STD_LOGIC_VECTOR(6 DOWNTO 0);
SIGNAL rw_i2cm: STD_LOGIC;
SIGNAL data_rwm: STD_LOGIC_VECTOR (7 DOWNTO 0);
SIGNAL sda1: STD_LOGIC;
SIGNAL scl1: STD_LOGIC;
--SIGNAL sdam: STD_LOGIC;
-------------------------------------------------
BEGIN
circuito1: i2c_master
	PORT MAP
	(
	 clk      =>clk,
    reset_n   =>reset_n,
    ena       =>en_i2c_in,
    addr      =>addr_i2c2m,
    rw        =>rw_i2cm,
    data_wr   =>data_rwm,
    busy      =>busy_i2cm,
    data_rd   =>data_rdm,
    ack_error => ack_error,
    sda       =>sda,
    scl       =>scl
	 );
	 
	circuito0: a_i2c
	PORT MAP
	(
	 scl       =>scl, 
    clk       =>clk,
    reset_n   =>reset_n,
	 start     =>start,
	 ch        =>ch,
	 pga       =>pga,
    dr        =>dr,
	 busy_i2c  =>busy_i2cm,
	 addr_i2c  => addr_i2c,
	 data_rd   =>data_rdm,
	 os        => os,
	 mode      => mode,
	 comp_mode =>comp_mode,
	 comp_pol  =>comp_pol,
	 comp_lat  =>comp_lat,
	 comp_que  =>comp_que,
	 en_i2c_in => en_i2c_in,
	 a00		  =>a00,
	 a11		  =>a11,
	 a22		  =>a22,
	 a33		  =>a33,
	 ack_error =>ack_error,
	 en_i2c    =>en_i2cm,
	 addr_i2c2 =>addr_i2c2m,
	 rw_i2c    =>rw_i2cm,
    data_rw   =>data_rwm,
	 ready     =>ready	
	 );
	 
	
	 
	 circuito2: ads1110
	 PORT MAP
	 (
	 sda=>sda,
     scl=>scl,
     reset_n=>reset_n
	  );
END rtl;