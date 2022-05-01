library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity writeback is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        memory_rd_we_i : in std_logic;
        memory_rd_adr_i : in std_logic_vector(4 downto 0);
        memory_rd_dat_i : in std_logic_vector(31 downto 0);
        execute_rd_we_i : in std_logic;
        execute_rd_adr_i : in std_logic_vector(4 downto 0);
        execute_rd_dat_i : in std_logic_vector(31 downto 0);
        csr_rd_we_i : in std_logic;
        csr_rd_adr_i : in std_logic_vector(4 downto 0);
        csr_rd_dat_i : in std_logic_vector(31 downto 0);
        rd_we_o : out std_logic;
        rd_adr_o : out std_logic_vector(4 downto 0);
        rd_dat_o : out std_logic_vector(31 downto 0);
        execute_ready_o : out std_logic;
        csr_ready_o : out std_logic
    );
end entity writeback;

architecture rtl of writeback is
    
begin
    
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            rd_we_o <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                rd_we_o <= '0';
            else
                rd_we_o <= (memory_rd_we_i or csr_rd_we_i or execute_rd_we_i);
                if memory_rd_we_i = '1' then
                    rd_adr_o <= memory_rd_adr_i;
                    rd_dat_o <= memory_rd_dat_i;
                elsif csr_rd_we_i = '1' then
                    rd_adr_o <= csr_rd_adr_i;
                    rd_dat_o <= csr_rd_dat_i;
                else
                    rd_adr_o <= execute_rd_adr_i;
                    rd_dat_o <= execute_rd_dat_i;
                end if;
            end if;
        end if;
    end process;

    execute_ready_o <= 
        '0' when memory_rd_we_i = '1' else
        '0' when csr_rd_we_i = '1' else
        '1';
    csr_ready_o <= 
        '0' when memory_rd_we_i = '1' else
        '1';
    
end architecture rtl;