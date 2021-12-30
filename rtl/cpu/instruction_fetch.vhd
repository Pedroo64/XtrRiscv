library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity instruction_fecth is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        en_i : in std_logic;
        load_pc_i : in std_logic;
        pc_i : in std_logic_vector(31 downto 0);
        cmd_adr_o : out std_logic_vector(31 downto 0);
        cmd_vld_o : out std_logic; 
        rsp_dat_i : in std_logic_vector(31 downto 0);
        cmd_rdy_i : in std_logic;
        rsp_vld_i : in std_logic;
        pc_o : out std_logic_vector(31 downto 0);
        instr_o : out std_logic_vector(31 downto 0);
        instr_vld_o : out std_logic;
        decode_rdy_i : in std_logic
    );
end entity instruction_fecth;

architecture rtl of instruction_fecth is
    signal pc : unsigned(31 downto 0);
begin
    
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            pc <= (others => '0');
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                pc <= (others => '0');
            else
                if en_i = '1' then
                    if load_pc_i = '1' then
                        pc <= unsigned(pc_i);
                    elsif cmd_rdy_i = '1' and decode_rdy_i = '1' then
                        pc <= pc + 4;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    cmd_adr_o <= std_logic_vector(pc);

    cmd_vld_o <= 
        '1' when en_i = '1' and decode_rdy_i = '1' else 
        '0';
    
    instr_o <= rsp_dat_i;
    instr_vld_o <= 
        '1' when decode_rdy_i = '0' else 
        '1' when decode_rdy_i = '1' and rsp_vld_i = '0' else             
        rsp_vld_i;
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if decode_rdy_i = '1' then
                pc_o <= std_logic_vector(pc);
            end if;
        end if;
    end process;
    
end architecture rtl;