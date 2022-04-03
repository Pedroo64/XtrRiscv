library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.csr_def.all;

entity csr is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        en_i : in std_logic;
        we_i : in std_logic;
        vld_i : in std_logic;
        adr_i : in std_logic_vector(11 downto 0);
        funct3_i : in std_logic_vector(2 downto 0);
        dat_i : in std_logic_vector(31 downto 0);
        rd_adr_i : in std_logic_vector(4 downto 0);
        rd_adr_o : out std_logic_vector(4 downto 0);
        rd_dat_o : out std_logic_vector(31 downto 0);
        rd_we_o : out std_logic;
        id_vld_i : in std_logic;
        id_pc_i : in std_logic_vector(31 downto 0);
        ex_pc_i : in std_logic_vector(31 downto 0);
        ex_vld_i : in std_logic;
        load_pc_o : out std_logic;
        pc_o : out std_logic_vector(31 downto 0);
        ex_load_pc_i : in std_logic;
        ex_rd_we_i : in std_logic;
        branching_i : in std_logic;
        wb_rdy_i : in std_logic;
        rdy_o : out std_logic;
        external_irq_i : in std_logic;
        mret_i : in std_logic;
        ecall_i : in std_logic
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
    signal rdy, rd_we : std_logic;
    type csr_machine_registers_t is record
        mcause : std_logic_vector(31 downto 0);
        mstatus : std_logic_vector(31 downto 0);
        mie : std_logic_vector(31 downto 0);
        mtvec : std_logic_vector(31 downto 0);
        mepc : std_logic_vector(31 downto 0);
    end record csr_machine_registers_t;
    signal mcsr : csr_machine_registers_t := (mstatus => (others => '0'), mie => (others => '0'), mtvec => (others => '0'), mcause => (others => '0'), mepc => (others => '0'));
    signal saved_pc : std_logic_vector(31 downto 0);
    signal on_irq, d_on_irq : std_logic;
    signal irq_en, ext_irq_en : std_logic;
    signal d_branching, d_ecall : std_logic;
    signal external_irq : std_logic;
begin
    
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            rd_we <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                rd_we <= '0';
            else
                if en_i = '1' and vld_i = '1' and rdy = '1' then
                    rd_we <= '1';
                    rd_adr_o <= rd_adr_i;
                    if we_i = '1' then
                        case adr_i is
                            when CSR_MSTATUS =>
                                rd_dat_o <= mcsr.mstatus;
                                mcsr.mstatus <= write_csr(dat_i, mcsr.mstatus, funct3_i);
                            when CSR_MIE =>
                                rd_dat_o <= mcsr.mie;
                                mcsr.mie <= write_csr(dat_i, mcsr.mie, funct3_i);
                            when CSR_MTVEC =>
                                rd_dat_o <= mcsr.mtvec;
                                mcsr.mtvec <= write_csr(dat_i, mcsr.mtvec, funct3_i);        
                            when CSR_MEPC =>
                                rd_dat_o <= mcsr.mepc;                
                            when CSR_MCAUSE =>
                                rd_dat_o <= mcsr.mcause;
                            when others =>
                                rd_dat_o <= (others => '0');
                        end case;
                    end if;
                elsif rd_we = '1' and wb_rdy_i = '1' then
                    rd_we <= '0';
                end if;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if ecall_i = '1' then
                mcsr.mcause <= CSR_MCAUSE_MACHINE_ECALL;
            elsif external_irq = '1' then
                mcsr.mcause <= CSR_MCAUSE_MACHINE_EXTERNAL_INTERRUPT;
            elsif vld_i = '1' and we_i = '1' and rdy = '1' then
                if adr_i = CSR_MSTATUS then
                    mcsr.mcause <= write_csr(dat_i, mcsr.mcause, funct3_i);
                end if;
            end if;
            if d_on_irq = '0' and ex_vld_i = '1' then
                if ex_load_pc_i = '1' then
                    mcsr.mepc <= ex_pc_i;
                else
                    mcsr.mepc <= std_logic_vector(unsigned(ex_pc_i) + 4);
                end if;
            elsif vld_i = '1' and we_i = '1' and rdy = '1' then
                if adr_i = CSR_MEPC then
                    mcsr.mepc <= write_csr(dat_i, mcsr.mepc, funct3_i);
                end if;
            end if;
        end if;
    end process;

    rdy <= '0' when rd_we = '1' and wb_rdy_i = '0' else '1';

    rd_we_o <= rd_we;
    rdy_o <= rdy;

    irq_en <= mcsr.mstatus(CSR_MSTATUS_MIE);
    ext_irq_en <= mcsr.mie(CSR_MIE_MEIE);

    --
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            on_irq <= '0';
            d_on_irq <= '0';
            external_irq <= '0';
        elsif rising_edge(clk_i) then
            d_on_irq <= on_irq;
            d_branching <= branching_i;
            external_irq <= '0';
            if on_irq = '0' then
                if ecall_i = '1' then
                    on_irq <= '1';
                elsif irq_en = '1' then -- for future interrupt support (timer, software)
                    if (external_irq_i and ext_irq_en) = '1' then
                        on_irq <= '1';
                        external_irq <= '1';
                    end if;
                end if;
            elsif mret_i = '1' then
                on_irq <= '0';
            end if;
--            if d_on_irq = '0' and ex_vld_i = '1' then
--                if ex_load_pc_i = '1' then
--                    saved_pc <= ex_pc_i;
--                else
--                    saved_pc <= std_logic_vector(unsigned(ex_pc_i) + 4);
--                end if;
--            end if;
        end if;
    end process;
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            d_ecall <= ecall_i;
        end if;
    end process;

    load_pc_o <=
        '1' when ecall_i = '1' and on_irq = '0' else
        '1' when d_ecall = '0' and on_irq = '1' and d_on_irq = '0' else
        '1' when mret_i = '1' else
        '0';
    pc_o <= 
        mcsr.mtvec when ecall_i = '1' else
        mcsr.mtvec when d_ecall = '0' and on_irq = '1' and d_on_irq = '0' else
        mcsr.mepc;

end architecture rtl;