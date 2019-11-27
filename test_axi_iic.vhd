----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.11.2019 15:30:38
-- Design Name: 
-- Module Name: test_axi_iic - Behavioral
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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity test_axi_iic is
    Port ( clk : in STD_LOGIC;
           rst_n : in STD_LOGIC;
           ena : in STD_LOGIC;
           ena_out : out STD_LOGIC;
           
           scl : inout STD_LOGIC;
           sda : inout STD_LOGIC);
end test_axi_iic;

architecture Behavioral of test_axi_iic is
constant C_S_AXI_DATA_WIDTH : integer := 32;
constant C_S_AXI_ADDR_WIDTH : integer := 4;
-----------------------------------------------------
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
constant addr_i2c: std_logic_vector(6 downto 0) := "1001000";
constant buffer_1 : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := X"0001c5e3";
constant buffer_2 : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := X"00000000";
signal   buffer_3 : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

signal sendIt : std_logic := '0';
signal readIt : std_logic := '0';

TYPE machine IS (idle, s1, s2, s3, s4, s5); --needed states
signal state : machine;

TYPE sendIt_machine IS (idle, s1, s2, s3); --needed states
signal sendIt_state : machine;

TYPE readIt_machine IS (idle, s1, s2, s3); --needed states
signal readIt_state : machine;

begin

uut_axi_iic: entity work.axi_iic_wrapper
port map (
    sda => sda,
    scl => scl,
    s_axi_aclk    => clk,
    s_axi_aresetn => rst_n,
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
    
    -- Initiate process which simulates a master wanting to write.
    -- This process is blocked on a "Send Flag" (sendIt).
    -- When the flag goes to 1, the process exits the wait state and
    -- execute a write transaction.
    PROCESS(clk)
    BEGIN
    if rising_edge(clk) then
        if rst_n = '0' then
            S_AXI_AWVALID<='0';
            S_AXI_WVALID<='0';
            S_AXI_BREADY<='0';
            
            sendIt_state <= idle;
        else
            case( sendIt_state ) is
                when IDLE =>
                if sendIt = '1' then
                    S_AXI_AWVALID<='1';
                    S_AXI_WVALID<='1';
                    sendIt_state <= s1;
                end if ;
                    
                when s1 => 
                if (S_AXI_AWREADY and S_AXI_WREADY) = '1' then
                    S_AXI_BREADY<='1';
                    sendIt_state <= s2;
                end if ;

                when s2 => 
                if S_AXI_BVALID = '1' then
                    S_AXI_AWVALID<='0';
                    S_AXI_WVALID<='0';
                    S_AXI_BREADY<='1';
                    sendIt_state <= s3;
                end if ;

                when s3 =>
                if S_AXI_BVALID = '0' then
                    S_AXI_BREADY<='0';
                    sendIt_state <= idle;
                end if ;

                when others => NULL;
            
            end case ;
            
        end if ;
    end if ;
    END PROCESS;

    -- Initiate process which simulates a master wanting to read.
    -- This process is blocked on a "Read Flag" (readIt).
    -- When the flag goes to 1, the process exits the wait state and
    -- execute a read transaction.
    PROCESS(clk)
    BEGIN
    if rising_edge(clk) then
        if rst_n = '0' then
            S_AXI_ARVALID<='0';
            S_AXI_RREADY<='0';
                  
            readIt_state <= idle;
        else
            case( readIt_state ) is
                when IDLE =>
                if readIt = '1' then
                    S_AXI_ARVALID<='1';
                    S_AXI_RREADY<='1';
                    readIt_state <= s1;
                end if ;
                    
                when s1 => 
                if S_AXI_ARREADY='1' then
                    if S_AXI_RVALID = '1' then
                        readIt_state <= s3;
                    else
                        readIt_state <= s2;
                    end if;
                end if;

                when s2 => 
                if S_AXI_RVALID = '1' then
                    readIt_state <= s3;
                end if;

                when s3 =>
                if S_AXI_RVALID = '0' then
                    S_AXI_RREADY<='0';
                    S_AXI_ARVALID<='0';
                    readIt_state <= idle;
                end if;

                when others => NULL;
            
            end case ;
            
        end if ;
    end if ;
    END PROCESS;

    -- FSM process
    process(clk)
    variable buff_size : integer range 1 to 4;
    variable buff_size_v : std_logic_vector(2 downto 0);
    variable ena_prev : std_logic;
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                state <= idle;
                S_AXI_AWADDR  <= (others=>'0');
                S_AXI_WDATA   <= (others=>'0');
                S_AXI_WSTRB   <= (others=>'0');
                S_AXI_ARADDR  <= (others=>'0');
                S_AXI_ARVALID <= '0';
                S_AXI_AWPROT  <= (others=>'0');
                S_AXI_ARPROT  <= (others=>'0');
                
                buffer_3 <= (others=>'0');
                state <= idle;
                buff_size := 1;
                
                ena_out <= '0';
            else
                case(state) is
                
                    when idle =>
                    if ena = '1' then
                        state <= s1;
                        ena_out <= '1';
                    else
                        ena_out <= '0';
                    end if;
                    buff_size := 3;
                    buff_size_v := std_logic_vector(to_unsigned(buff_size, buff_size_v'length));
                    S_AXI_AWADDR<=b"0000";     -- reg0
                    S_AXI_WDATA<=b"000000000000000000000" & buff_size_v & addr_i2c & "0"; -- send 3 bytes | addr | rd  
                    S_AXI_WSTRB<=b"1111";
                    sendIt<='1';                --Start AXI Write to Slave
                    ena_prev := ena;
                
                    when s1 =>
                    sendIt<='0';                --Start AXI Write to Slave
                    if S_AXI_BVALID = '1' then
                        state <= s2;
                    end if;
                    
                    when s2 =>
                    if S_AXI_BVALID = '0' then
                        state <= s3;
                        S_AXI_WSTRB<=b"0000";
                    end if;

                    when s3 =>
                    S_AXI_AWADDR<=b"0100";     -- reg1
                    S_AXI_WDATA<=buffer_1; -- 15 bits config
                    S_AXI_WSTRB<=b"1111";
                    sendIt<='1';                --Start AXI Write to Slave
                    state <= s4;

                    when s4 =>
                    sendIt<='0';                --Start AXI Write to Slave
                    if S_AXI_BVALID = '1' then
                        state <= s5;
                    end if;
                    
                    when s5 =>
                    if S_AXI_BVALID = '0' then
                        state <= idle;
                        S_AXI_WSTRB<=b"0000";
                    end if;
                    when others => NULL;
                
                end case ;    
            end if ;
        end if ;
    end process ;

end Behavioral;
