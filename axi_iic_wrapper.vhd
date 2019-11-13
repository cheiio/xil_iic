library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_iic_wrapper is
	generic (
		-- Users to add parameters here
        input_clk : INTEGER := 50_000_000; --input clock speed from user logic in Hz
        bus_clk   : INTEGER := 400_000);   --speed the i2c bus (scl) will run at in Hz
		-- User parameters ends
		-- Do not modify the parameters beyond this line

		-- Parameters of Axi Slave Bus Interface S00_AXI
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		C_S_AXI_ADDR_WIDTH	: integer	:= 7 -- iic 7 bit address
	);
	port (
		-- Users to add ports here
        sda       : INOUT  STD_LOGIC;
        scl       : INOUT  STD_LOGIC
		-- User ports ends
		-- Do not modify the ports beyond this line


        -- Ports of Axi Slave Bus Interface S00_AXI
        -- Clock and Reset
		s_axi_aclk	: in std_logic;
		s_axi_aresetn	: in std_logic;
        -- Write Address Channel
        s_axi_awaddr	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		s_axi_awprot	: in std_logic_vector(2 downto 0);
		s_axi_awvalid	: in std_logic;
		s_axi_awready	: out std_logic;
        -- Write Data Channel
        s_axi_wdata	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		s_axi_wstrb	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		s_axi_wvalid	: in std_logic;
		s_axi_wready	: out std_logic;
        -- Write Response Channel
        s_axi_bresp	: out std_logic_vector(1 downto 0);
		s_axi_bvalid	: out std_logic;
		s_axi_bready	: in std_logic;
        -- Read Address Channel
        s_axi_araddr	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		s_axi_arprot	: in std_logic_vector(2 downto 0);
		s_axi_arvalid	: in std_logic;
		s_axi_arready	: out std_logic;
        -- Read Data Channel
        s_axi_rdata	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		s_axi_rresp	: out std_logic_vector(1 downto 0);
		s_axi_rvalid	: out std_logic;
		s_axi_rready	: in std_logic
	);
end axi_iic_wrapper;

architecture arch_imp of axi_iic_wrapper is

-- component declaration
component i2c_master IS
  GENERIC(
    input_clk : INTEGER := 50_000_000;
    bus_clk   : INTEGER := 400_000);  
  PORT(
    clk       : IN     STD_LOGIC;
    reset_n   : IN     STD_LOGIC;
    ena       : IN     STD_LOGIC;
    addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0);
    rw        : IN     STD_LOGIC;
    data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0);
    busy      : OUT    STD_LOGIC;
    data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0);
    ack_error : BUFFER STD_LOGIC;
    sda       : INOUT  STD_LOGIC;
    scl       : INOUT  STD_LOGIC);
END component;

-- AXI4LITE signals
signal axi_awaddr	: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
signal axi_awready	: std_logic;
signal axi_wready	: std_logic;
signal axi_bresp	: std_logic_vector(1 downto 0);
signal axi_bvalid	: std_logic;
signal axi_araddr	: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
signal axi_arready	: std_logic;
signal axi_rdata	: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
signal axi_rresp	: std_logic_vector(1 downto 0);
signal axi_rvalid	: std_logic;

-- Example-specific design signals
-- local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
-- ADDR_LSB is used for addressing 32/64 bit registers/memories
-- ADDR_LSB = 2 for 32 bits (n downto 2)
-- ADDR_LSB = 3 for 64 bits (n downto 3)
constant ADDR_LSB  : integer := (C_S_AXI_DATA_WIDTH/32)+ 1;
constant OPT_MEM_ADDR_BITS : integer := 1;

--------------------------------------------------
---- Signals for user logic register space example
--------------------------------------------------
-- slv_reg |  | data_wr | addr | r/w |
--     bit |  |  24-8   |  7-1 |  0  |
signal slv_reg :std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
signal slv_reg_rden	: std_logic;
signal slv_reg_wren	: std_logic;
-- reg_out |  | data_rd |
--     bit |  |  15-0   |
signal reg_data_out	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
signal byte_index	: integer;
signal aw_en	: std_logic;

-- Signals for Modules
signal ena       : STD_LOGIC;
signal addr      : STD_LOGIC_VECTOR(6 DOWNTO 0);
signal rw        : STD_LOGIC;
signal data_wr   : STD_LOGIC_VECTOR(7 DOWNTO 0);
signal busy      : STD_LOGIC;
signal data_rd   : STD_LOGIC_VECTOR(7 DOWNTO 0);
signal ack_error : STD_LOGIC;
signal ready_in  : STD_LOGIC;
signal reg_data_rd : STD_LOGIC_VECTOR(15 DOWNTO 0);

begin

    -- I/O Connections assignments

    S_AXI_AWREADY	<= axi_awready;
    S_AXI_WREADY	<= axi_wready;
    S_AXI_BRESP	<= axi_bresp;
    S_AXI_BVALID	<= axi_bvalid;
    S_AXI_ARREADY	<= axi_arready;
    S_AXI_RDATA	<= axi_rdata;
    S_AXI_RRESP	<= axi_rresp;
    S_AXI_RVALID	<= axi_rvalid;
    
    -- Implement axi_awready generation
    -- axi_awready is asserted for one S_AXI_ACLK clock cycle when both
    -- S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
    -- de-asserted when reset is low.

    process (S_AXI_ACLK)
    begin
    if rising_edge(S_AXI_ACLK) then 
        if S_AXI_ARESETN = '0' then
        axi_awready <= '0';
        aw_en <= '1';
        else
        if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
            -- slave is ready to accept write address when
            -- there is a valid write address and write data
            -- on the write address and data bus. This design 
            -- expects no outstanding transactions. 
            axi_awready <= '1';
        elsif (S_AXI_BREADY = '1' and axi_bvalid = '1' and busy = '0') then
            aw_en <= '1';
            axi_awready <= '0';
        else
            axi_awready <= '0';
        end if;
        end if;
    end if;
    end process;

    -- Implement axi_awaddr latching
    -- This process is used to latch the address when both 
    -- S_AXI_AWVALID and S_AXI_WVALID are valid. 

    process (S_AXI_ACLK)
    begin
    if rising_edge(S_AXI_ACLK) then 
        if S_AXI_ARESETN = '0' then
        axi_awaddr <= (others => '0');
        else
        if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
            -- Write Address latching
            axi_awaddr <= S_AXI_AWADDR;
        end if;
        end if;
    end if;                   
    end process; 

    -- Implement axi_wready generation
    -- axi_wready is asserted for one S_AXI_ACLK clock cycle when both
    -- S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
    -- de-asserted when reset is low. 

    process (S_AXI_ACLK)
    begin
    if rising_edge(S_AXI_ACLK) then 
        if S_AXI_ARESETN = '0' then
        axi_wready <= '0';
        else
        if (axi_wready = '0' and S_AXI_WVALID = '1' and S_AXI_AWVALID = '1' and aw_en = '1') then
            -- slave is ready to accept write data when 
            -- there is a valid write address and write data
            -- on the write address and data bus. This design 
            -- expects no outstanding transactions.           
            axi_wready <= '1';
        else
            axi_wready <= '0';
        end if;
        end if;
    end if;
    end process; 

    -- Implement memory mapped register select and write logic generation
    -- The write data is accepted and written to memory mapped registers when
    -- axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
    -- select byte enables of slave registers while writing.
    -- These registers are cleared when reset (active low) is applied.
    -- Slave register write enable is asserted when valid address and data are available
    -- and the slave is ready to accept the write address and write data.
    slv_reg_wren <= axi_wready and S_AXI_WVALID and axi_awready and S_AXI_AWVALID ;

    process (S_AXI_ACLK)
    variable loc_addr :std_logic_vector(OPT_MEM_ADDR_BITS downto 0); 
    begin
    if rising_edge(S_AXI_ACLK) then 
        if S_AXI_ARESETN = '0' then
        slv_reg <= (others => '0');
        ready_in <= '0';
        else
        loc_addr := axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
        if (slv_reg_wren = '1') then
            case loc_addr is
            when b"00" =>
                -- slave registor
                slv_reg <= S_AXI_WDATA;
                -- data ready in
                ready_in <= '1';
            when others =>
                slv_reg <= slv_reg;
                ready_in <= '0';
            end case;
        end if;
        end if;
    end if;                   
    end process; 

    -- Implement write response logic generation
    -- The write response and response valid signals are asserted by the slave 
    -- when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
    -- This marks the acceptance of address and indicates the status of 
    -- write transaction.

    process (S_AXI_ACLK)
    begin
    if rising_edge(S_AXI_ACLK) then 
        if S_AXI_ARESETN = '0' then
        axi_bvalid  <= '0';
        axi_bresp   <= "00"; --need to work more on the responses
        else
        if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1' and axi_bvalid = '0'  ) then
            axi_bvalid <= '1';
            axi_bresp  <= "00"; 
        elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then   --check if bready is asserted while bvalid is high)
            axi_bvalid <= '0';                                 -- (there is a possibility that bready is always asserted high)
        end if;
        end if;
    end if;                   
    end process; 

    -- Implement axi_arready generation
    -- axi_arready is asserted for one S_AXI_ACLK clock cycle when
    -- S_AXI_ARVALID is asserted. axi_awready is 
    -- de-asserted when reset (active low) is asserted. 
    -- The read address is also latched when S_AXI_ARVALID is 
    -- asserted. axi_araddr is reset to zero on reset assertion.

    process (S_AXI_ACLK)
    begin
    if rising_edge(S_AXI_ACLK) then 
        if S_AXI_ARESETN = '0' then
        axi_arready <= '0';
        axi_araddr  <= (others => '1');
        else
        if (axi_arready = '0' and S_AXI_ARVALID = '1') then
            -- indicates that the slave has acceped the valid read address
            axi_arready <= '1';
            -- Read Address latching 
            axi_araddr  <= S_AXI_ARADDR;           
        else
            axi_arready <= '0';
        end if;
        end if;
    end if;                   
    end process; 

    -- Implement axi_arvalid generation
    -- axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
    -- S_AXI_ARVALID and axi_arready are asserted. The slave registers 
    -- data are available on the axi_rdata bus at this instance. The 
    -- assertion of axi_rvalid marks the validity of read data on the 
    -- bus and axi_rresp indicates the status of read transaction.axi_rvalid 
    -- is deasserted on reset (active low). axi_rresp and axi_rdata are 
    -- cleared to zero on reset (active low).  
    process (S_AXI_ACLK)
    begin
    if rising_edge(S_AXI_ACLK) then
        if S_AXI_ARESETN = '0' then
        axi_rvalid <= '0';
        axi_rresp  <= "00";
        else
        if (axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0') then
            -- Valid read data is available at the read data bus
            axi_rvalid <= '1';
            axi_rresp  <= "00"; -- 'OKAY' response
        elsif (axi_rvalid = '1' and S_AXI_RREADY = '1') then
            -- Read data is accepted by the master
            axi_rvalid <= '0';
        end if;            
        end if;
    end if;
    end process;

    -- Implement memory mapped register select and read logic generation
    -- Slave register read enable is asserted when valid address is available
    -- and the slave is ready to accept the read address.
    slv_reg_rden <= axi_arready and S_AXI_ARVALID and (not axi_rvalid) ;

    process (axi_araddr, S_AXI_ARESETN, slv_reg_rden)
    variable loc_addr :std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
    begin
        -- Address decoding for reading registers
        loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
        case loc_addr is
        when b"00" =>
            reg_data_out <= reg_data_rd;
        when others =>
            reg_data_out <= (others => '0');
        end case;
    end process; 

    -- Output register or memory read data
    process( S_AXI_ACLK ) is
    begin
    if (rising_edge (S_AXI_ACLK)) then
        if ( S_AXI_ARESETN = '0' ) then
        axi_rdata  <= (others => '0');
        else
        if (slv_reg_rden = '1') then
            -- When there is a valid read address (S_AXI_ARVALID) with 
            -- acceptance of read address by the slave (axi_arready), 
            -- output the read dada 
            -- Read address mux
            axi_rdata <= reg_data_out;     -- register read data
        end if;   
        end if;
    end if;
    end process;

    -- IIC module logic
    --
    -- Instantiation of module
    my_iic: i2c_master 
    Generic Map(
        input_clk => input_clk,
        bus_clk   => bus_clk  
    )
    Port Map(
        clk       => s_axi_aclk,
        reset_n   => s_axi_aresetn,
        ena       => ena,
        addr      => addr,
        rw        => rw,
        data_wr   => data_wr,
        busy      => busy,
        data_rd   => data_rd,
        ack_error => ack_error,
        sda       => sda,
        scl       => scl       
    );

    -- IIC logic process
    iic_logic: process(s_axi_aclk)
    variable slv_reg_local : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                reg_data_rd <= (others => '0');
                ena <= '0';
                slv_reg_local := (others => '0');
            else
                if ready_in = '1' then

                    slv_reg_local := slv_reg;
                    ena  <= '1';
                    rw <= slv_reg_local(0);
                    
                    addr <= slv_reg_local(7 downto 1);
                    data_wr <= slv_reg_local(16 downto 8);
                end if;
            end if;
        end if;
    end process iic_logic;

end arch_imp;