library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity instruction_decode is
    port (
        arst_i        : in std_logic;
        clk_i         : in std_logic;
        srst_i        : in std_logic;
        en_i          : in std_logic;
        pc_i          : in std_logic_vector(31 downto 0);
        instr_i       : in std_logic_vector(31 downto 0);
        instr_vld_i   : in std_logic;
        decode_rdy_o  : out std_logic;
        pc_o          : out std_logic_vector(31 downto 0);
        opcode_o      : out std_logic_vector(6 downto 0);
        rs1_adr_o     : out std_logic_vector(4 downto 0);
        rs2_adr_o     : out std_logic_vector(4 downto 0);
        rd_adr_o      : out std_logic_vector(4 downto 0);
        funct3        : out std_logic_vector(2 downto 0);
        funct7        : out std_logic_vector(6 downto 0);
        immediate_o   : out std_logic_vector(31 downto 0);
        decode_vld_o  : out std_logic;
        execute_rdy_i : in std_logic
    );
end entity instruction_decode;

architecture rtl of instruction_decode is
    signal rs1_adr, rs2_adr : std_logic_vector(4 downto 0);
    signal rdy              : std_logic;
begin
    rs1_adr_o <= instr_i(19 downto 15) when rdy = '1' else rs1_adr;
    rs2_adr_o <= instr_i(24 downto 20) when rdy = '1' else rs2_adr;
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            decode_vld_o <= '0';
            rs1_adr      <= (others => '0');
            rs2_adr      <= (others => '0');
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                decode_vld_o <= '0';
                rs1_adr      <= (others => '0');
                rs2_adr      <= (others => '0');
            else
                if en_i = '1' then
                    if execute_rdy_i = '1' then
                        rs1_adr      <= instr_i(19 downto 15);
                        rs2_adr      <= instr_i(24 downto 20);
                        decode_vld_o <= '0';
                        opcode_o     <= instr_i(6 downto 0);
                        pc_o         <= pc_i;
                        rd_adr_o     <= instr_i(11 downto 7);
                        funct3       <= instr_i(14 downto 12);
                        funct7       <= instr_i(31 downto 25);
                        case instr_i(6 downto 0) is
                            when RV32I_OP_LUI => -- U Type
                                immediate_o(31 downto 12) <= instr_i(31 downto 12);
                                immediate_o(11 downto 0)  <= (others => '0');
                                decode_vld_o              <= '1';
                            when RV32I_OP_AUIPC => -- U Type
                                immediate_o(31 downto 12) <= instr_i(31 downto 12);
                                immediate_o(11 downto 0)  <= (others => '0');
                                decode_vld_o              <= '1';

                            when RV32I_OP_JAL                    => -- J Type
                                immediate_o(31 downto 20) <= (others => instr_i(31));
                                immediate_o(19 downto 12) <= instr_i(19 downto 12);
                                immediate_o(11)           <= instr_i(20);
                                immediate_o(10 downto 5)  <= instr_i(30 downto 25);
                                immediate_o(4 downto 1)   <= instr_i(24 downto 21);
                                immediate_o(0)            <= '0';
                                decode_vld_o              <= '1';

                            when RV32I_OP_JALR                   => -- I Type
                                immediate_o(31 downto 11) <= (others => instr_i(31));
                                immediate_o(10 downto 5)  <= instr_i(30 downto 25);
                                immediate_o(4 downto 1)   <= instr_i(24 downto 21);
                                immediate_o(0)            <= instr_i(20);
                                decode_vld_o              <= '1';

                            when RV32I_OP_BRANCH                 => -- B Type
                                immediate_o(31 downto 12) <= (others => instr_i(31));
                                immediate_o(11)           <= instr_i(7);
                                immediate_o(10 downto 5)  <= instr_i(30 downto 25);
                                immediate_o(4 downto 1)   <= instr_i(11 downto 8);
                                immediate_o(0)            <= '0';
                                decode_vld_o              <= '1';

                            when RV32I_OP_LOAD                   => -- I Type
                                immediate_o(31 downto 11) <= (others => instr_i(31));
                                immediate_o(10 downto 5)  <= instr_i(30 downto 25);
                                immediate_o(4 downto 1)   <= instr_i(24 downto 21);
                                immediate_o(0)            <= instr_i(20);
                                decode_vld_o              <= '1';

                            when RV32I_OP_STORE                  => -- S Type
                                immediate_o(31 downto 11) <= (others => instr_i(31));
                                immediate_o(10 downto 5)  <= instr_i(30 downto 25);
                                immediate_o(4 downto 1)   <= instr_i(11 downto 8);
                                immediate_o(0)            <= instr_i(7);
                                decode_vld_o              <= '1';

                            when RV32I_OP_REG_IMM                => -- I Type
                                immediate_o(31 downto 11) <= (others => instr_i(31));
                                immediate_o(10 downto 5)  <= instr_i(30 downto 25);
                                immediate_o(4 downto 1)   <= instr_i(24 downto 21);
                                immediate_o(0)            <= instr_i(20);
                                decode_vld_o              <= '1';

                            when RV32I_OP_REG_REG => -- R Type
                                decode_vld_o <= '1';

                                --when RV32I_OP_FENCE =>
                                --    decode_vld_o <= '1';
                                --when RV32I_OP_SYS =>
                                --    decode_vld_o <= '1';
                            when others =>
                        end case;
                    end if;
                else
                    decode_vld_o <= '0';
                end if;
            end if;
        end if;
    end process;

    --process (clk_i, arst_i)
    --begin
    --    if arst_i = '1' then
    --        rdy <= '1';
    --    elsif rising_edge(clk_i) then
    --        if srst_i = '1' then
    --            rdy <= '1';
    --        else
    --            if execute_rdy_i = '0' then
    --                rdy <= '0';
    --            else
    --                rdy <= '1';
    --            end if;
    --        end if;
    --    end if;
    --end process;
    rdy          <= execute_rdy_i;
    decode_rdy_o <= rdy;
end architecture;