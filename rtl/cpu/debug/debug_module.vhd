library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.debug_module_pkg.all;
use work.rv32i_pkg.all;
use work.csr_def.all;

entity debug_module is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        debug_mode_i : in std_logic;
        debug_halt_o : out std_logic;
        debug_reset_o : out std_logic;
        debug_adr_i : in std_logic_vector(7 downto 0);
        debug_vld_i : in std_logic;
        debug_we_i : in std_logic;
        debug_dat_i : in std_logic_vector(31 downto 0);
        debug_dat_o : out std_logic_vector(31 downto 0);
        debug_vld_o : out std_logic;
        debug_rdy_o : out std_logic;
        instr_cmd_vld_i : in std_logic;
        instr_cmd_rdy_o : out std_logic;
        instr_rsp_dat_o : out std_logic_vector(31 downto 0);
        instr_rsp_vld_o : out std_logic;
        csr_data0_dat_o : out std_logic_vector(31 downto 0);
        csr_data0_vld_o : out std_logic;
        csr_data0_dat_i : in std_logic_vector(31 downto 0)
    );
end entity debug_module;

architecture rtl of debug_module is
    type execute_st is (st_idle, st_check, st_transfer, st_progbuf, st_ebreak, st_error);
    signal current_st : execute_st;
    signal dm_regs : debug_module_registers_t;
    signal dm_regs_command_control_alias : access_register_command_t;
    signal hart_reset, hart_halted : std_logic;
begin
    csr_data0_dat_o <= debug_dat_i;
    csr_data0_vld_o <= 
        '1' when unsigned(debug_adr_i) = C_DATA0 and (debug_vld_i and debug_we_i) = '1' else
        '0';

    dm_regs.data0 <= csr_data0_dat_i;

    dm_regs.dmcontrol.hartreset <= '0'; -- Unsupported
    dm_regs.dmcontrol.hasel <= '0'; -- Unsupported
    dm_regs.dmcontrol.hartsello <= (others => '0'); -- Unsupported
    dm_regs.dmcontrol.hartselhi <= (others => '0'); -- Unsupported
    dm_regs.dmcontrol.setkeepalive <= '0'; -- Unsupported
    dm_regs.dmcontrol.clrkeepalive <= '0'; -- Unsupported
    dm_regs.dmcontrol.setresethaltreq <= '0'; -- Unsupported
    dm_regs.dmcontrol.clrresethaltreq <= '0'; -- Unsupported

    dm_regs.dmstatus.ndmresetpending <= dm_regs.dmcontrol.ndmreset;
    dm_regs.dmstatus.stickyunavail <= '0';
    dm_regs.dmstatus.impebreak <= '1'; -- ebreak at the end of progbuf
    dm_regs.dmstatus.allhavereset <= hart_reset;
    dm_regs.dmstatus.anyhavereset <= hart_reset;
    dm_regs.dmstatus.allresumeack <= not hart_reset;
    dm_regs.dmstatus.anyresumeack <= not hart_reset;
    dm_regs.dmstatus.allnonexistent <= '0';
    dm_regs.dmstatus.anynonexistent <= '0';
    dm_regs.dmstatus.allunavail <= hart_reset;
    dm_regs.dmstatus.anyunavail <= hart_reset;
    dm_regs.dmstatus.allrunning <= not hart_halted;
    dm_regs.dmstatus.anyrunning <= not hart_halted;
    dm_regs.dmstatus.allhalted <= hart_halted;
    dm_regs.dmstatus.anyhalted <= hart_halted;
    dm_regs.dmstatus.authenticated <= '1';
    dm_regs.dmstatus.authbusy <= '0';
    dm_regs.dmstatus.hasresethaltreq <= '0';
    dm_regs.dmstatus.confstrptrvalid <= '0';
    dm_regs.dmstatus.version <= x"3";

    dm_regs.abstractcs.progbufsize <= std_logic_vector(to_unsigned(1, dm_regs.abstractcs.progbufsize'length));
    dm_regs.abstractcs.busy <= '1' when current_st /= st_idle else '0';
    dm_regs.abstractcs.relaxedpriv <= '0'; -- Unsupported 
    dm_regs.abstractcs.datacount <= std_logic_vector(to_unsigned(1, dm_regs.abstractcs.datacount'length));

    dm_regs.hartinfo.nscratch <= std_logic_vector(to_unsigned(0, dm_regs.hartinfo.nscratch'length));
    dm_regs.hartinfo.dataaccess <= '0';
    dm_regs.hartinfo.datasize <= std_logic_vector(to_unsigned(1, dm_regs.hartinfo.datasize'length));
    dm_regs.hartinfo.dataaddr <= CSR_DM_DATA0;

    -- map of debug_module_registers_t.command_t.control
    dm_regs_command_control_alias.aarsize <= dm_regs.command.control(22 downto 20);
    dm_regs_command_control_alias.aarpostincrement <= dm_regs.command.control(19);
    dm_regs_command_control_alias.postexec <= dm_regs.command.control(18);
    dm_regs_command_control_alias.transfer <= dm_regs.command.control(17);
    dm_regs_command_control_alias.write <= dm_regs.command.control(16);
    dm_regs_command_control_alias.regno <= dm_regs.command.control(15 downto 0);

    p_write: process(clk_i, arst_i)
    begin
        if arst_i = '1' then
            
        elsif rising_edge(clk_i) then
            if debug_vld_i = '1' and debug_we_i = '1' then
                case to_integer(unsigned(debug_adr_i)) is
                    when C_DMCONTROL =>
                        dm_regs.dmcontrol.haltreq <= debug_dat_i(31);
                        dm_regs.dmcontrol.resumereq <= debug_dat_i(30);
                        dm_regs.dmcontrol.ackhavereset <= debug_dat_i(28);
                        dm_regs.dmcontrol.ackunavail <= debug_dat_i(27);
                        dm_regs.dmcontrol.ndmreset <= debug_dat_i(1);
                        dm_regs.dmcontrol.dmactive <= debug_dat_i(0);
                    when C_ABSTRACTCS =>
                        dm_regs.abstractcs.cmderr <= (others => '0');
                    when C_COMMAND =>
                        dm_regs.command.cmdtype <= debug_dat_i(31 downto 24);
                        dm_regs.command.control <= debug_dat_i(23 downto 0);
                    when C_PROGBUF0 =>
                        dm_regs.progbuf0 <= debug_dat_i;
                    when others =>
                end case;
            end if;
        end if;
    end process p_write;

    p_read : process(clk_i)
    begin
        if rising_edge(clk_i) then
            debug_dat_o <= (others => '0');
            case to_integer(unsigned(debug_adr_i)) is
                when C_DATA0 =>
                    debug_dat_o <= dm_regs.data0;
                when C_DMCONTROL =>
                    debug_dat_o(29) <= dm_regs.dmcontrol.hartreset;
                    debug_dat_o(26) <= dm_regs.dmcontrol.hasel;
                    debug_dat_o(25 downto 16) <= dm_regs.dmcontrol.hartsello;
                    debug_dat_o(15 downto 6) <= dm_regs.dmcontrol.hartselhi;
                    debug_dat_o(1) <= dm_regs.dmcontrol.ndmreset;
                    debug_dat_o(0) <= dm_regs.dmcontrol.dmactive;
                when C_DMSTATUS =>
                    debug_dat_o(24) <= dm_regs.dmstatus.ndmresetpending;
                    debug_dat_o(23) <= dm_regs.dmstatus.stickyunavail;
                    debug_dat_o(22) <= dm_regs.dmstatus.impebreak;
                    debug_dat_o(19) <= dm_regs.dmstatus.allhavereset;
                    debug_dat_o(18) <= dm_regs.dmstatus.anyhavereset;
                    debug_dat_o(17) <= dm_regs.dmstatus.allresumeack;
                    debug_dat_o(16) <= dm_regs.dmstatus.anyresumeack;
                    debug_dat_o(15) <= dm_regs.dmstatus.allnonexistent;
                    debug_dat_o(14) <= dm_regs.dmstatus.anynonexistent;
                    debug_dat_o(13) <= dm_regs.dmstatus.allunavail;
                    debug_dat_o(12) <= dm_regs.dmstatus.anyunavail;
                    debug_dat_o(11) <= dm_regs.dmstatus.allrunning;
                    debug_dat_o(10) <= dm_regs.dmstatus.anyrunning;
                    debug_dat_o(9) <= dm_regs.dmstatus.allhalted;
                    debug_dat_o(8) <= dm_regs.dmstatus.anyhalted;
                    debug_dat_o(7) <= dm_regs.dmstatus.authenticated;
                    debug_dat_o(6) <= dm_regs.dmstatus.authbusy;
                    debug_dat_o(5) <= dm_regs.dmstatus.hasresethaltreq;
                    debug_dat_o(4) <= dm_regs.dmstatus.confstrptrvalid;
                    debug_dat_o(3 downto 0) <= dm_regs.dmstatus.version;
                when C_HARTINFO =>
                    debug_dat_o(23 downto 20) <= dm_regs.hartinfo.nscratch;
                    debug_dat_o(16) <= dm_regs.hartinfo.dataaccess;
                    debug_dat_o(15 downto 12) <= dm_regs.hartinfo.datasize;
                    debug_dat_o(11 downto 0) <= dm_regs.hartinfo.dataaddr;
                when C_ABSTRACTCS =>
                    debug_dat_o(28 downto 24) <= dm_regs.abstractcs.progbufsize;
                    debug_dat_o(12) <= dm_regs.abstractcs.busy;
                    debug_dat_o(11) <= dm_regs.abstractcs.relaxedpriv;
                    debug_dat_o(10 downto 8) <= dm_regs.abstractcs.cmderr;
                    debug_dat_o(3 downto 0) <= dm_regs.abstractcs.datacount;
                when C_PROGBUF0 => 
                    debug_dat_o <= dm_regs.progbuf0;
                when others =>
                    
            
            end case;
        end if;
    end process p_read;
    
    hart_reset <= 
        '1' when dm_regs.dmcontrol.dmactive = '1' and dm_regs.dmcontrol.ndmreset = '1' else
        '0';

    debug_halt_o <= 
        '1' when dm_regs.dmcontrol.dmactive = '1' and dm_regs.dmcontrol.haltreq = '1' else
        '0';

    debug_reset_o <= hart_reset;

    hart_halted <= debug_mode_i;
    
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            current_st <= st_idle;
        elsif rising_edge(clk_i) then
            case current_st is
                when st_idle =>
                    if debug_vld_i = '1' and debug_we_i = '1' and unsigned(debug_adr_i) = C_COMMAND then
                        current_st <= st_check;
                    end if;
                when st_check =>
                    if unsigned(dm_regs.command.cmdtype) = 0 and unsigned(dm_regs_command_control_alias.aarsize) = 2 then
                        if dm_regs_command_control_alias.transfer = '1' then
                            current_st <= st_transfer;
                        elsif dm_regs_command_control_alias.postexec = '1' then
                            current_st <= st_progbuf;
                        else
                            current_st <= st_error;
                        end if;
                    else
                        current_st <= st_error;
                    end if;
                when st_transfer =>
                    if instr_cmd_vld_i = '1' then
                        if dm_regs_command_control_alias.postexec = '1' then
                            current_st <= st_progbuf;
                        else
                            current_st <= st_ebreak;
                        end if;
                    end if;
                when st_progbuf =>
                    if instr_cmd_vld_i = '1' then
                        current_st <= st_ebreak;
                    end if;
                when st_ebreak =>
                    if instr_cmd_vld_i = '1' then
                        current_st <= st_idle;
                    end if;
                when st_error =>
                    current_st <= st_idle;
                when others =>
                    current_st <= st_idle;
            end case;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            instr_rsp_vld_o <= '0';
            case current_st is
                when st_transfer =>
                    instr_rsp_vld_o <= instr_cmd_vld_i;
                    instr_rsp_dat_o(6 downto 0) <= RV32I_OP_SYS;
                    instr_rsp_dat_o(31 downto 20) <= CSR_DM_DATA0;
                    if dm_regs_command_control_alias.write = '1' then
                        instr_rsp_dat_o(19 downto 15) <= (others => '0');
                        instr_rsp_dat_o(14 downto 12) <= RV32I_FN3_CSRRC;
                        instr_rsp_dat_o(11 downto 7) <= dm_regs_command_control_alias.regno(4 downto 0);
                    else
                        instr_rsp_dat_o(19 downto 15) <= dm_regs_command_control_alias.regno(4 downto 0);
                        instr_rsp_dat_o(14 downto 12) <= RV32I_FN3_CSRRW;
                        instr_rsp_dat_o(11 downto 7) <= (others => '0');
                    end if;
                when st_progbuf =>
                    instr_rsp_vld_o <= instr_cmd_vld_i;
                    instr_rsp_dat_o <= dm_regs.progbuf0;
                when st_ebreak =>
                    instr_rsp_vld_o <= instr_cmd_vld_i;
                    instr_rsp_dat_o(6 downto 0) <= RV32I_OP_SYS;
                    instr_rsp_dat_o(11 downto 7) <= (others => '0');
                    instr_rsp_dat_o(14 downto 12) <= (others => '0');
                    instr_rsp_dat_o(19 downto 15) <= (others => '0');
                    instr_rsp_dat_o(31 downto 20) <= x"001";
                when others =>
            end case;
        end if;
    end process;

    instr_cmd_rdy_o <= 
        '1' when current_st = st_transfer or current_st = st_progbuf or current_st = st_ebreak else
        '0';
end architecture rtl;