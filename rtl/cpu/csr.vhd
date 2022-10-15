library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.csr_def.all;

entity csr is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        valid_i : in std_logic;
        rd_adr_i : in std_logic_vector(4 downto 0);
        address_i : in std_logic_vector(11 downto 0);
        data_i : in std_logic_vector(31 downto 0);
        funct3_i : in std_logic_vector(2 downto 0);
        valid_o : out std_logic;
        rd_adr_o : out std_logic_vector(4 downto 0);
        rd_dat_o : out std_logic_vector(31 downto 0);
        rd_we_o : out std_logic;
        ready_i : in std_logic;
        ready_o : out std_logic;
        exception_pc_i : in std_logic_vector(31 downto 0);
        exception_taken_i : in std_logic;
        exception_exit_i : in std_logic;
        ecall_i : in std_logic;
        ebreak_i : in std_logic;
        cause_external_irq_i : in std_logic;
        cause_timer_irq_i : in std_logic;
        mstatus_o : out std_logic_vector(31 downto 0);
        mie_o : out std_logic_vector(31 downto 0);
        mtvec_o : out std_logic_vector(31 downto 0);
        mepc_o : out std_logic_vector(31 downto 0);
        dpc_o : out std_logic_vector(31 downto 0);
        cause_debug_irq_i : in std_logic;
        dm_halt_i : in std_logic;
        dm_data0_dat_i : in std_logic_vector(31 downto 0);
        dm_data0_vld_i : in std_logic;
        dm_data0_dat_o : out std_logic_vector(31 downto 0);
        dcsr_o : out std_logic_vector(31 downto 0)
    );
end entity csr;

architecture rtl of csr is
    function write_csr (csr_dat : std_logic_vector(31 downto 0); current_csr : std_logic_vector(31 downto 0); funct3 : std_logic_vector(2 downto 0)) return std_logic_vector is
        variable ret : std_logic_vector(31 downto 0);
    begin
        case funct3(1 downto 0) is
            when "01" =>
                ret := csr_dat;
            when "10" =>
                ret := current_csr or csr_dat;
            when others =>
                ret := current_csr and csr_dat;
        end case;
        return ret;
    end function;
    signal valid, ready : std_logic;
    signal mscratch : std_logic_vector(31 downto 0) := (others => '0');
    signal mie : std_logic_vector(31 downto 0) := (others => '0');
    signal mstatus : std_logic_vector(31 downto 0) := (others => '0');
    signal mtvec : std_logic_vector(31 downto 0) := (others => '0');
    signal mepc : std_logic_vector(31 downto 0) := (others => '0');
    signal mcause : std_logic_vector(31 downto 0) := (others => '0');
    signal mtval : std_logic_vector(31 downto 0);
    -- debug csr
    signal dcsr : std_logic_vector(31 downto 0) := (others => '0');
    signal dcsr_cause : std_logic_vector(2 downto 0) := (others => '0');
    signal dcsr_version : std_logic_vector(3 downto 0) := (others => '0');
    signal dcsr_ebreakm, dcsr_step : std_logic := '0';
    signal dpc : std_logic_vector(31 downto 0) := (others => '0');
    signal dm_data0 : std_logic_vector(31 downto 0) := (others => '0');
begin
    
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            mie <= (others => '0');
            valid <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                mie <= (others => '0');
                valid <= '0';
            else
                if valid_i = '1' and ready = '1' then
                    valid <= '1';
                    rd_adr_o <= rd_adr_i;
                    case address_i is
                        when CSR_MSCRATCH =>
                            rd_dat_o <= mscratch;
                            mscratch <= write_csr(data_i, mscratch, funct3_i);
                        when CSR_MSTATUS =>
                            rd_dat_o <= mstatus;
                        when CSR_MIE =>
                            rd_dat_o <= mie;
                            mie <= write_csr(data_i, mie, funct3_i);
                        when CSR_MTVEC =>
                            rd_dat_o <= mtvec;
                            mtvec <= write_csr(data_i, mtvec, funct3_i);
                        when CSR_MEPC =>
                            rd_dat_o <= mepc;
                        when CSR_MCAUSE =>
                            rd_dat_o <= mcause;
                        when CSR_MTVAL =>
                            rd_dat_o <= mtval;
                        when CSR_DPC => 
                            rd_dat_o <= dpc;    
                        when CSR_DCSR => 
                            rd_dat_o(31 downto 28) <= dcsr_version;
                            rd_dat_o(27 downto 16) <= (others => '0');
                            rd_dat_o(15) <= dcsr_ebreakm;
                            rd_dat_o(14 downto 9) <= (others => '0');
                            rd_dat_o(8 downto 6) <= dcsr_cause;
                            rd_dat_o(5 downto 3) <= (others => '0');
                            rd_dat_o(2) <= dcsr_step;
                            rd_dat_o(1 downto 0) <= (others => '0');
                        when CSR_DM_DATA0 => 
                            rd_dat_o <= dm_data0;
                        when others =>
                            rd_dat_o <= (others => '0');
                    end case;
                elsif valid = '1' and ready_i = '1' then
                    valid <= '0';
                end if;
            end if;
        end if;
    end process;
    valid_o <= valid;
    rd_we_o <= valid;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if exception_taken_i = '1' then
                if ecall_i = '1' then
                    mcause <= CSR_MCAUSE_MACHINE_ECALL;
                elsif ebreak_i = '1' then
                    mcause <= CSR_MCAUSE_BREAKPOINT;
                elsif cause_external_irq_i = '1' then
                    mcause <= CSR_MCAUSE_MACHINE_EXTERNAL_INTERRUPT;
                elsif cause_timer_irq_i = '1' then
                    mcause <= CSR_MCAUSE_MACHINE_TIMER_INTERRUPT;
                end if;
            elsif valid_i = '1' and ready_i = '1' and address_i = CSR_MCAUSE then
                mcause <= write_csr(data_i, mcause, funct3_i);
            end if;
            if exception_taken_i = '1' then
                mepc <= exception_pc_i;
            elsif valid_i = '1' and ready_i = '1' and address_i = CSR_MEPC then
                mepc <= write_csr(data_i, mepc, funct3_i);
            end if;
            if exception_taken_i = '1' and ebreak_i = '1' then
                mtval <= exception_pc_i;
            elsif valid_i = '1' and ready_i = '1' and address_i = CSR_MTVAL then
                mtval <= write_csr(data_i, mtval, funct3_i);
            end if;

            if exception_taken_i = '1' and cause_debug_irq_i = '1' then
                dpc <= exception_pc_i;
            elsif valid_i = '1' and ready_i = '1' and address_i = CSR_DPC then
                dpc <= write_csr(data_i, dpc, funct3_i);
            end if;
            if exception_taken_i = '1' and cause_debug_irq_i = '1' then
                if dm_halt_i = '1' then
                    dcsr(8 downto 6) <= std_logic_vector(to_unsigned(3, 3)); -- HALTREQ
                elsif ebreak_i = '1' then
                    dcsr(8 downto 6) <= std_logic_vector(to_unsigned(1, 3)); -- EBREAKM
                elsif dcsr(2) = '1' then
                    dcsr(8 downto 6) <= std_logic_vector(to_unsigned(4, 3)); -- STEP
                end if;
            elsif valid_i = '1' and ready_i = '1' and address_i = CSR_DCSR then
                dcsr <= write_csr(data_i, dcsr, funct3_i);
            end if;
            if dm_data0_vld_i = '1' then
                dm_data0 <= dm_data0_dat_i;
            elsif valid_i = '1' and ready_i = '1' and address_i = CSR_DM_DATA0 then
                dm_data0 <= write_csr(data_i, dm_data0, funct3_i);
            end if;
        end if;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            mstatus <= (others => '0');
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                mstatus <= (others => '0');
            else
                if exception_taken_i = '1' then
                    mstatus(7) <= mstatus(3);
                    -- mstatus.mie = 0
                    mstatus(3) <= '0';
                    -- mstatus.mpp = current privilege mode 
                    mstatus(12 downto 11) <= "11";
                elsif exception_exit_i = '1' then
                    -- privilege set to mstatus.mpp
                    -- mstatus.mie = mstatus.mpie
                    mstatus(3) <= mstatus(7);
                    mstatus(7) <= '1';
                    mstatus(12 downto 11) <= "11";
                elsif valid_i = '1' and ready_i = '1' and address_i = CSR_MSTATUS then
                    mstatus <= write_csr(data_i, mstatus, funct3_i);
                end if;
            end if;
        end if;
    end process;

    ready <= 
        '0' when valid = '1' and ready_i = '0' else
        '1';
    ready_o <= ready;

    mstatus_o <= mstatus;
    mie_o <= mie;
    mtvec_o <= mtvec;
    mepc_o <= mepc;

    dcsr_cause <= dcsr(8 downto 6);
    dcsr_version <= x"4";
    dcsr_ebreakm <= dcsr(15);
    dcsr_step <= dcsr(2);
    
    dcsr_o(31 downto 28) <= dcsr_version;
    dcsr_o(27 downto 16) <= (others => '0');
    dcsr_o(15) <= dcsr_ebreakm;
    dcsr_o(14 downto 9) <= (others => '0');
    dcsr_o(8 downto 6) <= dcsr_cause;
    dcsr_o(5 downto 3) <= (others => '0');
    dcsr_o(2) <= dcsr_step;
    dcsr_o(1 downto 0) <= (others => '0');

    dpc_o <= dpc;
    dm_data0_dat_o <= dm_data0;
end architecture rtl;