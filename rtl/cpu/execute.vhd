library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity execute is
    generic (
        G_FULL_BARREL_SHIFTER : boolean := FALSE;
        G_SHIFTER_EARLY_INJECTION : boolean := FALSE;
        G_MULDIV : boolean := FALSE
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        flush_i : in std_logic;
        enable_i : in std_logic;
        multicycle_enable_i : in std_logic;
        multicycle_flush_i : in std_logic;
        valid_i : in std_logic;
        instr_i : in std_logic_vector(31 downto 0);
        ctrl_i : in execute_struct_t;
        opcode_i : in opcode_t;
        rs1_adr_i : in std_logic_vector(4 downto 0);
        rs2_adr_i : in std_logic_vector(4 downto 0);
        rd_adr_i : in std_logic_vector(4 downto 0);
        rd_we_i : in std_logic;
        funct3_i : in std_logic_vector(2 downto 0);
        funct7_i : in std_logic_vector(6 downto 0);
        valid_o : out std_logic;
        opcode_o : out opcode_t;
        rd_adr_o : out std_logic_vector(4 downto 0);
        rd_we_o : out std_logic;
        rs1_adr_o : out std_logic_vector(4 downto 0);
        rs2_adr_o : out std_logic_vector(4 downto 0);
        immediate_o : out std_logic_vector(31 downto 0);
        alu_result_a_o : out std_logic_vector(31 downto 0);
        alu_result_b_o : out std_logic_vector(31 downto 0);
        funct3_o : out std_logic_vector(2 downto 0);
        funct7_o : out std_logic_vector(6 downto 0);
        shifter_start_o : out std_logic;
        shifter_result_o : out std_logic_vector(31 downto 0);
        shifter_ready_o : out std_logic;
        muldiv_start_o : out std_logic;
        muldiv_result_o : out std_logic_vector(31 downto 0);
        muldiv_ready_o : out std_logic;
        target_pc_i : in std_logic_vector(31 downto 0);
        load_pc_i : in std_logic;
        current_pc_o : out std_logic_vector(31 downto 0);
        multicycle_o : out std_logic;
        src1_dat_o : out std_logic_vector(31 downto 0);
        src2_dat_o : out std_logic_vector(31 downto 0);
        lsu_valid_o : out std_logic;
        lsu_address_o : out std_logic_vector(31 downto 0);
        lsu_write_data_o : out std_logic_vector(31 downto 0);
        lsu_load_o : out std_logic;
        lsu_store_o : out std_logic;
        ecall_o : out std_logic;
        ebreak_o : out std_logic;
        mret_o : out std_logic;
        struct_o : out execute_struct_t
    );
end entity execute;

architecture rtl of execute is
    constant C_ENABLE_SHIFTER_DATA_PATH : boolean := G_SHIFTER_EARLY_INJECTION;
    signal valid : std_logic;
    signal rs1_adr, rs2_adr, rd_adr : std_logic_vector(4 downto 0);
    signal rd_we : std_logic;
    signal immediate : std_logic_vector(31 downto 0);
    signal funct3 : std_logic_vector(2 downto 0);
    signal funct7 : std_logic_vector(6 downto 0);
    signal alu_result_a, alu_result_b : std_logic_vector(31 downto 0);
    signal opcode : opcode_t;
    signal ctrl : execute_struct_t;
-- PC
    signal pc, pc_incr : std_logic_vector(31 downto 0);
    signal address_pc : std_logic_vector(31 downto 0);
-- ALU
    signal alu_arith, alu_signed : std_logic;
    signal alu_logic : std_logic_vector(1 downto 0);
    signal alu_a, alu_b : std_logic_vector(31 downto 0);
    signal alu_arith_r : std_logic_vector(32 downto 0);
    signal alu_logic_r : std_logic_vector(31 downto 0);
-- SHIFTER
    signal shifter_start, shifter_ready, shifter_srst : std_logic;
    signal shifter_shmt : std_logic_vector(4 downto 0);
    signal shifter_type : std_logic_vector(1 downto 0);
    signal shifter_data_in, shifter_data_out : std_logic_vector(31 downto 0);
-- MULDIV
    signal muldiv_valid, muldiv_start, muldiv_ready, muldiv_srst : std_logic;
    signal muldiv_result : std_logic_vector(31 downto 0);
-- DEBUG
    signal instr : std_logic_vector(31 downto 0);
begin
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if enable_i = '1' then
                rs1_adr <= rs1_adr_i;
                rs2_adr <= rs2_adr_i;
                rd_adr <= rd_adr_i;
                rd_we <= rd_we_i;
                funct3 <= funct3_i;
                funct7 <= funct7_i;
                opcode <= opcode_i;
                instr <= instr_i;
                ctrl <= ctrl_i;
            end if;
        end if;
    end process;
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            valid <= '0';
        elsif rising_edge(clk_i) then
            if enable_i = '1' then
                if flush_i = '1' then
                    valid <= '0';
                else
                    valid <= valid_i;
                end if;
            end if;
        end if;
    end process;

    pc <= ctrl.pc;

    valid_o <= valid;
    opcode_o <= opcode;
    rd_adr_o <= rd_adr;
    rd_we_o <= rd_we and valid and not ctrl.rd_adr_is_zero;
    alu_result_a_o <= alu_result_a;
    alu_result_b_o <= alu_result_b;
    funct3_o <= funct3;
    funct7_o <= funct7;
    rs1_adr_o <= rs1_adr;
    rs2_adr_o <= rs2_adr;
    current_pc_o <= pc;
    multicycle_o <= '1' when valid = '1' and ctrl.shifter_en = '1' and G_FULL_BARREL_SHIFTER = FALSE else '0';
-- ALU
    u_alu : entity work.alu
        port map (
            arith_a_i => alu_a,
            arith_b_i => alu_b,
            signed_i => alu_signed,
            arith_op_i => alu_arith,
            logic_a_i => ctrl.src1,
            logic_b_i => alu_b,
            logic_op_i => alu_logic,
            arith_result_o => alu_arith_r,
            logic_result_o => alu_logic_r
        );

    alu_a <= ctrl.src1;
    alu_b <= ctrl.src2;

    alu_arith <= ctrl.alu_arith;

    alu_signed <= not funct3(0); -- SLT
--    alu_signed <= ctrl.alu_signed;
    alu_logic <= funct3(1 downto 0);

    process (ctrl, alu_arith_r, alu_logic_r, shifter_data_out)
    begin
        if G_SHIFTER_EARLY_INJECTION = TRUE then
            case ctrl.rd_res_sel is
                when "00" => alu_result_a <= alu_arith_r(31 downto 0);
                when "01" => alu_result_a <= alu_logic_r;
                when "10" => alu_result_a <= (31 downto 1 => '0') & alu_arith_r(alu_arith_r'left);
                when "11" => alu_result_a <= shifter_data_out;
                when others =>
            end case;
        else
            case ctrl.rd_res_sel is
                when "00" => alu_result_a <= alu_arith_r(31 downto 0);
                when "01" => alu_result_a <= alu_logic_r;
                when others => alu_result_a <= (31 downto 1 => '0') & alu_arith_r(alu_arith_r'left);
            end case;
        end if;
    end process;

--    alu_eq_o <= '1' when alu_arith_r(31 downto 0) = (31 downto 0 => '0') else '0';
--    alu_lt_o <= alu_arith_r(alu_arith_r'left);

    address_pc <= std_logic_vector(unsigned(ctrl.base_addr) + unsigned(ctrl.imm));
    alu_result_b <= address_pc;

-- SHIFTER
    u_shifter : entity work.shifter
        generic map (
            G_FULL_BARREL_SHIFTER => G_FULL_BARREL_SHIFTER,
            G_SHIFTER_EARLY_INJECTION => G_SHIFTER_EARLY_INJECTION
        )
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => shifter_srst,
            shift_i => shifter_shmt,
            type_i => shifter_type,
            data_i => shifter_data_in,
            start_i => shifter_start,
            data_o => shifter_data_out,
            done_o => open,
            ready_o => shifter_ready
        );
    shifter_srst <= multicycle_flush_i;
    shifter_shmt <= alu_b(4 downto 0);
    shifter_type <= funct3(2) & funct7(5);
    shifter_data_in <= ctrl.src1;
    shifter_start <=
        '1' when valid = '1' and ctrl.shifter_en = '1' and (multicycle_enable_i = '1' or G_FULL_BARREL_SHIFTER = TRUE) else
        '0';
    shifter_result_o <= shifter_data_out;
    shifter_ready_o <= shifter_ready;
    shifter_start_o <= shifter_start when G_SHIFTER_EARLY_INJECTION = FALSE else '0';

-- LSU
    lsu_address_o <= address_pc;
    lsu_valid_o <= ctrl.lsu_valid and valid;
    lsu_load_o <= opcode.load;
    lsu_store_o <= opcode.store;
    process (ctrl, funct3)
    begin
        lsu_write_data_o <= ctrl.src2;
        case funct3(1 downto 0) is
            when "00" => lsu_write_data_o <= ctrl.src2(7 downto 0) & ctrl.src2(7 downto 0) & ctrl.src2(7 downto 0) & ctrl.src2(7 downto 0);
            when "01" => lsu_write_data_o <= ctrl.src2(15 downto 0) & ctrl.src2(15 downto 0);
            when others =>
        end case;
    end process;

-- MUL-DIV
gen_muldiv: if G_MULDIV = TRUE generate
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            muldiv_valid <= '0';
        elsif rising_edge(clk_i) then
            if enable_i = '1' then
                if flush_i = '1' then
                    muldiv_valid <= '0';
                else
                    muldiv_valid <= valid_i;
                end if;
            elsif muldiv_valid = '1' and muldiv_ready = '1' then
                muldiv_valid <= '0';
            end if;
        end if;
    end process;
    u_muldiv : entity work.muldiv
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => muldiv_srst,
            a_i => ctrl.src1,
            b_i => ctrl.src2,
            funct3_i => funct3,
            start_i => muldiv_start,
            result_o => muldiv_result,
            ready_o => muldiv_ready
        );
    muldiv_srst <= multicycle_flush_i;
    muldiv_start <= muldiv_valid and ctrl.muldiv_en;
    muldiv_result_o <= muldiv_result;
end generate gen_muldiv;
    muldiv_ready_o <= muldiv_ready when G_MULDIV = TRUE else '0';
    muldiv_start_o <= muldiv_start when G_MULDIV = TRUE else '0';

    src1_dat_o <= ctrl.src1;
    src2_dat_o <= ctrl.src2;
    struct_o <= ctrl;
    ecall_o <= ctrl.ecall and valid;
    ebreak_o <= ctrl.ebreak and valid;
    mret_o <= ctrl.mret and valid;
end architecture rtl;
