LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

entity tb_axi_iic is
end entity;

architecture arch of tb_axi_iic is
-- Width of S_AXI data bus
constant C_S_AXI_DATA_WIDTH : integer := 32;
-- Width of S_AXI address bus
constant C_S_AXI_ADDR_WIDTH : integer := 4;
-----------------------------------------------------
signal sda : STD_LOGIC;
signal scl : STD_LOGIC;

signal S_AXI_ACLK    : std_logic := '0';
signal S_AXI_ARESETN : std_logic;
signal S_AXI_AWADDR  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
signal S_AXI_AWVALID : std_logic;
signal S_AXI_WDATA   : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
signal S_AXI_WSTRB   : std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
signal S_AXI_WVALID  : std_logic;
signal S_AXI_BREADY  : std_logic;
signal S_AXI_ARADDR  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
signal S_AXI_ARVALID : std_logic;
signal S_AXI_RREADY  : std_logic;
signal S_AXI_ARREADY : std_logic;
signal S_AXI_RDATA   : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
signal S_AXI_RRESP   : std_logic_vector(1 downto 0);
signal S_AXI_RVALID  : std_logic;
signal S_AXI_WREADY  : std_logic;
signal S_AXI_BRESP   : std_logic_vector(1 downto 0);
signal S_AXI_BVALID  : std_logic;
signal S_AXI_AWREADY : std_logic;
signal S_AXI_AWPROT  : std_logic_vector(2 downto 0);
signal S_AXI_ARPROT  : std_logic_vector(2 downto 0);
-----------------------------------------------------
constant period      : time :=	10 ns;
constant half_period : time :=	period/2;
constant OFFSET     : time := 10 ns;
-----------------------------------------------------
signal sendIt : std_logic := '0';
signal readIt : std_logic := '0';
-----------------------------------------------------
SIGNAL conf_vect: STD_LOGIC_VECTOR(15 DOWNTO 0); --vector de configuración del ads
-----------------------------------------------------
constant P1:STD_LOGIC_VECTOR(7 DOWNTO 0):="00000001";
constant P0:STD_LOGIC_VECTOR(7 DOWNTO 0):="00000000";
constant pga : std_logic_vector(2 downto 0):= "010";
constant dr : std_logic_vector(2 downto 0):= "111";
constant addr_i2c: std_logic_vector(6 downto 0) := "1001000";
constant os       : STD_LOGIC :='1';
constant mode     : STD_LOGIC :='1';
constant comp_mode: STD_LOGIC :='0';
constant comp_pol : STD_LOGIC :='0';
constant comp_lat : STD_LOGIC :='0';
constant comp_que : std_logic_vector(1 downto 0) :="11";

begin

uut_ads: entity work.ads1110
PORT MAP(
    sda=>sda,
    scl=>scl,
    reset_n=>S_AXI_ARESETN);

uut_axi_iic: entity work.axi_iic_wrapper
port map (
    sda => sda,
    scl => scl,
    s_axi_aclk    => S_AXI_ACLK,
    s_axi_aresetn => S_AXI_ARESETN,
    s_axi_awaddr  => S_AXI_AWADDR,
    s_axi_awprot  => S_AXI_AWPROT,
    s_axi_awvalid => S_AXI_AWVALID,
    s_axi_awready => S_AXI_AWREADY,
    s_axi_wdata   => S_AXI_WDATA,
    s_axi_wstrb   => S_AXI_WSTRB,
    s_axi_wvalid  => S_AXI_WVALID,
    s_axi_wready  => S_AXI_WREADY,
    s_axi_bresp   => S_AXI_BRESP,
    s_axi_bvalid  => S_AXI_BVALID,
    s_axi_bready  => S_AXI_BREADY,
    s_axi_araddr  => S_AXI_ARADDR,
    s_axi_arprot  => S_AXI_ARPROT,
    s_axi_arvalid => S_AXI_ARVALID,
    s_axi_arready => S_AXI_ARREADY,
    s_axi_rdata   => S_AXI_RDATA,
    s_axi_rresp   => S_AXI_RRESP,
    s_axi_rvalid  => S_AXI_RVALID,
    s_axi_rready  => S_AXI_RREADY);
    

-- clock generation
S_AXI_ACLK <= not S_AXI_ACLK after half_period;

-- Initiate process which simulates a master wanting to write.
-- This process is blocked on a "Send Flag" (sendIt).
-- When the flag goes to 1, the process exits the wait state and
-- execute a write transaction.
send : PROCESS
BEGIN
   S_AXI_AWVALID<='0';
   S_AXI_WVALID<='0';
   S_AXI_BREADY<='0';
   loop
       wait until sendIt = '1';
       wait until S_AXI_ACLK= '0';
           S_AXI_AWVALID<='1';
           S_AXI_WVALID<='1';
       wait until (S_AXI_AWREADY and S_AXI_WREADY) = '1';  --Client ready to read address/data        
           S_AXI_BREADY<='1';
       wait until S_AXI_BVALID = '1';  -- Write result valid
           assert S_AXI_BRESP = "00" report "AXI data not written" severity failure;
           S_AXI_AWVALID<='0';
           S_AXI_WVALID<='0';
           S_AXI_BREADY<='1';
       wait until S_AXI_BVALID = '0';  -- All finished
           S_AXI_BREADY<='0';
   end loop;
END PROCESS send;
 -- Initiate process which simulates a master wanting to read.
 -- This process is blocked on a "Read Flag" (readIt).
 -- When the flag goes to 1, the process exits the wait state and
 -- execute a read transaction.
 read : PROCESS
 BEGIN
   S_AXI_ARVALID<='0';
   S_AXI_RREADY<='0';
    loop
        wait until readIt = '1';
        wait until S_AXI_ACLK= '0';
            S_AXI_ARVALID<='1';
            S_AXI_RREADY<='1';
        wait until (S_AXI_ARREADY) = '1';  --Client provided data
        wait until S_AXI_RVALID = '1';
        wait until S_AXI_RVALID = '0';
           assert S_AXI_RRESP = "00" report "AXI data not written" severity failure;
           S_AXI_RREADY<='0';
           S_AXI_ARVALID<='0';
    end loop;
 END PROCESS read;

-- Se concatena el vector configuración con los correspondientes parámetros del tadashett
conf_vect <= os & "100" & pga & mode & dr & comp_mode & comp_pol & comp_lat & comp_que; -- ch 0
-- 
tb : PROCESS
variable write_ready : std_logic;
BEGIN
    S_AXI_ARESETN<='0';
    sendIt<='0';
    
    -------------------------------------------------------- Start Write
    wait for 3 us;
       S_AXI_ARESETN<='1';
       
       S_AXI_AWADDR<=b"0000";     -- reg0
           S_AXI_WDATA<=b"000000000000000000000" & "011" & addr_i2c & "0"; -- send 3 bytes | addr | rd  
           S_AXI_WSTRB<=b"1111";
           sendIt<='1';                --Start AXI Write to Slave
           wait for 1 ns; sendIt<='0'; --Clear Start Send Flag
       wait until S_AXI_BVALID = '1';
       wait until S_AXI_BVALID = '0';  --AXI Write finished
           S_AXI_WSTRB<=b"0000";
       
    wait for 100 ns;
    
    S_AXI_ARESETN<='1';
       
    S_AXI_AWADDR<=b"0100";     -- reg1
        S_AXI_WDATA<=b"00000000" & P1 & conf_vect ; -- 15 bits config
        S_AXI_WSTRB<=b"1111";
        sendIt<='1';                --Start AXI Write to Slave
        wait for 1 ns; sendIt<='0'; --Clear Start Send Flag
    wait until S_AXI_BVALID = '1';
    wait until S_AXI_BVALID = '0';  --AXI Write finished
        S_AXI_WSTRB<=b"0000";
    
    wait for 100 ns;    
    -------------------------------------------------------- Wait Write
    write_ready := '0';
    while write_ready='0' loop
            S_AXI_ARADDR<=b"0000";
            readIt<='1';                --Start AXI Read from Slave
            wait for 1 ns; readIt<='0'; --Clear "Start Read" STATUS
        wait until S_AXI_RVALID = '1';
        wait until S_AXI_RVALID = '0';
        
        wait for 100 ns;
        if S_AXI_RDATA(C_S_AXI_DATA_WIDTH-1)='0' then
            write_ready := '1';
        end if;

    end loop;
    --------------------------------------------------------- Config Read mode          
    S_AXI_AWADDR<=b"0000";     -- reg0
       S_AXI_WDATA<=b"000000000000000000000" & "001" & addr_i2c & "0"; -- send 1 bytes | addr | rd  
       S_AXI_WSTRB<=b"1111";
       sendIt<='1';                --Start AXI Write to Slave
       wait for 1 ns; sendIt<='0'; --Clear Start Send Flag
    wait until S_AXI_BVALID = '1';
    wait until S_AXI_BVALID = '0';  --AXI Write finished
       S_AXI_WSTRB<=b"0000";
           
    wait for 100 ns;
       
    S_AXI_AWADDR<=b"0100";     -- reg1
        S_AXI_WDATA<=b"000000000000000000000000" & P0; -- P1
        S_AXI_WSTRB<=b"1111";
        sendIt<='1';                --Start AXI Write to Slave
        wait for 1 ns; sendIt<='0'; --Clear Start Send Flag
    wait until S_AXI_BVALID = '1';
    wait until S_AXI_BVALID = '0';  --AXI Write finished
        S_AXI_WSTRB<=b"0000";
    
    wait for 100 ns;
    
    -------------------------------------------------------- Wait Write
    write_ready := '0';
        while write_ready='0' loop
                S_AXI_ARADDR<=b"0000";
                readIt<='1';                --Start AXI Read from Slave
                wait for 1 ns; readIt<='0'; --Clear "Start Read" STATUS
            wait until S_AXI_RVALID = '1';
            wait until S_AXI_RVALID = '0';
            
            wait for 100 ns;
            if S_AXI_RDATA(C_S_AXI_DATA_WIDTH-1)='0' then
                write_ready := '1';
            end if;
        end loop;
    --------------------------------------------------------- Start Read
    wait for 10 us;
    
       S_AXI_AWADDR<=b"0000";     -- reg0
       S_AXI_WDATA<=b"000000000000000000000" & "010" & addr_i2c & "1"; -- reveive 2 bytes | addr | rd  
       S_AXI_WSTRB<=b"1111";
       sendIt<='1';                --Start AXI Write to Slave
       wait for 1 ns; sendIt<='0'; --Clear Start Send Flag
    wait until S_AXI_BVALID = '1';
    wait until S_AXI_BVALID = '0';  --AXI Write finished
       S_AXI_WSTRB<=b"0000";

    wait for 100 ns;
    --------------------------------------------------------- Wait End Read
    write_ready := '0';
        while write_ready='0' loop
                S_AXI_ARADDR<=b"0000";
                readIt<='1';                --Start AXI Read from Slave
                wait for 1 ns; readIt<='0'; --Clear "Start Read" STATUS
            wait until S_AXI_RVALID = '1';
            wait until S_AXI_RVALID = '0';
            
            wait for 100 ns;
            if S_AXI_RDATA(C_S_AXI_DATA_WIDTH-1)='0' then
                write_ready := '1';
            end if;
        end loop;
    --------------------------------------------------------- Read Incoming Data
    wait for 1 us;
           
           S_AXI_ARADDR<=b"1000"; --------------------------- Reg2 has read buffer
                readIt<='1';                --Start AXI Read from Slave
                wait for 1 ns; readIt<='0'; --Clear "Start Read" STATUS
            wait until S_AXI_RVALID = '1';
            wait until S_AXI_RVALID = '0';
            
            wait for 100 ns;
        
    wait; -- will wait forever
END PROCESS tb;

end architecture arch;