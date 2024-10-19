library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

use work.xtr_def.all;

entity xtr_ram is
    generic (
        G_RAM_SIZE : integer := 8192;
        G_INIT_FILE : string := "none"
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        instr_cmd_i : in xtr_cmd_t;
        instr_rsp_o : out xtr_rsp_t;
        dat_cmd_i : in xtr_cmd_t;
        dat_rsp_o : out xtr_rsp_t
    );
end entity xtr_ram;

architecture rtl of xtr_ram is
    constant C_ADDR_DEPTH : integer := integer(ceil(log2(real(G_RAM_SIZE / 4))));
    signal adr : std_logic_vector(C_ADDR_DEPTH-1 downto 0);
    signal wdat, rdat : std_logic_vector(31 downto 0);
    signal be : std_logic_vector(3 downto 0);
    signal en, we : std_logic;
    signal sel, sel_q, ack, ack_q : std_logic;
begin

    sel <= dat_cmd_i.vld;
    ack <= (instr_cmd_i.vld and not instr_cmd_i.we and not sel)
        or (  dat_cmd_i.vld and not   dat_cmd_i.we and     sel)
        ;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            sel_q <= sel;
            ack_q <= ack;
        end if;
    end process;

    adr <= (instr_cmd_i.adr(C_ADDR_DEPTH+1 downto 2) and (C_ADDR_DEPTH+1 downto 2 => not sel))
        or (  dat_cmd_i.adr(C_ADDR_DEPTH+1 downto 2) and (C_ADDR_DEPTH+1 downto 2 =>     sel))
        ;

    wdat <= (instr_cmd_i.dat and (31 downto 0 => not sel))
         or (  dat_cmd_i.dat and (31 downto 0 =>     sel))
         ;

    be   <= (instr_cmd_i.sel                          and (3 downto 0 => not sel))
         or (  dat_cmd_i.sel                          and (3 downto 0 =>     sel))
         ;

    en   <= instr_cmd_i.vld or dat_cmd_i.vld;

    we   <= (instr_cmd_i.we and not sel)
         or (  dat_cmd_i.we and     sel)
         ;

    u_bram : entity work.bram
        generic map (
            G_DEPTH => C_RAM_SIZE / 4,
            G_ADDR_WIDTH => C_ADDR_DEPTH,
            G_DATA_WIDTH => 32,
            G_BYTE_WIDTH => 8,
            G_INIT_FILE => C_INIT_FILE
        )
        port map (
            clk_i => clk_i,
            adr_i => adr,
            en_i => en,
            we_i => we,
            be_i => be,
            dat_i => wdat,
            dat_o => rdat
        );

    instr_rsp_o.rdy <= not sel;
    instr_rsp_o.dat <= rdat;
    instr_rsp_o.vld <= ack_q and not sel_q;

    dat_rsp_o.rdy   <= sel;
    dat_rsp_o.dat   <= rdat;
    dat_rsp_o.vld   <= ack_q and sel_q;

end architecture rtl;