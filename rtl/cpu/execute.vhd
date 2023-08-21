library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity execute is
    generic (
        G_FULL_BARREL_SHIFTER : boolean := FALSE
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        flush_i : in std_logic;
        enable_i : in std_logic;
        multicycle_flush_i : in std_logic;
        valid_i : in std_logic;
        instr_i : in std_logic_vector(31 downto 0);
        opcode_i : in opcode_t;
        rs1_adr_i : in std_logic_vector(4 downto 0);
        rs2_adr_i : in std_logic_vector(4 downto 0);
        rd_adr_i : in std_logic_vector(4 downto 0);
        rd_we_i : in std_logic;
        immediate_i : in std_logic_vector(31 downto 0);
        funct3_i : in std_logic_vector(2 downto 0);
        funct7_i : in std_logic_vector(6 downto 0);
        rs1_dat_i : in std_logic_vector(31 downto 0);
        rs2_dat_i : in std_logic_vector(31 downto 0);
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
        shifter_result_o : out std_logic_vector(31 downto 0);
        target_pc_i : in std_logic_vector(31 downto 0);
        load_pc_i : in std_logic;
        current_pc_o : out std_logic_vector(31 downto 0);
        multicycle_o : out std_logic;
        ready_o : out std_logic
    );
end entity execute;

architecture rtl of execute is
    signal valid : std_logic;
    signal rs1_adr, rs2_adr, rd_adr : std_logic_vector(4 downto 0);
    signal rd_we : std_logic;
    signal immediate : std_logic_vector(31 downto 0);
    signal funct3 : std_logic_vector(2 downto 0);
    signal funct7 : std_logic_vector(6 downto 0);
    signal alu_result_a, alu_result_b : std_logic_vector(31 downto 0);
    signal opcode : opcode_t;
-- PC
    signal pc, pc_incr : std_logic_vector(31 downto 0);
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
                immediate <= immediate_i;
                funct3 <= funct3_i;
                funct7 <= funct7_i;
                opcode <= opcode_i;
                instr <= instr_i;
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
    valid_o <= valid;
    opcode_o <= opcode;
    rd_adr_o <= rd_adr;
    rd_we_o <= rd_we and valid;
    alu_result_a_o <= alu_result_a;
    alu_result_b_o <= alu_result_b;
    immediate_o <= immediate;
    funct3_o <= funct3;
    rs1_adr_o <= rs1_adr;
    rs2_adr_o <= rs2_adr;
    current_pc_o <= pc;
    ready_o <= shifter_ready;
    multicycle_o <= valid when (opcode.reg_imm or opcode.reg_reg) = '1' and (funct3 = RV32I_FN3_SL or funct3 = RV32I_FN3_SR) and G_FULL_BARREL_SHIFTER = FALSE else '0';
-- PC
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if enable_i = '1' then
                if load_pc_i = '1' then
                    pc <= target_pc_i;
                elsif valid = '1' then
                    pc <= pc_incr;
                end if;
            end if;
        end if;
    end process;
    pc_incr <= std_logic_vector(unsigned(pc) + 4);
-- ALU
    u_alu : entity work.alu
        port map (
            a_i => alu_a,
            b_i => alu_b,
            signed_i => alu_signed,
            arith_op_i => alu_arith,
            logic_op_i => alu_logic,
            arith_result_o => alu_arith_r,
            logic_result_o => alu_logic_r
        );
    alu_a <= 
        pc when (opcode.auipc or opcode.jal or opcode.branch) = '1' else
        rs1_dat_i;

    alu_b <= 
        immediate when (opcode.reg_reg) = '0' else
        rs2_dat_i;

    alu_arith <= (opcode.reg_reg and funct7(5)) or (funct3(1) and (opcode.reg_reg or opcode.reg_imm)); -- SLT
    alu_signed <= not funct3(0); -- SLT
    alu_logic <= funct3(1 downto 0);

    process (opcode, pc_incr, funct3, alu_logic_r, alu_arith_r, rs2_dat_i)
    begin
        if (opcode.jal or opcode.jalr or opcode.branch) = '1' then
            alu_result_a <= pc_incr;
            alu_result_b <= alu_arith_r(31 downto 0);
        else
            if (opcode.reg_imm or opcode.reg_reg) = '1' and (funct3(2)) = '1' then
                alu_result_a <= alu_logic_r;
            elsif (opcode.reg_reg or opcode.reg_imm) = '1' and (funct3(1)) = '1' then
                alu_result_a <= (31 downto 1 => '0') & alu_arith_r(alu_arith_r'left);
            else
                alu_result_a <= alu_arith_r(31 downto 0);
            end if;
            alu_result_b <= rs2_dat_i;
        end if;
    end process;

-- SHIFTER
    u_shifter : entity work.shifter
    generic map (
        G_FULL_BARREL_SHIFTER => G_FULL_BARREL_SHIFTER
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
    shifter_data_in <= rs1_dat_i;
    shifter_start <= 
        valid when (opcode.reg_imm or opcode.reg_reg) = '1' and (funct3 = RV32I_FN3_SL or funct3 = RV32I_FN3_SR) else
        '0';
    shifter_result_o <= shifter_data_out;
end architecture rtl;