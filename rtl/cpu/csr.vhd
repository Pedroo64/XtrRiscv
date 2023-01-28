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
        mepc_o : out std_logic_vector(31 downto 0)
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
                ret := current_csr and (not csr_dat);
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
    signal mtval : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_result : std_logic_vector(31 downto 0);
begin

    block_alu : block
        signal alu_a, alu_b, alu_y : std_logic_vector(31 downto 0);
    begin
        alu_a <= data_i;
        with address_i select
            alu_b <= 
                mscratch when CSR_MSCRATCH,
                mstatus when CSR_MSTATUS,
                mie when CSR_MIE,
                mtvec when CSR_MTVEC,
                mepc when CSR_MEPC,
                mcause when CSR_MCAUSE,
                mtval when CSR_MTVAL,
                (others => '-') when others;
        

        with funct3_i(1 downto 0) select
            alu_y <= 
                alu_a when "01",
                alu_a or alu_b when "10",
                alu_a and (not alu_b) when "11",
                (others => '0') when others;

        csr_result <= alu_y;
    end block;


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
                            mscratch <= csr_result;
                        when CSR_MSTATUS =>
                            rd_dat_o <= mstatus;
                        when CSR_MIE =>
                            rd_dat_o <= mie;
                            mie <= csr_result;
                        when CSR_MTVEC =>
                            rd_dat_o <= mtvec;
                            mtvec <= csr_result;
                        when CSR_MEPC =>
                            rd_dat_o <= mepc;
                        when CSR_MCAUSE =>
                            rd_dat_o <= mcause;
                        when CSR_MTVAL =>
                            rd_dat_o <= mtval;
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
                mcause <= csr_result;
            end if;
            if exception_taken_i = '1' then
                mepc <= exception_pc_i;
            elsif valid_i = '1' and ready_i = '1' and address_i = CSR_MEPC then
                mepc <= csr_result;
            end if;
            if exception_taken_i = '1' and ebreak_i = '1' then
                mtval <= exception_pc_i;
            elsif valid_i = '1' and ready_i = '1' and address_i = CSR_MTVAL then
                mtval <= csr_result;
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
                    mstatus <= csr_result;
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
    
    
end architecture rtl;