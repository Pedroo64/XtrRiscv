library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use STD.TEXTIO.all;
use ieee.std_logic_textio.all;

entity bram is
    generic (
        G_DEPTH : integer := 256;
        G_ADDR_WIDTH : integer := 8;
        G_DATA_WIDTH : integer := 32;
        G_BYTE_WIDTH : integer := 8;
        G_INIT_FILE : string := "none"
    );
    port (
        clk_i : in std_logic;
        adr_i : in std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
        en_i : in std_logic;
        we_i : in std_logic;
        be_i : in std_logic_vector((G_DATA_WIDTH / G_BYTE_WIDTH) - 1 downto 0);
        dat_i : in std_logic_vector(G_DATA_WIDTH - 1 downto 0);
        dat_o : out std_logic_vector(G_DATA_WIDTH - 1 downto 0)
    );
end entity bram;

architecture rtl of bram is
    constant C_NB_COL : integer := (G_DATA_WIDTH / G_BYTE_WIDTH);
    type ram_t is array (0 to G_DEPTH - 1) of std_logic_vector(G_DATA_WIDTH - 1 downto 0);
    shared variable ram : ram_t;
begin

    process
        file     f            : TEXT;
        variable current_line : LINE;
        variable temp_word    : STD_LOGIC_VECTOR(31 downto 0);
    begin
        if G_INIT_FILE /= "none" then
            file_open(f, G_INIT_FILE,  read_mode);
            for i in 0 to ram'length - 1 loop
                exit when endfile(f);
                readline(f, current_line);
                hread(current_line, temp_word);
                ram(i) := temp_word;
            end loop;
            file_close(f);
        end if;
        wait;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            dat_o <= (others => '-');
            if en_i = '1' then
                if we_i = '1' then
                    for i in be_i'range loop
                        if be_i(i) = '1' then
                            ram(to_integer(unsigned(adr_i)))((i+1)*G_BYTE_WIDTH - 1 downto i*G_BYTE_WIDTH) := dat_i((i+1)*G_BYTE_WIDTH - 1 downto i*G_BYTE_WIDTH);
                        end if;
                    end loop;
                else
                    dat_o <= ram(to_integer(unsigned(adr_i)));
                end if;
            end if;
        end if;
    end process;

end architecture rtl;
