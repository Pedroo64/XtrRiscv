library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity data_handshake is
    generic (
        G_DATA_WIDTH : integer := 32
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        command_ready_o : out std_logic;
        command_data_i : in std_logic_vector(G_DATA_WIDTH - 1 downto 0);
        command_valid_i : in std_logic;
        response_data_o : out std_logic_vector(G_DATA_WIDTH - 1 downto 0);
        response_valid_o : out std_logic;
        response_ready_i : in std_logic
    );
end entity data_handshake;

architecture rtl of data_handshake is
    
begin
    
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if command_valid_i = '1' and response_ready_i = '1' then
                response_data_o <= command_data_i;
            end if;
        end if;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            response_valid_o <= '0';
        elsif rising_edge(clk_i) then
            if command_valid_i = '1' and response_ready_i = '1' then -- SET
                response_valid_o <= '1';
            elsif response_ready_i = '1' then -- RESET
                response_valid_o <= '0';
            end if;
        end if;
    end process;

    command_ready_o <= response_ready_i;

end architecture rtl;