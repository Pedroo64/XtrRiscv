library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cpu is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        instr_cmd_adr_o : out std_logic_vector(31 downto 0);
        instr_cmd_vld_o : out std_logic;
        instr_cmd_rdy_i : in std_logic;
        instr_rsp_dat_i : in std_logic_vector(31 downto 0);
        instr_rsp_vld_i : in std_logic;
        data_cmd_adr_o : out std_logic_vector(31 downto 0);
        data_cmd_vld_o : out std_logic;
        data_cmd_we_o : out std_logic;
        data_cmd_siz_o : out std_logic_vector(1 downto 0);
        data_cmd_rdy_i : in std_logic;
        data_cmd_dat_o : out std_logic_vector(31 downto 0);
        data_rsp_dat_i : in std_logic_vector(31 downto 0);
        data_rsp_vld_i : in std_logic;
        external_irq_i : in std_logic;
        timer_irq_i : in std_logic
    );
end entity cpu;

architecture rtl of cpu is
    -- if
    signal if_en, if_rst, if_load_pc : std_logic;
    signal if_pc : std_logic_vector(31 downto 0);
    -- if -> id
    signal if_id_pc, if_id_instr : std_logic_vector(31 downto 0);
    signal if_id_vld : std_logic;
    -- id
    signal id_en, id_rst, id_rdy : std_logic;
    signal id_rs1_adr, id_rs2_adr : std_logic_vector(4 downto 0);
    -- id -> ex
    signal id_ex_vld, id_ex_mem_vld, id_ex_csr_vld : std_logic;
    signal id_ex_pc : std_logic_vector(31 downto 0);
    signal id_ex_opcode : std_logic_vector(6 downto 0);
    signal id_ex_immediate : std_logic_vector(31 downto 0);
    signal id_ex_funct3 : std_logic_vector(2 downto 0);
    signal id_ex_funct7 : std_logic_vector(6 downto 0);
    signal id_ex_rd_adr : std_logic_vector(4 downto 0);
    signal id_ex_csr_adr : std_logic_vector(11 downto 0);
    signal id_ex_csr_zimm : std_logic_vector(4 downto 0);
    -- ex
    signal ex_en, ex_rst, ex_rdy, ex_vld, ex_hold : std_logic;
    signal ex_rd_adr : std_logic_vector(4 downto 0);
    signal ex_rd_we : std_logic;
    signal ex_funct3 : std_logic_vector(2 downto 0);
    signal ex_funct7 : std_logic_vector(6 downto 0);
    -- ex -> mem
    signal ex_mem_adr, ex_mem_dat : std_logic_vector(31 downto 0);
    signal ex_mem_rd_adr : std_logic_vector(4 downto 0);
    signal ex_mem_vld, ex_mem_we : std_logic;
    signal ex_mem_siz : std_logic_vector(1 downto 0);
    signal ex_mem_rd_we : std_logic;
    -- mem
    signal mem_en, mem_rdy : std_logic;
    -- ex -> wb
    signal ex_wb_rd_adr : std_logic_vector(4 downto 0);
    signal ex_wb_rd_we, ex_wb_load_pc : std_logic;
    signal ex_wb_rd_dat, ex_wb_pc : std_logic_vector(31 downto 0);
    -- mem -> wb
    signal mem_wb_rd_we : std_logic;
    signal mem_wb_rd_adr : std_logic_vector(4 downto 0);
    signal mem_wb_rd_dat : std_logic_vector(31 downto 0);
    -- csr
    signal csr_en, csr_rdy : std_logic;
    -- ex -> csr
    signal ex_csr_vld, ex_csr_we : std_logic;
    signal ex_csr_dat : std_logic_vector(31 downto 0);
    signal ex_csr_rd_adr : std_logic_vector(4 downto 0);
    signal ex_csr_funct3 : std_logic_vector(2 downto 0);
    signal ex_csr_adr : std_logic_vector(11 downto 0);
    signal ex_csr_mret, ex_csr_ecall : std_logic;
    -- csr -> wb
    signal csr_wb_rd_we : std_logic;
    signal csr_wb_rd_dat : std_logic_vector(31 downto 0);
    signal csr_wb_rd_adr : std_logic_vector(4 downto 0);
    signal csr_wb_load_pc : std_logic;
    signal csr_wb_pc : std_logic_vector(31 downto 0);
    -- wb
    signal wb_en, wb_ex_rdy, wb_csr_rdy : std_logic;
    signal wb_rd_adr : std_logic_vector(4 downto 0);
    signal wb_rd_we, wb_load_pc : std_logic; 
    signal wb_rd_dat, wb_pc : std_logic_vector(31 downto 0);
    -- reg file
    signal rs1_adr, rs2_adr, rd_adr : std_logic_vector(4 downto 0);
    signal rs1_dat, rs2_dat, rd_dat : std_logic_vector(31 downto 0);
    signal rd_we : std_logic;
    -- control unit
    signal cu_if_rst, cu_id_rst, cu_ex_rst : std_logic;
    signal cu_if_en, cu_id_en, cu_ex_en : std_logic;
    signal cu_branching : std_logic;
begin
-- Fetch
    if_rst <= cu_if_rst or srst_i;
    if_en <= cu_if_en;
    if_load_pc <= wb_load_pc;
    if_pc <= wb_pc;
    u_if : entity work.instruction_fecth
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => if_rst,
            en_i => if_en, decode_rdy_i => id_rdy,
            load_pc_i => if_load_pc, pc_i => if_pc,
            cmd_adr_o => instr_cmd_adr_o, cmd_vld_o => instr_cmd_vld_o, cmd_rdy_i => instr_cmd_rdy_i, rsp_dat_i => instr_rsp_dat_i, rsp_vld_i => instr_rsp_vld_i,
            pc_o => if_id_pc, instr_o => if_id_instr, instr_vld_o => if_id_vld);
-- Decode
    id_rst <= cu_id_rst or srst_i;
    id_en <= cu_id_en;
    u_id : entity work.instruction_decode
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => id_rst,
            en_i => id_en, decode_rdy_o => id_rdy, execute_rdy_i => ex_rdy,
            pc_i => if_id_pc, instr_i => if_id_instr, instr_vld_i => if_id_vld,
            rs1_adr_o => id_rs1_adr, rs2_adr_o => id_rs2_adr,
            pc_o => id_ex_pc, opcode_o => id_ex_opcode, rd_adr_o => id_ex_rd_adr,
            funct3 => id_ex_funct3, funct7 => id_ex_funct7, immediate_o => id_ex_immediate,
            csr_adr_o => id_ex_csr_adr, csr_zimm_o => id_ex_csr_zimm,
            vld_o => id_ex_vld, mem_vld_o => id_ex_mem_vld, csr_vld_o => id_ex_csr_vld);

-- Register file
    rs1_adr <= id_rs1_adr;
    rs2_adr <= id_rs2_adr;
    rd_adr <= wb_rd_adr;
    rd_we <= wb_rd_we;
    rd_dat <= wb_rd_dat;
    u_regfile : entity work.regfile
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => srst_i,
            rs1_adr_i => rs1_adr, rs1_dat_o => rs1_dat, rs2_adr_i => rs2_adr, rs2_dat_o => rs2_dat,
            rd_adr_i => rd_adr, rd_we_i => rd_we, rd_dat_i => rd_dat);
          
-- Execute      
    ex_rst <= cu_ex_rst or srst_i;
    ex_en <= cu_ex_en;
--    u_ex : entity work.execute
--        port map (
--            arst_i => arst_i, clk_i => clk_i, srst_i => ex_rst,
--            en_i => ex_en, vld_i => id_ex_vld, mem_vld_i => id_ex_mem_vld, mem_rdy_i => mem_rdy, wb_rdy_i => wb_ex_rdy, vld_o => ex_vld, rdy_o => ex_rdy,
--            pc_i => id_ex_pc, rs1_dat_i => rs1_dat, rs2_dat_i => rs2_dat,
--            opcode_i => id_ex_opcode, immediate_i => id_ex_immediate, funct3_i => id_ex_funct3, funct7_i => id_ex_funct7,
--            rd_adr_i => id_ex_rd_adr, rd_we_o => ex_wb_rd_we,
--            rd_adr_o => ex_wb_rd_adr, rd_dat_o => ex_wb_rd_dat,
--            load_pc_o => ex_wb_load_pc, pc_o => ex_wb_pc,
--            mem_rd_adr_o => ex_mem_rd_adr, mem_cmd_adr_o => ex_mem_adr, mem_cmd_vld_o => ex_mem_vld, mem_cmd_we_o => ex_mem_we, mem_cmd_dat_o => ex_mem_dat, mem_cmd_siz_o => ex_mem_siz,
--            csr_vld_i => id_ex_csr_vld, csr_rdy_i => csr_rdy,
--            csr_adr_i => id_ex_csr_adr, csr_zimm_i => id_ex_csr_zimm, 
--            csr_adr_o => ex_csr_adr, csr_vld_o => ex_csr_vld, csr_we_o => ex_csr_we, csr_dat_o => ex_csr_dat, csr_rd_adr_o => ex_csr_rd_adr, csr_funct3_o => ex_csr_funct3,
--            mret_o => ex_csr_mret, ecall_o => ex_csr_ecall);

            u_ex : entity work.execute
                port map (
                    arst_i => arst_i,
                    clk_i => clk_i,
                    srst_i => ex_rst,
                    en_i => ex_en,
                    hold_i => ex_hold,
                    valid_i => id_ex_vld,
                    pc_i => id_ex_pc,
                    opcode_i => id_ex_opcode,
                    rs1_dat_i => rs1_dat,
                    rs2_dat_i => rs2_dat,
                    immediate_i => id_ex_immediate,
                    funct3_i => id_ex_funct3,
                    funct7_i => id_ex_funct7,
                    csr_zimm_i => id_ex_csr_zimm,
                    rd_adr_i => id_ex_rd_adr,
                    rd_we_o => ex_rd_we,
                    rd_adr_o => ex_rd_adr,
                    rd_dat_o => open,
                    funct3_o => ex_funct3,
                    funct7_o => ex_funct7,
                    pc_o => ex_wb_pc,
                    load_pc_o => ex_wb_load_pc,
                    valid_o => ex_vld,
                    write_back_valid_o => open,
                    write_back_rd_adr_o => ex_wb_rd_adr,
                    write_back_rd_dat_o => ex_wb_rd_dat,
                    write_back_rd_we_o => ex_wb_rd_we,
                    write_back_ready_i => wb_ex_rdy,
                    memory_valid_o => ex_mem_vld,
                    memory_rd_adr_o => ex_mem_rd_adr,
                    memory_address_o => ex_mem_adr,
                    memory_data_o => ex_mem_dat,
                    memory_size_o => ex_mem_siz,
                    memory_we_o => ex_mem_we,
                    memory_ready_i => mem_rdy,
                    csr_valid_o => ex_csr_vld,
                    csr_address_o => ex_csr_adr,
                    csr_data_o => ex_csr_dat,
                    csr_rd_adr_o => ex_csr_rd_adr,
                    csr_ready_i => csr_rdy,
                    ecall_o => ex_csr_ecall,
                    mret_o => ex_csr_mret,
                    ready_o => ex_rdy
                );
          
    ex_mem_rd_we <= 
        '1' when ex_mem_vld = '1' and ex_mem_we = '0' else 
        '0';

-- memory
    mem_en <= '1';
    u_mem : entity work.memory
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => srst_i,
            en_i => mem_en, vld_i => ex_mem_vld, rdy_o => mem_rdy,
            adr_i => ex_mem_adr, we_i => ex_mem_we, dat_i => ex_mem_dat, siz_i => ex_mem_siz,
            rd_adr_i => ex_mem_rd_adr, rd_adr_o => mem_wb_rd_adr, rd_we_o => mem_wb_rd_we, rd_dat_o => mem_wb_rd_dat,
            cmd_adr_o => data_cmd_adr_o, cmd_vld_o => data_cmd_vld_o, cmd_we_o => data_cmd_we_o, cmd_siz_o => data_cmd_siz_o, cmd_dat_o => data_cmd_dat_o,
            cmd_rdy_i => data_cmd_rdy_i, rsp_vld_i => data_rsp_vld_i, rsp_dat_i => data_rsp_dat_i);

-- csr
    csr_en <= '1';
    u_csr : entity work.csr
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => srst_i,
            en_i => csr_en, rdy_o => csr_rdy, wb_rdy_i => wb_csr_rdy,
            vld_i => ex_csr_vld, we_i => '1', adr_i => ex_csr_adr, funct3_i => ex_funct3, dat_i => ex_csr_dat,
            rd_adr_i => ex_csr_rd_adr, rd_adr_o => csr_wb_rd_adr, rd_dat_o => csr_wb_rd_dat, rd_we_o => csr_wb_rd_we,
            branching_i => cu_branching,
            id_vld_i => id_ex_vld, id_pc_i => id_ex_pc, 
            ex_vld_i => ex_vld, ex_pc_i => ex_wb_pc, pc_o => csr_wb_pc, load_pc_o => csr_wb_load_pc,
            ex_rd_we_i => ex_wb_rd_we, ex_load_pc_i => ex_wb_load_pc,
            mret_i => ex_csr_mret, ecall_i => ex_csr_ecall, external_irq_i => external_irq_i, timer_irq_i => timer_irq_i);

-- writeback
    wb_en <= '1';
    u_wb : entity work.writeback
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => srst_i,
            en_i => wb_en, ex_rdy_o => wb_ex_rdy, csr_rdy_o => wb_csr_rdy,
            mem_rd_adr_i => mem_wb_rd_adr, mem_rd_we_i => mem_wb_rd_we, mem_rd_dat_i => mem_wb_rd_dat,
            csr_rd_adr_i => csr_wb_rd_adr, csr_rd_we_i => csr_wb_rd_we, csr_rd_dat_i => csr_wb_rd_dat, 
            csr_load_pc_i => csr_wb_load_pc, csr_pc_i => csr_wb_pc,
            ex_load_pc_i => ex_wb_load_pc, ex_pc_i => ex_wb_pc, ex_rd_adr_i => ex_wb_rd_adr, ex_rd_we_i => ex_wb_rd_we, ex_rd_dat_i => ex_wb_rd_dat,
            rd_adr_o => wb_rd_adr, rd_we_o => wb_rd_we, rd_dat_o => wb_rd_dat, load_pc_o => wb_load_pc, pc_o => wb_pc);

-- control unit
    u_cu : entity work.control_unit
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => srst_i,
            opcode_i => id_ex_opcode, rs1_adr_i => rs1_adr, rs2_adr_i => rs2_adr, funct3_i => id_ex_funct3,
            ex_load_pc_i => ex_wb_load_pc, ex_rd_adr_i => ex_rd_adr, ex_rd_we_i => ex_rd_we, ex_vld_i => ex_vld,
--            ex_mem_rd_adr_i => ex_mem_rd_adr, ex_mem_rd_we_i => ex_mem_rd_we,
            wb_load_pc_i => wb_load_pc, wb_rd_adr_i => wb_rd_adr, wb_rd_we_i => wb_rd_we,
            csr_load_pc_i => csr_wb_load_pc,
            branching_o => cu_branching,
            if_rst_o => cu_if_rst, if_en_o => cu_if_en,
            id_rst_o => cu_id_rst, id_en_o => cu_id_en,
            ex_rst_o => cu_ex_rst, ex_en_o => cu_ex_en, ex_hold_o => ex_hold);

end architecture rtl;
