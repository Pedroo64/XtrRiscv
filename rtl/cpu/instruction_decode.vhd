library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;
use work.csr_def.all;

entity instruction_decode is
    generic (
        G_EXTENSION_C : boolean := FALSE;
        G_EXTENSION_M : boolean := FALSE;
        G_EXTENSION_ZICSR : boolean := FALSE;
        G_SHIFTER_EARLY_INJECTION : boolean := FALSE
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        flush_i : in std_logic;
        enable_i : in std_logic;
        valid_i : in std_logic;
        instr_i : in std_logic_vector(31 downto 0);
        compressed_i : in std_logic;
        load_pc_i : in std_logic;
        target_pc_i : in std_logic_vector(31 downto 0);
        valid_o : out std_logic;
        opcode_o : out opcode_t;
        next_rs1_adr_o : out std_logic_vector(4 downto 0);
        next_rs2_adr_o : out std_logic_vector(4 downto 0);
        rs1_adr_o : out std_logic_vector(4 downto 0);
        rs1_en_o : out std_logic;
        rs1_dat_i : in std_logic_vector(31 downto 0);
        rs2_adr_o : out std_logic_vector(4 downto 0);
        rs2_en_o : out std_logic;
        rs2_dat_i : in std_logic_vector(31 downto 0);
        rd_adr_o : out std_logic_vector(4 downto 0);
        rd_we_o : out std_logic;
        funct3_o : out std_logic_vector(2 downto 0);
        funct7_o : out std_logic_vector(6 downto 0);
        compressed_o : out std_logic;
        instr_o : out std_logic_vector(31 downto 0);
        ctrl_o : out execute_struct_t
    );
end entity instruction_decode;

architecture rtl of instruction_decode is
    signal valid : std_logic;
    signal fetched_instr, decompressed_instr, instr_dat : std_logic_vector(31 downto 0);
    signal instr_opcode : std_logic_vector(6 downto 0);
    signal rs1_en, rs2_en : std_logic;
    signal rd_we, compressed : std_logic;
    signal opcode : opcode_t;
    signal opcode_type : opcode_type_t;
    signal ctrl : execute_struct_t;
    alias instr_funct3 : std_logic_vector(2 downto 0) is instr_dat(14 downto 12);
    alias instr_funct7 : std_logic_vector(6 downto 0) is instr_dat(31 downto 25);
    signal rs1_adr : std_logic_vector(4 downto 0);
    signal imm_i, imm_s, imm_b, imm_u, imm_j : std_logic_vector(31 downto 0);
    signal pc, nxt_pc, pc_incr, pc_plus_4 : std_logic_vector(31 downto 0);
    signal pc_en : std_logic;
begin
    gen_compress: if G_EXTENSION_C = TRUE generate
        -- decompressor
        u_decompressor : entity work.decompressor
            port map (
                instr_i => instr_i(15 downto 0),
                instr_o => decompressed_instr
            );
    end generate gen_compress;
    fetched_instr <= decompressed_instr when compressed_i = '1' else instr_i;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if enable_i = '1' then
                instr_dat <= fetched_instr;
                if G_EXTENSION_C = TRUE then
                    compressed <= compressed_i;
                else
                    compressed <= '0';
                end if;
            end if;
        end if;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            valid <= '0';
        elsif rising_edge(clk_i) then
            if enable_i = '1' then
                valid <= valid_i and not flush_i;
            end if;
        end if;
    end process;

    instr_opcode <= instr_dat(6 downto 2) & "11";

    next_rs1_adr_o <= fetched_instr(19 downto 15) when enable_i = '1' else instr_dat(19 downto 15);
    next_rs2_adr_o <= fetched_instr(24 downto 20) when enable_i = '1' else instr_dat(24 downto 20);
    rs1_adr_o <= instr_dat(19 downto 15);
    rs2_adr_o <= instr_dat(24 downto 20);
    rd_adr_o <= instr_dat(11 downto 7);
    rd_we_o <= rd_we;
    rs1_en_o <= rs1_en;
    rs2_en_o <= rs2_en;
    funct3_o <= instr_funct3;
    funct7_o <= instr_funct7;

    imm_i <= (31 downto 12 => instr_dat(31)) & instr_dat(31 downto 20);
    imm_s <= (31 downto 12 => instr_dat(31)) & instr_dat(31 downto 25) & instr_dat(11 downto 7);
    imm_b <= (31 downto 12 => instr_dat(31)) & instr_dat(7) & instr_dat(30 downto 25) & instr_dat(11 downto 8) & '0';
    imm_u <= instr_dat(31 downto 12) & (11 downto 0 => '0');
    imm_j <= (31 downto 20 => instr_dat(31)) & instr_dat(19 downto 12) & instr_dat(20) & instr_dat(30 downto 21) & '0';

    process (instr_opcode)
    begin
        opcode <= (
            lui => '0',
            auipc => '0',
            jal => '0',
            jalr => '0',
            branch => '0',
            load => '0',
            store => '0',
            reg_imm => '0',
            reg_reg => '0',
            fence => '0',
            sys => '0',
            illegal => '0'
        );
        case instr_opcode is
            when RV32I_OP_LUI     =>
            when RV32I_OP_AUIPC   =>
            when RV32I_OP_JAL     => opcode.jal <= '1';
            when RV32I_OP_JALR    => opcode.jal <= '1';
            when RV32I_OP_BRANCH  => opcode.branch <= '1';
            when RV32I_OP_LOAD    => opcode.load <= '1';
            when RV32I_OP_STORE   => opcode.store <= '1';
            when RV32I_OP_REG_IMM =>
            when RV32I_OP_REG_REG => opcode.reg_reg <= '1';
            when RV32I_OP_FENCE   =>
            when RV32I_OP_SYS     => if G_EXTENSION_ZICSR = TRUE then opcode.sys <= '1'; end if;
            when others =>
        end case;
    end process;

    process (instr_opcode)
    begin
        rs1_en <= '0';
        rs2_en <= '0';
        rd_we <= '0';
        case instr_opcode is
            when RV32I_OP_LUI     => rs1_en <= '0'; rs2_en <= '0'; rd_we <= '1';
            when RV32I_OP_AUIPC   => rs1_en <= '0'; rs2_en <= '0'; rd_we <= '1';
            when RV32I_OP_JAL     => rs1_en <= '0'; rs2_en <= '0'; rd_we <= '1';
            when RV32I_OP_JALR    => rs1_en <= '1'; rs2_en <= '0'; rd_we <= '1';
            when RV32I_OP_BRANCH  => rs1_en <= '1'; rs2_en <= '1'; rd_we <= '0';
            when RV32I_OP_LOAD    => rs1_en <= '1'; rs2_en <= '0'; rd_we <= '1';
            when RV32I_OP_STORE   => rs1_en <= '1'; rs2_en <= '1'; rd_we <= '0';
            when RV32I_OP_REG_IMM => rs1_en <= '1'; rs2_en <= '0'; rd_we <= '1';
            when RV32I_OP_REG_REG => rs1_en <= '1'; rs2_en <= '1'; rd_we <= '1';
            when RV32I_OP_FENCE   => rs1_en <= '0'; rs2_en <= '0'; rd_we <= '1';
            when RV32I_OP_SYS     => rs1_en <= '1'; rs2_en <= '0'; rd_we <= '1';
            when others =>
        end case;
    end process;

--    process (instr_opcode, rs1_dat_i, rs2_dat_i, pc, pc_plus_4, imm_u, imm_i)
--    begin
--        ctrl.src1 <= rs1_dat_i;
--        ctrl.src2 <= rs2_dat_i;
--        case instr_opcode is
--            when RV32I_OP_LUI     => ctrl.src1 <= (others => '0'); ctrl.src2 <= imm_u;
--            when RV32I_OP_AUIPC   => ctrl.src1 <= pc; ctrl.src2 <= imm_u;
--            when RV32I_OP_JAL     => ctrl.src1 <= (others => '0'); ctrl.src2 <= pc_plus_4;
--            when RV32I_OP_JALR    => ctrl.src1 <= (others => '0'); ctrl.src2 <= pc_plus_4;
--            when RV32I_OP_BRANCH  => ctrl.src1 <= rs1_dat_i; ctrl.src2 <= rs2_dat_i;
--            when RV32I_OP_LOAD    =>
--            when RV32I_OP_STORE   => ctrl.src2 <= rs2_dat_i;
--            when RV32I_OP_REG_IMM => ctrl.src1 <= rs1_dat_i; ctrl.src2 <= imm_i;
--            when RV32I_OP_REG_REG => ctrl.src1 <= rs1_dat_i; ctrl.src2 <= rs2_dat_i;
--            when RV32I_OP_FENCE   =>
--            when RV32I_OP_SYS     => ctrl.src1 <= rs1_dat_i; ctrl.src2 <= imm_i;
--            when others =>
--        end case;
--    end process;

    process (instr_opcode, rs1_dat_i, rs2_dat_i, pc, pc_incr, imm_u, imm_i)
    begin
        ctrl.src1 <= (others => '-');
        ctrl.src2 <= (others => '-');
        case instr_opcode is
            when RV32I_OP_LUI     => ctrl.src1 <= (others => '0'); ctrl.src2 <= imm_u;
            when RV32I_OP_AUIPC   => ctrl.src1 <= pc; ctrl.src2 <= imm_u;
            when RV32I_OP_JAL     => ctrl.src1 <= pc; ctrl.src2 <= pc_incr;
            when RV32I_OP_JALR    => ctrl.src1 <= pc; ctrl.src2 <= pc_incr;
            when RV32I_OP_BRANCH  => ctrl.src1 <= rs1_dat_i; ctrl.src2 <= rs2_dat_i;
            when RV32I_OP_LOAD    =>
            when RV32I_OP_STORE   => ctrl.src2 <= rs2_dat_i;
            when RV32I_OP_REG_IMM => ctrl.src1 <= rs1_dat_i; ctrl.src2 <= imm_i;
            when RV32I_OP_REG_REG => ctrl.src1 <= rs1_dat_i; ctrl.src2 <= rs2_dat_i;
            when RV32I_OP_FENCE   =>
            when RV32I_OP_SYS     => if G_EXTENSION_ZICSR = TRUE then ctrl.src1 <= rs1_dat_i; ctrl.src2 <= imm_i; end if;
            when others =>
        end case;
    end process;
    ctrl.rd_adr_is_zero <= '1' when instr_dat(11 downto 7) = "00000" else '0';

    process (instr_opcode, rs1_dat_i, pc, imm_j, imm_i, imm_b, imm_s)
    begin
        ctrl.base_addr <= (others => '-');
        ctrl.imm <= (others => '-');
        case instr_opcode is
            when RV32I_OP_LUI     =>
            when RV32I_OP_AUIPC   =>
            when RV32I_OP_JAL     => ctrl.base_addr <= pc; ctrl.imm <= imm_j;
            when RV32I_OP_JALR    => ctrl.base_addr <= rs1_dat_i; ctrl.imm <= imm_i;
            when RV32I_OP_BRANCH  => ctrl.base_addr <= pc; ctrl.imm <= imm_b;
            when RV32I_OP_LOAD    => ctrl.base_addr <= rs1_dat_i; ctrl.imm <= imm_i;
            when RV32I_OP_STORE   => ctrl.base_addr <= rs1_dat_i; ctrl.imm <= imm_s;
            when RV32I_OP_REG_IMM =>
            when RV32I_OP_REG_REG =>
            when RV32I_OP_FENCE   =>
            when RV32I_OP_SYS     =>
            when others =>
        end case;
    end process;

    process (instr_opcode, instr_dat)
    begin
        ctrl.alu_arith <= '0';
        ctrl.lsu_valid <= '0';
        ctrl.shifter_en <= '0';
        ctrl.muldiv_en <= '0';
        ctrl.ecall <= '0';
        ctrl.ebreak <= '0';
        ctrl.mret <= '0';
--        ctrl.jal <= '0';
--        ctrl.branch <= '0';
--        ctrl.load <= '0';
--        ctrl.store <= '0';
        case instr_opcode is
            when RV32I_OP_LUI     =>
            when RV32I_OP_AUIPC   =>
            when RV32I_OP_JAL     =>
            when RV32I_OP_JALR    =>
            when RV32I_OP_BRANCH  =>
            when RV32I_OP_LOAD    => ctrl.lsu_valid <= '1';
            when RV32I_OP_STORE   => ctrl.lsu_valid <= '1';
            when RV32I_OP_REG_IMM =>
                case instr_funct3 is
                    when RV32I_FN3_ADD  =>
                    when RV32I_FN3_SL   => if instr_funct7 = RV32M_FN7_SL then ctrl.shifter_en <= '1'; end if;
                    when RV32I_FN3_SLT  => ctrl.alu_arith <= '1';
                    when RV32I_FN3_SLTU => ctrl.alu_arith <= '1';
                    when RV32I_FN3_XOR  =>
                    when RV32I_FN3_SR   => if instr_funct7 = RV32M_FN7_SL or instr_funct7 = RV32M_FN7_SA then ctrl.shifter_en <= '1'; end if;
                    when RV32I_FN3_OR   =>
                    when RV32I_FN3_AND  =>
                    when others =>
                end case;
            when RV32I_OP_REG_REG =>
                case instr_funct3 is
                    when RV32I_FN3_ADD  => if instr_funct7 = RV32M_FN7_SUB then ctrl.alu_arith <= '1'; end if;
                    when RV32I_FN3_SL   => if instr_funct7 = RV32M_FN7_SL then ctrl.shifter_en <= '1'; end if;
                    when RV32I_FN3_SLT  => ctrl.alu_arith <= '1';
                    when RV32I_FN3_SLTU => ctrl.alu_arith <= '1';
                    when RV32I_FN3_XOR  =>
                    when RV32I_FN3_SR   => if instr_funct7 = RV32M_FN7_SL or instr_funct7 = RV32M_FN7_SA then ctrl.shifter_en <= '1'; end if;
                    when RV32I_FN3_OR   =>
                    when RV32I_FN3_AND  =>
                    when others =>
                end case;
                if G_EXTENSION_M = TRUE and instr_funct7 = RV32M_FN7_MULDIV then ctrl.muldiv_en <= '1'; end if;
            when RV32I_OP_FENCE  =>
            when RV32I_OP_SYS    =>
                if G_EXTENSION_ZICSR = TRUE and instr_funct3 = "000" then
                    case instr_dat(31 downto 20) is
                        when CSR_FN12_ECALL  => ctrl.ecall <= '1';
                        when CSR_FN12_EBREAK => ctrl.ebreak <= '1';
                        when CSR_FN12_MRET   => ctrl.mret <= '1';
                        when others =>
                    end case;
                end if;
            when others =>
        end case;
    end process;
--    ctrl.alu_signed <= '1' when instr_funct3(2 downto 1) = "01" or instr_funct3(2 downto 1) = "10" else '0';

    gen_shifter_early_injection: if G_SHIFTER_EARLY_INJECTION = TRUE generate
        process (instr_opcode, instr_funct3)
        begin
            ctrl.rd_res_sel <= "00";
            case instr_opcode is
                when RV32I_OP_REG_IMM | RV32I_OP_REG_REG =>
                    case instr_funct3 is
                        when RV32I_FN3_SL | RV32I_FN3_SR => ctrl.rd_res_sel <= "11";
                        when RV32I_FN3_SLT | RV32I_FN3_SLTU => ctrl.rd_res_sel <= "10";
                        when RV32I_FN3_XOR | RV32I_FN3_OR | RV32I_FN3_AND => ctrl.rd_res_sel <= "01";
                        when others => ctrl.rd_res_sel <= "00";
                    end case;
                when others =>
            end case;
        end process;
    end generate gen_shifter_early_injection;
    gen_no_shifter_early_injection: if G_SHIFTER_EARLY_INJECTION = FALSE generate
        process (instr_opcode, instr_funct3)
        begin
            ctrl.rd_res_sel <= "00";
            case instr_opcode is
                when RV32I_OP_REG_IMM | RV32I_OP_REG_REG =>
                    case instr_funct3 is
                        when RV32I_FN3_XOR | RV32I_FN3_OR | RV32I_FN3_AND => ctrl.rd_res_sel(1 downto 0) <= "01";
                        when RV32I_FN3_SLT | RV32I_FN3_SLTU => ctrl.rd_res_sel(1 downto 0) <= "1-";
                        when others =>
                    end case;
                when others =>
            end case;
        end process;
    end generate gen_no_shifter_early_injection;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if pc_en = '1' then
                pc <= nxt_pc;
            end if;
        end if;
    end process;

    pc_incr <= std_logic_vector(to_unsigned(2, pc_incr'length)) when compressed = '1' and G_EXTENSION_C = TRUE else std_logic_vector(to_unsigned(4, pc_incr'length));
    pc_plus_4 <= std_logic_vector(unsigned(pc) + unsigned(pc_incr));
    nxt_pc <=
        target_pc_i when load_pc_i = '1' else
        pc_plus_4;

    pc_en <= enable_i and (load_pc_i or valid);

    ctrl.pc <= pc;

    ctrl_o <= ctrl;
    valid_o <= valid;
    compressed_o <= compressed;
    opcode_o <= opcode;

    -- DEBUG
    instr_o <= instr_dat;
end architecture rtl;