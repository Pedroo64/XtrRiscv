library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity instruction_decode is
    generic (
        G_EXTENSION_C : boolean := FALSE;
        G_EXTENSION_M : boolean := FALSE;
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
        valid_o : out std_logic;
        opcode_o : out opcode_t;
        opcode_type_o : out opcode_type_t;
        rs1_adr_o : out std_logic_vector(4 downto 0);
        rs1_en_o : out std_logic;
        rs2_adr_o : out std_logic_vector(4 downto 0);
        rs2_en_o : out std_logic;
        rd_adr_o : out std_logic_vector(4 downto 0);
        rd_we_o : out std_logic;
        immediate_o : out std_logic_vector(31 downto 0);
        funct3_o : out std_logic_vector(2 downto 0);
        funct7_o : out std_logic_vector(6 downto 0);
        compressed_o : out std_logic;
        instr_o : out std_logic_vector(31 downto 0);
        ctrl_o : out execute_ctrl_t
    );
end entity instruction_decode;

architecture rtl of instruction_decode is
    signal fetched_instr, decompressed_instr, instr_dat : std_logic_vector(31 downto 0);
    signal instr_opcode : std_logic_vector(6 downto 0);
    signal rs1_en, rs2_en : std_logic;
    signal rd_we, compressed : std_logic;
    signal opcode : opcode_t;
    signal opcode_type : opcode_type_t;
    signal ctrl : execute_ctrl_t;
    alias instr_funct3 : std_logic_vector(2 downto 0) is instr_dat(14 downto 12);
    alias instr_funct7 : std_logic_vector(6 downto 0) is instr_dat(31 downto 25);
    signal rs1_adr : std_logic_vector(4 downto 0);
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
                compressed <= compressed_i;
            end if;
        end if;
    end process;

    instr_opcode <= instr_dat(6 downto 2) & "11";

    opcode.illegal <= '0';
-- opcode decode
    process (instr_opcode, instr_dat)
    begin
        opcode.lui <= '0';
        opcode.auipc <= '0';
        opcode.jal <= '0';
        opcode.jalr <= '0';
        opcode.branch <= '0';
        opcode.load <= '0';
        opcode.store <= '0';
        opcode.reg_imm <= '0';
        opcode.reg_reg <= '0';
        opcode.fence <= '0';
        opcode.sys <= '0';
        opcode_type.r_type <= '0';
        opcode_type.i_type <= '0';
        opcode_type.s_type <= '0';
        opcode_type.b_type <= '0';
        opcode_type.u_type <= '0';
        opcode_type.j_type <= '0';
        immediate_o <= (others => '-');
        rd_we <= '0';
        case instr_opcode is
            when RV32I_OP_LUI =>
                opcode.lui <= '1';
                opcode_type.u_type <= '1';
                immediate_o <= instr_dat(31 downto 12) & (11 downto 0 => '0');
                rd_we <= '1';
            when RV32I_OP_AUIPC =>
                opcode_type.u_type <= '1';
                opcode.auipc <= '1'; 
                immediate_o <= instr_dat(31 downto 12) & (11 downto 0 => '0');
                rd_we <= '1';
            when RV32I_OP_JAL =>
                opcode.jal <= '1';
                opcode_type.j_type <= '1';
                immediate_o <= (31 downto 20 => instr_dat(31)) & instr_dat(19 downto 12) & instr_dat(20) & instr_dat(30 downto 21) & '0';
                rd_we <= '1';
            when RV32I_OP_JALR =>
                opcode.jalr <= '1';
                opcode_type.i_type <= '1';
                immediate_o <= (31 downto 11 => instr_dat(31)) & instr_dat(30 downto 20);
                rd_we <= '1';
            when RV32I_OP_BRANCH =>
                opcode.branch <= '1';
                opcode_type.b_type <= '1';
                immediate_o <= (31 downto 12 => instr_dat(31)) & instr_dat(7) & instr_dat(30 downto 25) & instr_dat(11 downto 8) & '0';
            when RV32I_OP_LOAD =>
                opcode.load <= '1';
                opcode_type.i_type <= '1';
                immediate_o <= (31 downto 11 => instr_dat(31)) & instr_dat(30 downto 20);
                rd_we <= '1';
            when RV32I_OP_STORE =>
                opcode.store <= '1';
                opcode_type.s_type <= '1';
                immediate_o <= (31 downto 11 => instr_dat(31)) & instr_dat(30 downto 25) & instr_dat(11 downto 7);
            when RV32I_OP_REG_IMM =>
                opcode.reg_imm <= '1';
                opcode_type.i_type <= '1';
                immediate_o <= (31 downto 11 => instr_dat(31)) & instr_dat(30 downto 20);
                rd_we <= '1';
            when RV32I_OP_REG_REG =>
                opcode.reg_reg <= '1';
                opcode_type.r_type <= '1';
                rd_we <= '1';
            when RV32I_OP_FENCE =>
                opcode.fence <= '1';
            when RV32I_OP_SYS =>
                opcode.sys <= '1';
                opcode_type.i_type <= '1';
                immediate_o <= (31 downto 11 => instr_dat(31)) & instr_dat(30 downto 20);
                rd_we <= '1';
            when others =>
        end case;
    end process;

    process (instr_opcode, instr_funct3, instr_funct7)
    begin
        ctrl.alu_op_a_sel <= '0';
        ctrl.alu_op_b_sel <= '0';
        ctrl.alu_arith <= '0';
        ctrl.shifter_en <= '0';
        ctrl.muldiv_en <= '0';
        case instr_opcode is
            when RV32I_OP_LUI     =>
            when RV32I_OP_AUIPC   => ctrl.alu_op_a_sel <= '1';
            when RV32I_OP_JAL     => ctrl.alu_op_a_sel <= '1';
            when RV32I_OP_JALR    =>
            when RV32I_OP_BRANCH  => ctrl.alu_op_a_sel <= '1';
            when RV32I_OP_LOAD    =>
            when RV32I_OP_STORE   =>
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
                ctrl.alu_op_b_sel <= '1';
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
            when others =>
        end case;
    end process;

    gen_shifter_early_injection: if G_SHIFTER_EARLY_INJECTION = TRUE generate
        process (instr_opcode, instr_funct3)
        begin
            ctrl.alu_res_sel <= "000";
            case instr_opcode is
                when RV32I_OP_JAL | RV32I_OP_JALR | RV32I_OP_BRANCH =>
                    ctrl.alu_res_sel <= "1--";
                when RV32I_OP_REG_IMM | RV32I_OP_REG_REG =>
                    case instr_funct3 is
                        when RV32I_FN3_SL | RV32I_FN3_SR => ctrl.alu_res_sel <= "011";
                        when RV32I_FN3_SLT | RV32I_FN3_SLTU => ctrl.alu_res_sel <= "010";
                        when RV32I_FN3_XOR | RV32I_FN3_OR | RV32I_FN3_AND => ctrl.alu_res_sel <= "001";
                        when others => ctrl.alu_res_sel <= "000";
                    end case;
                when others =>
            end case;
        end process;
    end generate gen_shifter_early_injection;
    gen_no_shifter_early_injection: if G_SHIFTER_EARLY_INJECTION = FALSE generate
        process (instr_opcode, instr_funct3)
        begin
            ctrl.alu_res_sel <= "-00";
            case instr_opcode is
                when RV32I_OP_JAL | RV32I_OP_JALR | RV32I_OP_BRANCH =>
                    ctrl.alu_res_sel(1 downto 0) <= "11";
                when RV32I_OP_REG_IMM | RV32I_OP_REG_REG =>
                    case instr_funct3 is
                        when RV32I_FN3_XOR | RV32I_FN3_OR | RV32I_FN3_AND => ctrl.alu_res_sel(1 downto 0) <= "01";
                        when RV32I_FN3_SLT | RV32I_FN3_SLTU => ctrl.alu_res_sel(1 downto 0) <= "10";
                        when others =>
                    end case;
                when others =>
            end case;
        end process;
    end generate gen_no_shifter_early_injection;

    process (instr_opcode)
    begin
        rs1_en <= '0';
        rs2_en <= '0';
        case instr_opcode is
            when RV32I_OP_LUI =>
            when RV32I_OP_AUIPC =>
            when RV32I_OP_JAL =>
            when RV32I_OP_JALR =>
                rs1_en <= '1';
            when RV32I_OP_BRANCH =>
                rs1_en <= '1';
                rs2_en <= '1';
            when RV32I_OP_LOAD =>
                rs1_en <= '1';
            when RV32I_OP_STORE =>
                rs1_en <= '1';
                rs2_en <= '1';
            when RV32I_OP_REG_IMM =>
                rs1_en <= '1';
            when RV32I_OP_REG_REG =>
                rs1_en <= '1';
                rs2_en <= '1';
            when RV32I_OP_FENCE =>
            when RV32I_OP_SYS =>
                rs1_en <= '1';
            when others =>
        end case;
    end process;

    opcode_o <= opcode;

    rs1_adr <= (others => '0') when opcode.lui = '1' else instr_dat(19 downto 15);
    rs1_adr_o <= rs1_adr;
    rs2_adr_o <= instr_dat(24 downto 20);
    rd_adr_o <= instr_dat(11 downto 7);

    funct3_o <= instr_dat(14 downto 12);
    funct7_o <= instr_dat(31 downto 25);
    rd_we_o <= rd_we;
    opcode_type_o <= opcode_type;
    compressed_o <= compressed;

    rs1_en_o <= rs1_en;
    rs2_en_o <= rs2_en;

    ctrl_o <= ctrl;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            valid_o <= '0';
        elsif rising_edge(clk_i) then
            if enable_i = '1' then
                if flush_i = '1' then
                    valid_o <= '0';
                else
                    valid_o <= valid_i;
                end if;
            end if;
        end if;
    end process;

    -- DEBUG
    instr_o <= instr_dat;
end architecture rtl;