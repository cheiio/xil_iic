library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity FIFO_MOD is
    generic(data_width: integer := 8;
            fifo_depth : integer := 4);
    port(   clk, resetn: in std_logic;
            push, pull : in std_logic;
            data_qtd : in std_logic_vector(2 downto 0);
            data_in : in std_logic_vector(data_width*fifo_depth-1 downto 0);
            data_out : out std_logic_vector(data_width-1 downto 0);
            empty, full : out std_logic);
end entity FIFO_MOD;

architecture RTL of FIFO_MOD is
    -- FIFO signals
    signal fifo_cont : integer range 0 to 4; -- fifo cont
    type fifo_type is array (0 to fifo_depth-1) of std_logic_vector(data_width-1 downto 0);
    signal fifo_reg : fifo_type;
begin
    -- FIFO logic
    fifo_logic: process(clk)
    variable s : std_logic_vector(1 downto 0);
    variable full_loc, empty_loc : std_logic;
    
    begin
        if rising_edge(clk) then
        if resetn = '0' then
            fifo_reg <= (others => (others => '0'));
            data_qtd <= (others => '0');
            data_out <= (others => '0');
            fifo_cont <= 0;
            full_loc := '0';
            empty_loc := '0';
        else
            
            if fifo_cont = 0 then
                empty_loc := '1';
            else
                empty_loc := '0';
            end if;
            if fifo_cont = fifo_depth then
                full_loc := '1';
            else
                full_loc := '0';
            end if;
            
            s := pull & push;
            case s is
            when "01" => -- push
                if full_loc = '0' then
                    for I in 0 to fifo_depth-1 loop
                        fifo_reg(I) <= data_in((I+1)*data_width-1 downto data_width*I);
                    end loop;
                    fifo_cont <= conv_integer(unsigned(data_qtd));
                end if;
            when "10" => -- pull
                if empty_loc = '0' then
                    data_out <= fifo_reg(fifo_cont-1);
                    fifo_cont <= fifo_cont-1;
                end if;
            when others =>
                fifo_reg <= fifo_reg;
            end case;
            
            full <= full_loc;
            empty <= empty_loc;
        end if;
        end if;
    end process fifo_logic;
end architecture;