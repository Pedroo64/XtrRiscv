library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.dtm_pkg.all;

entity jtag_dtm is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        tck_i : in std_logic;
        tdi_i : in std_logic;
        tdo_o : out std_logic;
        tms_i : in std_logic;
        cmd_adr_o : out std_logic_vector(7 downto 0);
        cmd_dat_o : out std_logic_vector(31 downto 0);
        cmd_vld_o : out std_logic;
        cmd_we_o : out std_logic;
        rsp_rdy_i : in std_logic;
        rsp_vld_i : in std_logic;
        rsp_dat_i : in std_logic_vector(31 downto 0)
    );
end entity jtag_dtm;

architecture rtl of jtag_dtm is
    type tap_state_t is (
        TAP_RESET,
        TAP_IDLE, 
        TAP_DRSELECT, 
        TAP_DRCAPTURE, 
        TAP_DRSHIFT, 
        TAP_DREXIT1, 
        TAP_DRPAUSE, 
        TAP_DREXIT2, 
        TAP_DRUPDATE, 
        TAP_IRSELECT, 
        TAP_IRCAPTURE, 
        TAP_IRSHIFT, 
        TAP_IREXIT1, 
        TAP_IRPAUSE, 
        TAP_IREXIT2, 
        TAP_IRUPDATE 
        );
    signal tap_current_st : tap_state_t;
    signal tck, tdi, tdo, tms : std_logic;
    signal d_tck, tck_re, tck_fe : std_logic;
    signal instr_reg : unsigned(4 downto 0);
    signal idcode : std_logic_vector(31 downto 0);
    signal dtmcs : dtmcs_t;
    signal dmi : dmi_t;
    signal ir_shift : unsigned(4 downto 0);
    signal dr_shift32 : std_logic_vector(31 downto 0);
    signal dr_shift42 : std_logic_vector(41 downto 0);
    signal dr_bypass : std_logic;
    signal cmd_vld : std_logic;
begin
    idcode(31 downto 28) <= x"C";
    idcode(27 downto 12) <= x"AFE0";
    idcode(11 downto 1) <= (others => '0');
    idcode(0) <= '1';

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            tck <= tck_i;
            tdi <= tdi_i;
            tms <= tms_i;
            d_tck <= tck;
        end if;
    end process;

    tck_re <= '1' when tck = '1' and d_tck = '0' else '0';
    tck_fe <= '1' when tck = '0' and d_tck = '1' else '0';
    
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            tap_current_st <= TAP_RESET;
        elsif rising_edge(clk_i) then
            if tck_re = '1' then
                case tap_current_st is
                    when TAP_RESET => if tms = '0' then tap_current_st <= TAP_IDLE; end if;
                    when TAP_IDLE => if tms = '1' then tap_current_st <= TAP_DRSELECT; end if;
                    when TAP_DRSELECT => if tms = '1' then tap_current_st <= TAP_IRSELECT; else tap_current_st <= TAP_DRCAPTURE; end if;
                    when TAP_DRCAPTURE => if tms = '1' then tap_current_st <= TAP_DREXIT1; else tap_current_st <= TAP_DRSHIFT; end if;
                    when TAP_DRSHIFT => if tms = '1' then tap_current_st <= TAP_DREXIT1; end if;
                    when TAP_DREXIT1 => if tms = '1' then tap_current_st <= TAP_DRUPDATE; else tap_current_st <= TAP_DRPAUSE; end if;
                    when TAP_DRPAUSE => if tms = '1' then tap_current_st <= TAP_DREXIT2; end if;
                    when TAP_DREXIT2 => if tms = '1' then tap_current_st <= TAP_DRUPDATE; else tap_current_st <= TAP_DRSHIFT; end if;
                    when TAP_DRUPDATE => if tms = '1' then tap_current_st <= TAP_DRSELECT; else tap_current_st <= TAP_IDLE; end if;
                    when TAP_IRSELECT => if tms = '1' then tap_current_st <= TAP_RESET; else tap_current_st <= TAP_IRCAPTURE; end if;
                    when TAP_IRCAPTURE => if tms = '1' then tap_current_st <= TAP_IREXIT1; else tap_current_st <= TAP_IRSHIFT; end if;
                    when TAP_IRSHIFT => if tms = '1' then tap_current_st <= TAP_IREXIT1; end if;
                    when TAP_IREXIT1 => if tms = '1' then tap_current_st <= TAP_IRUPDATE; else tap_current_st <= TAP_IRPAUSE; end if;
                    when TAP_IRPAUSE => if tms = '1' then tap_current_st <= TAP_IREXIT2; end if;
                    when TAP_IREXIT2 => if tms = '1' then tap_current_st <= TAP_IRUPDATE; else tap_current_st <= TAP_IRSHIFT; end if;
                    when TAP_IRUPDATE => if tms = '1' then tap_current_st <= TAP_DRSELECT; else tap_current_st <= TAP_IDLE; end if;
                    when others =>
                end case;
            end if;
        end if;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            ir_shift <= (others => '-');
            instr_reg <= '0' & x"1";
            dr_shift32 <= (others => '-');
            dr_shift42 <= (others => '-');
            dr_bypass <= '0';
        elsif rising_edge(clk_i) then
            if tap_current_st = TAP_RESET then
                instr_reg <= '0' & x"1";
            elsif tap_current_st = TAP_IRUPDATE then
                instr_reg <= ir_shift;
            end if;
            if tap_current_st = TAP_IRCAPTURE then
                ir_shift <= instr_reg;
            elsif tap_current_st = TAP_IRSHIFT and tck_re = '1' then
                ir_shift <= tdi & ir_shift(ir_shift'left downto 1);
            end if;
            if tap_current_st = TAP_DRCAPTURE then
                case to_integer(instr_reg) is
                    when 16#01# =>
                        dr_shift32 <= idcode;
                    when 16#10# =>
                        dr_shift32 <= get_dtmcs(dtmcs);
                    when 16#11# =>
                        dr_shift42 <= get_dmi(dmi);
                    when others =>
                        dr_bypass <= '0';
                end case;
            elsif tap_current_st = TAP_DRSHIFT and tck_re = '1' then
                case to_integer(instr_reg) is
                    when 16#01# | 16#10# =>
                        dr_shift32 <= tdi & dr_shift32(dr_shift32'left downto 1);
                    when 16#11# =>
                        dr_shift42 <= tdi & dr_shift42(dr_shift42'left downto 1);
                    when others =>
                        dr_bypass <= tdi;
                end case;
            end if;

        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if tck_fe = '1' then
                if tap_current_st = TAP_IRSHIFT then
                    tdo <= ir_shift(0);
                else
                    case to_integer(instr_reg) is
                        when 16#01# | 16#10# =>
                            tdo <= dr_shift32(0);
                        when 16#11# =>
                            tdo <= dr_shift42(0);
                        when others =>
                            tdo <= dr_bypass;
                    end case;
                end if;
            end if;
        end if;
    end process;

    tdo_o <= tdo when tap_current_st = TAP_DRSHIFT or tap_current_st = TAP_IRSHIFT else 'Z';

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            dmi.address <= (others => '0');
            dmi.data <= (others => '0');
            dmi.op <= (others => '0');
            dtmcs.dmihardreset <= '1';
            dtmcs.dmireset <= '1';
        elsif rising_edge(clk_i) then
            dtmcs.dmihardreset <= '0';
            dtmcs.dmireset <= '0';
            if tap_current_st = TAP_DRUPDATE then
                case to_integer(instr_reg) is
                    when 16#10# =>
                        dtmcs.dmihardreset <= dr_shift32(17);
                        dtmcs.dmireset <= dr_shift32(16);
                    when 16#11# =>
                        dmi.address <= dr_shift42(41 downto 34);
                        dmi.data <= dr_shift42(33 downto 2);
                        dmi.op <= dr_shift42(1 downto 0);
                    when others =>
                end case;
            elsif rsp_vld_i = '1' then
                dmi.data <= rsp_dat_i;
            end if;
            if dtmcs.dmireset = '1' then
                dmi.op <= (others => '0');
            elsif cmd_vld = '1' then
                if rsp_rdy_i = '1' then
                    dmi.op <= (others => '0');
                else
                    dmi.op <= (others => '1');
                end if;
            end if;
        end if;
    end process;


    dtmcs.idle <= (others => '0');
    dtmcs.dmistat <= (others => '0');
    dtmcs.abits <= std_logic_vector(to_unsigned(8, 6));
    dtmcs.version <= std_logic_vector(to_unsigned(1, 4));

    cmd_adr_o <= dmi.address;
    cmd_dat_o <= dmi.data;
    cmd_we_o <= 
        '1' when unsigned(dmi.op) = 2 else
        '0';
    cmd_vld <= 
        '1' when (unsigned(dmi.op) = 2 or unsigned(dmi.op) = 1) and instr_reg = 16#11# and tck_re = '1' else
        '0';

    cmd_vld_o <= cmd_vld;
end architecture rtl;