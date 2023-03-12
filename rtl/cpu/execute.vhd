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
        srst_i : in std_logic;
        enable_i : in std_logic;
        valid_i : in std_logic;
        pc_i : in std_logic_vector(31 downto 0);
        opcode_i : in opcode_t;
        immediate_i : in std_logic_vector(31 downto 0);
        rs1_adr_i : in std_logic_vector(4 downto 0);
        rs1_dat_i : in std_logic_vector(31 downto 0);
        rs2_adr_i : in std_logic_vector(4 downto 0);
        rs2_dat_i : in std_logic_vector(31 downto 0);
        rd_adr_i : in std_logic_vector(4 downto 0);
        rd_we_i : in std_logic;
        funct3_i : in std_logic_vector(2 downto 0);
        funct7_i : in std_logic_vector(6 downto 0);
        rd_adr_o : out std_logic_vector(4 downto 0);
        rd_dat_o : out std_logic_vector(31 downto 0);
        rd_we_o : out std_logic;
        funct3_o : out std_logic_vector(2 downto 0);
        funct7_o : out std_logic_vector(6 downto 0);
        writeback_valid_o : out std_logic;
        writeback_ready_i : in std_logic;
        pc_o : out std_logic_vector(31 downto 0);
        load_pc_o : out std_logic;
        memory_rd_adr_o : out std_logic_vector(4 downto 0);
        memory_valid_o : out std_logic;
        memory_address_o : out std_logic_vector(31 downto 0);
        memory_data_o : out std_logic_vector(31 downto 0);
        memory_we_o : out std_logic;
        memory_size_o : out std_logic_vector(2 downto 0);
        memory_ready_i : in std_logic;
        csr_rd_adr_o : out std_logic_vector(4 downto 0);
        csr_valid_o : out std_logic;
        csr_address_o : out std_logic_vector(11 downto 0);
        csr_data_o : out std_logic_vector(31 downto 0);
        csr_ready_i : in std_logic;
        exception_valid_i : in std_logic;
        trap_vector_i : in std_logic_vector(31 downto 0);
        exception_pc_i : in std_logic_vector(31 downto 0);
        exception_pc_o : out std_logic_vector(31 downto 0);
        exception_taken_o : out std_logic;
        exception_exit_o : out std_logic;
        mret_o : out std_logic;
        ecall_o : out std_logic;
        ebreak_o : out std_logic;
        ready_o : out std_logic
    );
end entity execute;

architecture rtl of execute is
    signal opcode : opcode_t;
    signal comb_writeback_valid, comb_memory_valid, comb_csr_valid : std_logic;
    signal writeback_valid, memory_valid, csr_valid : std_logic;
    signal ready : std_logic;
    signal alu_arith_result, alu_logic_result, immediate : std_logic_vector(31 downto 0);
    signal alu_lt, alu_eq : std_logic;
    signal alu_arith_address : std_logic_vector(31 downto 0);
    signal address, data : std_logic_vector(31 downto 0);
    signal funct3 : std_logic_vector(2 downto 0);
    signal rd_adr : std_logic_vector(4 downto 0);
    signal comb_branch, comb_load_pc, comb_ecall, comb_ebreak, comb_mret : std_logic;
    signal branch, ecall, ebreak, mret : std_logic;
    signal last_pc, next_pc, branch_pc : std_logic_vector(31 downto 0);
    signal data_valid, load_pc : std_logic;
    signal shifter_data : std_logic_vector(31 downto 0);
    signal shifter_ready, shifter_done : std_logic;
begin

    block_alu_res : block
        signal op_signed : std_logic;
        signal op_a, op_b : std_logic_vector(31 downto 0);
        signal arith_op : std_logic;
        signal logic_op : std_logic_vector(1 downto 0);
        signal arith_res : std_logic_vector(32 downto 0);
        signal logic_res : std_logic_vector(31 downto 0);
    begin
        op_a <= pc_i when (opcode_i.auipc) = '1' else
            rs1_dat_i;
        op_b <= 
            immediate_i when (opcode_i.lui or opcode_i.reg_imm or opcode_i.auipc) = '1' else
            rs2_dat_i;

        arith_op <= 
            '1' when funct7_i(5) = '1' and opcode_i.reg_reg = '1' else
            '1' when (opcode_i.reg_reg = '1' or opcode_i.reg_imm = '1') and (funct3_i(1) = '1') else
            '1' when opcode_i.branch = '1' else
            '0';

        logic_op <= funct3_i(1 downto 0);

        op_signed <= 
            '1' when opcode_i.branch = '1' and funct3_i(2 downto 1) = "10" else
            '1' when (opcode_i.reg_imm or opcode_i.reg_reg) = '1' and funct3_i(1 downto 0) = "10" else 
            '0';

        u_alu : entity work.alu
            port map (
                a_i => op_a,
                b_i => op_b,
                signed_i => op_signed,
                arith_op_i => arith_op,
                logic_op_i => logic_op,
                arith_result_o => arith_res,
                logic_result_o => logic_res
            );

        alu_arith_result <= 
            (1 to 31 => '0') & arith_res(arith_res'left) when (opcode_i.reg_reg = '1' or opcode_i.reg_imm = '1') and (funct3_i = RV32I_FN3_SLT or funct3_i = RV32I_FN3_SLTU) else
            arith_res(arith_res'left - 1 downto 0);
        alu_logic_result <= logic_res;

        alu_eq <= '1' when op_a = op_b else '0';
        alu_lt <= arith_res(arith_res'left);

        data_valid <= 
            '0' when (opcode_i.reg_imm or opcode_i.reg_reg) = '1' and (funct3_i = RV32I_FN3_SL or funct3_i = RV32I_FN3_SR) else 
            '0' when (opcode_i.load or opcode_i.store) = '1' else
            enable_i;

    end block;

    block_alu_address : block
        signal op_a, op_b, res : std_logic_vector(31 downto 0);
    begin
        op_a <= 
            pc_i when (opcode_i.jal or opcode_i.branch) = '1' else
            rs1_dat_i;
        op_b <= immediate_i;
        res <= std_logic_vector(unsigned(op_a) + unsigned(op_b));
        alu_arith_address <= res;
    end block;

    block_shifter : block
        signal shifter_start : std_logic;
        signal shift_type : std_logic_vector(1 downto 0);
        signal shift : std_logic_vector(4 downto 0);
    begin
        shifter_start <= 
            enable_i when (opcode_i.reg_imm or opcode_i.reg_reg) = '1' and (funct3_i = RV32I_FN3_SL or funct3_i = RV32I_FN3_SR) else
            '0';

        shift_type <= 
            "10" when funct3_i = RV32I_FN3_SR and funct7_i(5) = '0' else
            "11" when funct3_i = RV32I_FN3_SR and funct7_i(5) = '1' else
            "00";
        shift <= 
            immediate_i(4 downto 0) when opcode_i.reg_imm = '1' else
            rs2_dat_i(4 downto 0);
        
        u_shifter : entity work.shifter
            generic map (
                G_FULL_BARREL_SHIFTER => G_FULL_BARREL_SHIFTER
            )
            port map (
                arst_i => arst_i,
                clk_i => clk_i,
                srst_i => srst_i,
                shift_i => shift,
                type_i => shift_type,
                data_i => rs1_dat_i,
                start_i => shifter_start,
                data_o => shifter_data,
                done_o => shifter_done,
                ready_o => shifter_ready,
                ready_i => writeback_ready_i
            );
    end block;

    block_branch : block
    begin
        process (opcode_i, funct3_i, alu_eq, alu_lt)
        begin
            if (opcode_i.jal or opcode_i.jalr) = '1' then
                comb_branch <= '1';
            elsif opcode_i.branch = '1' then
                case funct3_i is
                    when RV32I_FN3_BEQ =>
                        comb_branch <= alu_eq;
                    when RV32I_FN3_BNE =>
                        comb_branch <= not alu_eq;
                    when RV32I_FN3_BLT | RV32I_FN3_BLTU =>
                        comb_branch <= alu_lt;
                    when RV32I_FN3_BGE | RV32I_FN3_BGEU =>
                        comb_branch <= not alu_lt;
                    when others =>
                        comb_branch <= '0';
                end case;
            else
                comb_branch <= '0';
            end if;
        end process;        
    end block;

    comb_ecall <= '1' when opcode_i.sys = '1' and funct3_i = RV32I_FN3_TRAP and immediate_i(1 downto 0) = "00" else '0';
    comb_ebreak <= '1' when opcode_i.sys = '1' and funct3_i = RV32I_FN3_TRAP and immediate_i(1 downto 0) = "01" else '0';
    comb_mret <= '1' when opcode_i.sys = '1' and funct3_i = RV32I_FN3_TRAP and immediate_i(1 downto 0) = "10" else '0';

    comb_load_pc <= comb_branch or comb_ecall or comb_ebreak or comb_mret;

    comb_writeback_valid <= data_valid and (not opcode_i.sys);

    comb_memory_valid <= 
        '1' when (opcode_i.load or opcode_i.store) = '1' else
        '0';

    comb_csr_valid <= 
        '1' when opcode_i.sys = '1' and unsigned(funct3_i) /= 0 else
        '0';

    block_general : block
    begin
        process (clk_i, arst_i)
        begin
            if arst_i = '1' then
                writeback_valid <= '0';
                memory_valid <= '0';
                csr_valid <= '0';
                load_pc <= '0';
            elsif rising_edge(clk_i) then
                if srst_i = '1' then
                    writeback_valid <= '0';
                    memory_valid <= '0';
                    csr_valid <= '0';
                    load_pc <= '0';
                else
                    if enable_i = '1' then
                        writeback_valid <= comb_writeback_valid;
                        memory_valid <= comb_memory_valid;
                        csr_valid <= comb_csr_valid;
                    elsif ready = '1' then
                        writeback_valid <= '0';
                        memory_valid <= '0';
                        csr_valid <= '0';
                    end if;
                    if enable_i = '1' then
                        load_pc <= comb_load_pc;
                    else
                        load_pc <= '0';
                    end if;
                end if;
            end if;
        end process;

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if enable_i = '1' then
                    opcode <= opcode_i;
                    address <= alu_arith_address;
                    immediate <= immediate_i;
                    if ((opcode_i.reg_imm or opcode_i.reg_reg) and funct3_i(2)) = '1' then 
                        data <= alu_logic_result;
                    else
                        data <= alu_arith_result;
                    end if;
                    rd_adr <= rd_adr_i;
                    ecall <= comb_ecall;
                    ebreak <= comb_ebreak;
                    mret <= comb_mret;
                    memory_data_o <= rs2_dat_i;
                    memory_we_o <= opcode_i.store;
                    funct3 <= funct3_i;
                    csr_address_o <= immediate_i(11 downto 0);
                    funct7_o <= funct7_i;
                    if funct3_i(2) = '0' then
                        csr_data_o <= rs1_dat_i;
                    else
                        csr_data_o <= (5 to 31 => '0') & rs1_adr_i;
                    end if;
                    branch <= comb_branch;
                    last_pc <= pc_i;
                    rd_we_o <= rd_we_i;
                end if;
            end if;
        end process;
        branch_pc <= address;
        next_pc <= std_logic_vector(unsigned(last_pc) + 4);

        funct3_o <= funct3;
        rd_adr_o <= rd_adr;
        rd_dat_o <= 
            shifter_data when shifter_done = '1' else
            next_pc when (opcode.jal or opcode.jalr) = '1' else
            data;
        pc_o <= 
            trap_vector_i when (ecall or ebreak or exception_valid_i) = '1' else
            exception_pc_i when mret = '1' else 
            branch_pc;
        load_pc_o <= load_pc or exception_valid_i;
        memory_rd_adr_o <= rd_adr;
        memory_address_o <= address;
        memory_size_o <= funct3;
        csr_rd_adr_o <= rd_adr;
        ecall_o <= ecall;
        ebreak_o <= ebreak;
        mret_o <= mret;
        exception_taken_o <= ecall or ebreak or exception_valid_i;
        exception_exit_o <= mret;
        exception_pc_o <= 
            last_pc when (ecall or ebreak) = '1' else
            branch_pc when branch = '1' else
            next_pc;
    end block;

    ready <= 
        '0' when shifter_ready = '0' else
        '0' when writeback_valid = '1' and writeback_ready_i = '0' else
        '0' when memory_valid = '1' and memory_ready_i = '0' else
        '0' when csr_valid = '1' and csr_ready_i = '0' else
        '1';

    ready_o <= ready;

    writeback_valid_o <= writeback_valid or shifter_done;
    memory_valid_o <= memory_valid;
    csr_valid_o <= csr_valid;

end architecture rtl;