-- Quartus II VHDL Template
-- Four-State Moore State Machine

-- A Moore machine's outputs are dependent only on the current state.
-- The output is written only when the state changes.  (State
-- transitions are synchronous.)

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

entity a_i2c is
--GENERIC(
 --   input_clk : INTEGER := 50_000_000; --input clock speed from user logic in Hz
 --   bus_clk   : INTEGER := 400_000);   --speed the i2c bus (scl) will run at in Hz
PORT(
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
	a00	   : OUT 	  STD_LOGIC_VECTOR(15 DOWNTO 0);
	a11	   : OUT 	  STD_LOGIC_VECTOR(15 DOWNTO 0);
	a22	   : OUT 	  STD_LOGIC_VECTOR(15 DOWNTO 0);
	a33	   : OUT 	  STD_LOGIC_VECTOR(15 DOWNTO 0);
    ack_error  : BUFFER STD_LOGIC );                  --flag if improper acknowledge from slave
end entity;

architecture rtl of a_i2c is
--constant cont_max := input_clk
--  CONSTANT divider  :  INTEGER := (input_clk/bus_clk)/4; --number of clocks in 1/4 cycle of scl
  TYPE a000 IS array (3 DOWNTO 0) OF STD_LOGIC_VECTOR (15 DOWNTO 0);--memoria a0, aqui se guardan los valores del ads si el canal es 100
  TYPE a111 IS array (3 DOWNTO 0) OF STD_LOGIC_VECTOR (15 DOWNTO 0);--memoria a1, aqui se guardan los valores del ads si el canal es 101
  TYPE a222 IS array (3 DOWNTO 0) OF STD_LOGIC_VECTOR (15 DOWNTO 0);--memoria a2, aqui se guardan los valores del ads si el canal es 110
  TYPE a333 IS array (3 DOWNTO 0) OF STD_LOGIC_VECTOR (15 DOWNTO 0);--memoria a3, aqui se guardan los valores del ads si el canal es 111
  TYPE chan IS ARRAY (0 TO 3) OF STD_LOGIC_VECTOR(7 DOWNTO 0); --vector auxiliar que ayuda a hacer el vector de configuración (este depende del canal)
  SIGNAL a0: a000; 
  SIGNAL a1: a111;
  SIGNAL a2: a222;
  SIGNAL a3: a333;
  SIGNAL channel:chan;
  SIGNAL p : STD_LOGIC_VECTOR(1 DOWNTO 0):="01"; --señal que ayuda a generar el vector data_rw donde su valor depende del estado de la maquina, mirar datasheet
  SIGNAL i  : INTEGER RANGE 0 TO 4:=0; --señal que se utiliza para seleccionar el valor de channel que deseamos utilizar
  SIGNAL conf_vect: STD_LOGIC_VECTOR(15 DOWNTO 0); --vector de configuración del ads
  SIGNAL conv_reg: STD_LOGIC_VECTOR(15 DOWNTO 0);  --vector de lectura del modulo ads
  SIGNAL aux_data_rw: STD_LOGIC_VECTOR (7 DOWNTO 0); -- datos a ser enviados por la salida data_rw
  SIGNAL aux_addr_i2c: STD_LOGIC_VECTOR (6 DOWNTO 0); --datos a ser enviado por la salida addr_i2c2
  SIGNAL busy_i2c_ant  :STD_LOGIC;                    --entrada del busy del modulo i2c anterior.
  SIGNAL scl_ant   :      STD_LOGIC;                   --etrada del scl del modulo i2c ANTERIOR
	type state_type is (inicio,  ea, ep, ee1,cr1,cr2,cr3 ,ea2,r1,ackl_master,contador,r2,stop,stop1);-- maquina de estados que se utilizará en este código
	-- Register to hold the current state
	signal state   : state_type;
	
begin
	-- Logic to advance to the next state
	---------------------------------------
	PROCESS(clk)
		BEGIN
			if(rising_edge(clk))then
				conf_vect<=os & "000" & pga & mode & dr & comp_mode & comp_pol & comp_lat & comp_que;-- Se concatena el vector configuración con los correspondientes parámetros del tadashett
				channel(0)<="01000000";channel(1)<="01010000";channel(2)<="01100000";channel(3)<="01110000";--se guardan los valores posibles del canal datasheet
			end if;
	END PROCESS;
	------------------------------------------
	process (clk, reset_n, scl)
		CONSTANT ceros: STD_LOGIC_VECTOR(5 DOWNTO 0):="000000"; --constante que se utiliza cuando se envia el valor de p
		VARIABLE cont: INTEGER RANGE 0 TO 10:=0; --variable que se utilizará para simular un wait de 100 ns
		VARIABLE ch_aux: std_LOGIC_VECTOR(2 DOWNTO 0); --variable que se utilizará para guardar el canal por el cual se esta leyendo
		VARIABLE ii: INTEGER RANGE 0 TO 4:=0;
		VARIABLE ii2: INTEGER RANGE 0 TO 4:=0;
		VARIABLE ii3: INTEGER RANGE 0 TO 4:=0;
		VARIABLE ii4: INTEGER RANGE 0 TO 4:=0;
		VARIABLE v: STD_LOGIC:='0';
	begin
	
		if reset_n = '0' then
			state <= inicio;--faltan otros valores para reiniciar.
		elsif (rising_edge(clk)) then
			busy_i2c_ant<= busy_i2c;
			scl_ant<=scl;
			en_i2c<=en_i2c_in;
			 
			case state is
---------------------------------------------------------- prepara la dirección del ads para ser enviado al igual que el valor de p, el valor de wr.
				when inicio=>
					if (start = '1' and busy_i2c='0') then --se espera hasta que star se accióne y busy en cero indica que el modulo i2c esta libre para comenzar la comunicación
					   if (busy_i2c_ant/=busy_i2c and busy_i2c='0') then	
						ch_aux := ch; -- guarda el canal por el cual se realizará la lectura 
						aux_addr_i2c<=addr_i2c; -- guarda la dirección por donde se realizará la lectura
						  --p toma el valor correspondiente para realizar la respectiva configuración del módulo ads
						aux_data_rw<=ceros&p;
						state<=inicio;
					   else
					   state<=ea;
					   end if;
				    else
						state <= inicio;-- si la señal de star no se ha activa quedese en este estado
					end if;
				-----------------------------	
				
-------------------------------------------------------concatena el vector data_rw con los valores de p para configurar el modulo ads, ademas de enviar la dirección del módulo ads
				when ea=>
				if (busy_i2c_ant/=busy_i2c and busy_i2c='1') then-- espera la señal de confirmación del módulo ads 
						if (p="01") then --cuando p se encuentre en modo configuración
						--	aux_data_rw<=ceros&p; -- concatena la constate ceros con el valor de 
                            case ch_aux is
                               when "000" => -- dependiendo del canal a sí mismo será la configuración de los primeros 8 valores del vector de configuración
                                   aux_data_rw <= conf_vect(15 downto 8) or channel(0);
                                   state <= ep;-- todos los case pasan al mismo estado de ee1
                              when "001"=>
                                   aux_data_rw<=conf_vect(15 downto 8) or channel(1);
                                   state <= ep;
                              when "010"=> 
                                   aux_data_rw<=conf_vect(15 downto 8) or channel(2);
                                  state <= ep;
                              when "011"=>
                                   aux_data_rw<=conf_vect(15 downto 8) or channel(3);
                                   state <= ep;
                              when others=>
                                   aux_data_rw<="00000000";
                              end case;
						else
						  state <= r1; -- pasamos al siguiente estado de 
						end if;
				   else
					   state<=ea;-- si p esta en modo lectura pasamos a los estados de lectura
					   -- si no se recive la señal de confirmación quedamos en el mismo estado
				   end if;
------------------------------------------------------------------Concatena los 8 primeros datos de la configuración dependiendo del canal
				when ep=>
		     		if (busy_i2c_ant/=busy_i2c and busy_i2c='0') then 
                       aux_data_rw<=conf_vect(7 DOWNTO 0);-- termina de cargar los datos para la configuración del módulo ads
                       p<="00";
                       state <= ee1;-- pasa al ultimo estado de configuración
                    else
                    state <= ep;-- si no se recive el la señal de confirmación por parte del módulo ads se queda en el mismo estado
					end if;
-------------------------------------------------------------envia la primera configuración y carga los datos de la segunda configuración
				when ee1 =>
					-- esperamos la confirmación del módulo ads 
                    -- cambiamos la configuración del vector p que era de configuración para lectura del módulo ads
                    if (busy_i2c_ant/=busy_i2c and busy_i2c='0') then    
                        v:='1';
                        aux_data_rw<=ceros&p;
                        state<=cr1;--volvemos al estado ea para enviar el vetor p al modulo ads
                    else
                        state<=ee1;
                   end if;
----------------------------------------------------------------Termina de realizar la configuracion del modulo ads
                when cr1=>
                 if (busy_i2c_ant/=busy_i2c and busy_i2c='0') then  
                    state<=cr2;
                 end if;
                when cr2 =>
                  if (busy_i2c_ant/=busy_i2c and busy_i2c='0') then  
                    state<=cr3;
                 end if;  
                 when cr3 =>
                 if (busy_i2c_ant/=busy_i2c and busy_i2c='0') then  
                    state<=ea2;
                 end if;  
----------------------------------------------------Envio de la dirección y concatenación del vector data_rw con la configuracion de p
--------------------------------------------------------------Estado de la primera lectura por parte del modulo i2c
				when ea2 =>
				if (busy_i2c_ant/=busy_i2c and busy_i2c='0') then-- esperamos la confirmación del módulo ads 
                   aux_data_rw<=ceros&p;-- cambiamos la configuración del vector p que era de configuración para lectura del módulo ads
                   state<=r1;--volvemos al estado ea para enviar el vetor p al modulo ads
                else
                    state<=ea2; -- -- sí no recive la confirmación del módulo ads se queda en el mismo estado.
                end if;
                
				when r1=>
					if (busy_i2c_ant/=busy_i2c and busy_i2c='0') then-- espera la confirmación por parte de la dirección que se envio nuevamente(ver process de salidas)
						conv_reg(15 downto 8)<=data_rd;--se lee el valor que llega del modulo i2c
						state <= ackl_master;--pasamos al siguiente estado
					else
						state<=r1;--si todavia no llega la confirmación del modulo ads quedamos en el mismo estado
					end if;
-------------------------------------------------------------Comienza la confirmación del ackl_master
				when ackl_master =>
					 if (busy_i2c = '0')then                  -- esperar busy en nivel baixo para seguinte op																							--	 ena <= '0';-- deshabilitar modulo para nova operação
						if(scl_ant/=scl and scl = '0')then        -- esperar a descer e subir
							    -- esperar a scl ser desabilitado
							   state<=contador;                 -- pasa al estado para esperar 100ns para ads preparar (esto lo saq
					           
						end if;
					 else
					 state<=ackl_master;-- si no sucede las condiciones anterirmente descritas queda en el estado de ackl_master
                end if;
---------------------------------------------------------estado de espera para 100ns segun el tb de Sergio					 
				when contador=>
					if (cont=10) then-- termina de contar
						cont:=0;--se reinicia el contador
						state<=r2;--pasa al estado de lectura 2
					else
						cont:=cont+1;--acrecenta el contador
						state<=contador;--hasta que no llegue a 10 no cambia de estado
					end if;
					
--------------------------------------------------------- estado de lectura 2
				when r2=>
				if (busy_i2c_ant/=busy_i2c and busy_i2c='0') then
				 conv_reg(7 DOWNTO 0)<=data_rd;--realiza la lectura de los ultimos 8 bits del modulo ads
				 state<=stop1;-- pasa al estado de parada.
				 end if;
			   when stop=>
			      state<=inicio;
----------------------------------------------------------termina la primera lectura
				when stop1=>
					case ch_aux is
							when "000" => -- dependiendo del canal a sí mismo será la configuración de los primeros 8 valores del vector de configuración
								    a0(ii) <= conv_reg;
								    a00<=conv_reg;
								    ii:=ii+1;
								    state<=inicio;--pasa nuevamente al estado de inicio.
								IF (ii=3)THEN
									ii2:=0;
									state<=inicio;--pasa nuevamente al estado de inicio.
								ELSE
									ii2:=ii2;
								END IF;
								
								
							when "001"=>
								a1(ii2) <= conv_reg;
								a11<=conv_reg;
								ii2:=ii2+1;
								IF (ii2=3)THEN
									ii2:=0;
								ELSE
									ii2:=ii2;
								END IF;
								state<=inicio;--pasa nuevamente al estado de inicio.
							when "010"=> 
								a2(ii3) <= conv_reg;
								a22<=a2(ii3);
								ii3:=ii3+1;
								IF (ii3=3) THEN
									ii3:=0;
								ELSE
									ii3:=ii3;
								END IF;
								state<=inicio;--pasa nuevamente al estado de inicio.
							when "011"=>
								a3(ii4) <= conv_reg;
								a33<=a3(ii4);
								ii4:=ii4+1;
								IF (ii4=3)THEN
									ii4:=0;
								ELSE
									ii4:=ii4;
								END IF;
								state<=inicio;--pasa nuevamente al estado de inicio.
							when others=>
								a00<=(OTHERS =>'0');
								a11<=(OTHERS =>'0');
								a22<=(OTHERS =>'0');
								a33<=(OTHERS =>'0');
						end case;	
			end case;
		end if;
	end process;

	-- Output depends solely on the current state
	process (state,addr_i2c,aux_addr_i2c,aux_data_rw)
	VARIABLE b: STD_LOGIC:='0';
	begin
		case state is
			when inicio =>
			--	addr_i2c2<=addr_i2c;-- se envia el vector diección al módulo ads
				addr_i2c2<=addr_i2c;
			    rw_i2c<='0';
			 --   data_rw<=aux_data_rw;      -- se envia el valor de lectura al modulo ads
				
			    
			when ea =>
			-- como todavia no ha realizado la configuración b=0
			 data_rw<=aux_data_rw;   
			--	data_rw<=aux_data_rw;-- se guardan los datos con el valor de p al modulo ads
					--addr_i2c2<=addr_i2c;
					--rw_i2c<='0';
			when ep =>--se envian los datos del vector p
				data_rw<=aux_data_rw; -- se guardan los primeros 8 valores de la configuración
				--addr_i2c2<=(others=>'0');
				--rw_i2c<='0';
			when ee1 => -- se envian los primeros 8 valores del vector de configuración
				-- se guardan los ultimos valores del vector de configuración
			--	addr_i2c2<=addr_i2c;
			 data_rw<=aux_data_rw;
			--	rw_i2c<='0'; 
            --    addr_i2c2<=aux_addr_i2c;
            --    rw_i2c<='0';			
			--	addr_i2c2<=(others=>'0');
			--	rw_i2c<='0
			when cr1 =>
			  data_rw<=addr_i2c&"0";
			    
			when cr2 =>
			    data_rw<=aux_data_rw;
			when cr3 =>
			      data_rw<=addr_i2c&'1';
			  --   rw_i2c<='1';
            when ea2 =>
            --   data_rw<=aux_data_rw;-- se guardan los datos con el valor de p al modulo ads
                    rw_i2c<='1';
             --    data_rw<=aux_data_rw;
            --     rw_i2c<='0';
			when r1=>--enviamos el valor de la dirección y de la escritua
			--  data_rw<=aux_data_rw;
				--data_rw<=(others =>'0');
				--addr_i2c2<=(others=>'0');
				 
			when ackl_master=>-- no enviamos nada
				--data_rw<=(others =>'0');
			--	data_rw<='1';
				--addr_i2c2<=(others=>'0');
				--rw_i2c<='1';
			when contador=>--no enviamos nada
				--data_rw<=(others =>'0');
				--addr_i2c2<=(others=>'0');
				--rw_i2c<='1';
			when r2 =>
			--	addr_i2c2<="0000000";                      -- muda endereço a 0000000 para parar modulo
			--    rw_i2c <='0';                              -- inverte rw para parar modulo (tambem)
			--data_rw<='0';
			--	data_rw<=(others =>'0');
		    when stop=>
		    
			when stop1 =>
				data_rw<=(others =>'0');
				addr_i2c2<=(others=>'0');
				rw_i2c<='0';
		end case;
	end process;

end rtl;
