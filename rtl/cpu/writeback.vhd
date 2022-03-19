library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity writeback is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        en_i : in std_logic;
        mem_rd_adr_i : in std_logic_vector(4 downto 0);
        mem_rd_we_i : in std_logic;
        mem_rd_dat_i : in std_logic_vector(31 downto 0);
        ex_load_pc_i : in std_logic;
        ex_pc_i : in std_logic_vector(31 downto 0);
        ex_rd_adr_i : in std_logic_vector(4 downto 0);
        ex_rd_we_i : in std_logic;
        ex_rd_dat_i : in std_logic_vector(31 downto 0);
        csr_rd_adr_i : in std_logic_vector(4 downto 0);
        csr_rd_we_i : in std_logic;
        csr_rd_dat_i : in std_logic_vector(31 downto 0);
        rd_adr_o : out std_logic_vector(4 downto 0);
        rd_we_o : out std_logic;
        rd_dat_o : out std_logic_vector(31 downto 0);
        load_pc_o : out std_logic;
        pc_o : out std_logic_vector(31 downto 0);
        csr_rdy_o : out std_logic;
        ex_rdy_o : out std_logic
    );
end entity writeback;

architecture rtl of writeback is
    signal ex_rdy, csr_rdy : std_logic;
begin
    
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            rd_we_o <= '0';
            load_pc_o <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                rd_we_o <= '0';
                load_pc_o <= '0';
            else
                if en_i = '1' then
                    load_pc_o <= '0';
                    pc_o <= ex_pc_i;
                    if mem_rd_we_i = '1' then
                        rd_adr_o <= mem_rd_adr_i;
                        rd_we_o <= '1';
                        rd_dat_o <= mem_rd_dat_i;
                    elsif csr_rd_we_i = '1' then
                        rd_adr_o <= csr_rd_adr_i;
                        rd_we_o <= '1';
                        rd_dat_o <= csr_rd_dat_i;
                    else
                        rd_adr_o <= ex_rd_adr_i;
                        rd_we_o <= ex_rd_we_i;
                        rd_dat_o <= ex_rd_dat_i;
                        load_pc_o <= ex_load_pc_i;
                    end if;
                end if;
            end if;
        end if;
    end process;
    ex_rdy <= 
        '0' when mem_rd_we_i = '1' else 
        '0' when csr_rd_we_i = '1' else
        en_i;
    csr_rdy <= 
        '0' when mem_rd_we_i = '1' else
        en_i;
    
    ex_rdy_o <= ex_rdy;
    csr_rdy_o <= csr_rdy;
end architecture rtl;