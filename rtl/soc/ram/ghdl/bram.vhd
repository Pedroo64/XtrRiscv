library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use STD.TEXTIO.all;
use ieee.std_logic_textio.all;

entity bram is
    generic (
        C_DEPTH : integer := 256;
        C_ADDR_A_WIDTH : integer := 8;
        C_DATA_A_WIDTH : integer := 32;
        C_BYTE_A_WIDTH : integer := 8;
        C_ADDR_B_WIDTH : integer := 8;
        C_DATA_B_WIDTH : integer := 32;
        C_BYTE_B_WIDTH : integer := 8;
        C_INIT_FILE : string := "none"
    );
    port (
        arst_i : in std_logic := '0';
        clk_i : in std_logic;
        srst_i : in std_logic := '0';
        addr_a_i : in std_logic_vector(C_ADDR_A_WIDTH - 1 downto 0);
        en_a_i : in std_logic;
        we_a_i : in std_logic;
        be_a_i : in std_logic_vector((C_DATA_A_WIDTH / C_BYTE_A_WIDTH) - 1 downto 0);
        dat_a_i : in std_logic_vector(C_DATA_A_WIDTH - 1 downto 0);
        dat_a_o : out std_logic_vector(C_DATA_A_WIDTH - 1 downto 0);
        addr_b_i : in std_logic_vector(C_ADDR_B_WIDTH - 1 downto 0);
        en_b_i : in std_logic;
        we_b_i : in std_logic;
        be_b_i : in std_logic_vector((C_DATA_B_WIDTH / C_BYTE_B_WIDTH) - 1 downto 0);
        dat_b_i : in std_logic_vector(C_DATA_B_WIDTH - 1 downto 0);
        dat_b_o : out std_logic_vector(C_DATA_B_WIDTH - 1 downto 0)
    );
end entity bram;

architecture rtl of bram is
    constant C_NB_COL_A : integer := (C_DATA_A_WIDTH / C_BYTE_A_WIDTH);
    constant C_NB_COL_B : integer := (C_DATA_B_WIDTH / C_BYTE_B_WIDTH);
    type ram_t is array (0 to C_DEPTH - 1) of std_logic_vector(C_DATA_A_WIDTH - 1 downto 0);
begin
    
    process (clk_i, arst_i)
        variable ram : ram_t;
        procedure ocram_readmemfile(file_name : string) is
            file file_handle : text;
            variable current_line : line;
            variable temp_word : std_logic_vector(31 downto 0);
        begin
            if file_name /= "none" then
                file_open(file_handle, file_name,  read_mode);
            end if;
            for i in 0 to C_DEPTH - 1 loop
                if file_name /= "none" and not endfile(file_handle) then
                    readline(file_handle, current_line);
                    hread(current_line, temp_word);
                else
                    temp_word := (others => '0');
                end if;
                ram(i) := temp_word;
            end loop;
            if file_name /= "none" then
                file_close(file_handle);
            end if;
        end procedure;
    begin
        if arst_i = '1' then
            ocram_readmemfile(C_INIT_FILE);
        elsif rising_edge(clk_i) then
            if en_a_i = '1' then
                dat_a_o <= ram(to_integer(unsigned(addr_a_i)));
                if we_a_i = '1' then
                    for i in 0 to C_NB_COL_A - 1 loop
                        if be_a_i(i) = '1' then
                            ram(to_integer(unsigned(addr_a_i)))(i*8 + 7 downto i*8) := dat_a_i(i*8 + 7 downto i*8);
                        end if;
                    end loop;
                end if;
            end if;
            if en_b_i = '1' then
                dat_b_o <= ram(to_integer(unsigned(addr_b_i)));
                if we_b_i = '1' then
                    for i in 0 to C_NB_COL_A - 1 loop
                        if be_b_i(i) = '1' then
                            ram(to_integer(unsigned(addr_b_i)))(i*8 + 7 downto i*8) := dat_b_i(i*8 + 7 downto i*8);
                        end if;
                    end loop;
                end if;
            end if;
        end if;
    end process;
    
end architecture rtl;