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
        ctrl_i : in execute_ctrl_t;
        compressed_i : in std_logic;
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
        multicycle_o : out std_logic
    );
end entity execute;

architecture rtl of execute is
    constant C_ENABLE_SHIFTER_DATA_PATH : boolean := G_SHIFTER_EARLY_INJECTION;
    signal valid, compressed : std_logic;
    signal rs1_adr, rs2_adr, rd_adr : std_logic_vector(4 downto 0);
    signal rd_we : std_logic;
    signal immediate : std_logic_vector(31 downto 0);
    signal funct3 : std_logic_vector(2 downto 0);
    signal funct7 : std_logic_vector(6 downto 0);
    signal alu_result_a, alu_result_b : std_logic_vector(31 downto 0);
    signal opcode : opcode_t;
    signal ctrl : execute_ctrl_t;
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
                immediate <= immediate_i;
                funct3 <= funct3_i;
                funct7 <= funct7_i;
                opcode <= opcode_i;
                compressed <= compressed_i;
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

    valid_o <= valid;
    opcode_o <= opcode;
    rd_adr_o <= rd_adr;
    rd_we_o <= rd_we and valid;
    alu_result_a_o <= alu_result_a;
    alu_result_b_o <= alu_result_b;
    immediate_o <= immediate;
    funct3_o <= funct3;
    funct7_o <= funct7;
    rs1_adr_o <= rs1_adr;
    rs2_adr_o <= rs2_adr;
    current_pc_o <= pc;
    multicycle_o <= '1' when valid = '1' and ctrl.shifter_en = '1' and G_FULL_BARREL_SHIFTER = FALSE else '0';
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
    pc_incr <= std_logic_vector(unsigned(pc) + 2) when compressed = '1' else std_logic_vector(unsigned(pc) + 4);
-- ALU
    u_alu : entity work.alu
        port map (
            arith_a_i => alu_a,
            arith_b_i => alu_b,
            signed_i => alu_signed,
            arith_op_i => alu_arith,
            logic_a_i => alu_a,
            logic_b_i => alu_b,
            logic_op_i => alu_logic,
            arith_result_o => alu_arith_r,
            logic_result_o => alu_logic_r
        );

    alu_a <= 
        pc when ctrl.alu_op_a_sel = '1' else
        rs1_dat_i;

    alu_b <= 
        rs2_dat_i when ctrl.alu_op_b_sel = '1' else
        immediate;

    alu_arith <= ctrl.alu_arith;

    alu_signed <= not funct3(0); -- SLT
    alu_logic <= funct3(1 downto 0);

    process (ctrl, alu_arith_r, alu_logic_r, shifter_data_out, pc_incr)
    begin
        if G_SHIFTER_EARLY_INJECTION = TRUE then
            case ctrl.alu_res_sel is
                when "000" => alu_result_a <= alu_arith_r(31 downto 0);
                when "001" => alu_result_a <= alu_logic_r;
                when "010" => alu_result_a <= (31 downto 1 => '0') & alu_arith_r(alu_arith_r'left);
                when "011" => alu_result_a <= shifter_data_out;
                when others => alu_result_a <= pc_incr;
            end case;
        else
            case ctrl.alu_res_sel(1 downto 0) is
                when "00" => alu_result_a <= alu_arith_r(31 downto 0);
                when "01" => alu_result_a <= alu_logic_r;
                when "10" => alu_result_a <= (31 downto 1 => '0') & alu_arith_r(alu_arith_r'left);
                when "11" => alu_result_a <= pc_incr;
                when others => alu_result_a <= (others => '-');
            end case;
        end if;
    end process;

    alu_result_b <= 
        alu_arith_r(31 downto 0) when ctrl.alu_res_sel(2) = '1' and G_SHIFTER_EARLY_INJECTION = TRUE else
        alu_arith_r(31 downto 0) when ctrl.alu_res_sel(1) = '1' and G_SHIFTER_EARLY_INJECTION = FALSE else
        rs2_dat_i;

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
    shifter_data_in <= rs1_dat_i;
    shifter_start <= 
        '1' when valid = '1' and ctrl.shifter_en = '1' and (multicycle_enable_i = '1' or G_FULL_BARREL_SHIFTER = TRUE) else
        '0';
    shifter_result_o <= shifter_data_out;
    shifter_ready_o <= shifter_ready;
    shifter_start_o <= shifter_start when G_SHIFTER_EARLY_INJECTION = FALSE else '0';

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
            a_i => rs1_dat_i,
            b_i => rs2_dat_i,
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
end architecture rtl;
