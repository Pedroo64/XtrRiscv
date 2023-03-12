library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity cpu is
    generic (
        G_BOOT_ADDRESS : std_logic_vector(31 downto 0) := (others => '0');
        G_WRITEBACK_BYPASS : boolean := FALSE;
        G_FULL_BARREL_SHIFTER : boolean := FALSE
    );
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
    signal id_rs1_adr_latch, id_rs2_adr_latch : std_logic_vector(4 downto 0);
    -- id -> ex
    signal id_ex_vld, id_ex_rd_we : std_logic;
    signal id_ex_pc : std_logic_vector(31 downto 0);
    signal id_ex_opcode : opcode_t;
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
    signal ex_rd_dat : std_logic_vector(31 downto 0);
    signal mret, ecall, ebreak : std_logic;
    -- ex -> mem
    signal ex_mem_adr, ex_mem_dat : std_logic_vector(31 downto 0);
    signal ex_mem_rd_adr : std_logic_vector(4 downto 0);
    signal ex_mem_vld, ex_mem_we : std_logic;
    signal ex_mem_siz : std_logic_vector(2 downto 0);
    signal ex_mem_rd_we : std_logic;
    -- mem
    signal mem_en, mem_rdy : std_logic;
    -- ex -> wb
    signal ex_wb_rd_adr : std_logic_vector(4 downto 0);
    signal ex_wb_vld, ex_wb_rd_we, ex_wb_load_pc : std_logic;
    signal ex_wb_rd_dat, ex_wb_pc : std_logic_vector(31 downto 0);
    -- mem -> wb
    signal mem_wb_rd_we : std_logic;
    signal mem_wb_rd_adr : std_logic_vector(4 downto 0);
    signal mem_wb_rd_dat : std_logic_vector(31 downto 0);
    -- csr
    signal csr_en, csr_rdy : std_logic;
    signal mtvec, mie, mstatus, mcause : std_logic_vector(31 downto 0);
    -- ex -> csr
    signal ex_csr_vld, ex_csr_we : std_logic;
    signal ex_csr_dat : std_logic_vector(31 downto 0);
    signal ex_csr_rd_adr : std_logic_vector(4 downto 0);
    signal ex_csr_funct3 : std_logic_vector(2 downto 0);
    signal ex_csr_adr : std_logic_vector(11 downto 0);
    -- csr -> wb
    signal csr_wb_rd_we, csr_wb_vld : std_logic;
    signal csr_wb_rd_dat : std_logic_vector(31 downto 0);
    signal csr_wb_rd_adr : std_logic_vector(4 downto 0);
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
    signal cu_rs1_wb_bypass, cu_rs2_wb_bypass : std_logic;
    -- interrupt handler
    signal exception_valid, exception_taken, exception_exit : std_logic;
    signal ex_exception_pc, csr_exception_pc : std_logic_vector(31 downto 0);
    signal cause_external_irq : std_logic;
    signal cause_timer_irq : std_logic;
begin
-- Fetch
    if_rst <= cu_if_rst or srst_i;
    if_en <= '1';

    u_if : entity work.instruction_fecth
        generic map (
            G_BOOT_ADDRESS => G_BOOT_ADDRESS
        )
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => if_rst,
            en_i => if_en, decode_rdy_i => id_rdy,
            load_pc_i => if_load_pc, pc_i => if_pc,
            cmd_adr_o => instr_cmd_adr_o, cmd_vld_o => instr_cmd_vld_o, cmd_rdy_i => instr_cmd_rdy_i, rsp_dat_i => instr_rsp_dat_i, rsp_vld_i => instr_rsp_vld_i,
            pc_o => if_id_pc, instr_o => if_id_instr, instr_vld_o => if_id_vld);
-- Decode
    id_rst <= cu_id_rst or srst_i;
    id_en <= '1';
    u_id : entity work.instruction_decode
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => id_rst,
            en_i => id_en,
            vld_i => if_id_vld,
            instr_dat_i => if_id_instr,
            pc_i => if_id_pc,
            opcode_o => id_ex_opcode,
            rs1_adr_o => id_rs1_adr,
            rs2_adr_o => id_rs2_adr,
            rd_adr_o => id_ex_rd_adr,
            rd_we_o => id_ex_rd_we,
            pc_o => id_ex_pc,
            immediate_o => id_ex_immediate,
            funct3_o => id_ex_funct3,
            funct7_o => id_ex_funct7,
            rdy_o => id_rdy,
            vld_o => id_ex_vld,
            rdy_i => ex_rdy,
            rs1_adr_latch_o => id_rs1_adr_latch,
            rs2_adr_latch_o => id_rs2_adr_latch
        );

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
block_execute : block
    signal execute_ready : std_logic;
    signal rs1, rs2 : std_logic_vector(31 downto 0);
begin
    ex_rst <= srst_i;
    ex_en <= cu_ex_en and id_ex_vld and execute_ready;

    ex_rdy <= cu_ex_en and execute_ready;

    rs1 <= 
        wb_rd_dat when cu_rs1_wb_bypass = '1' else
        rs1_dat;
    rs2 <= 
        wb_rd_dat when cu_rs2_wb_bypass = '1' else
        rs2_dat;

    u_execute : entity work.execute
        generic map (
            G_FULL_BARREL_SHIFTER => G_FULL_BARREL_SHIFTER
        )
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => ex_rst,
            enable_i => ex_en,
            valid_i => id_ex_vld,
            pc_i => id_ex_pc,
            opcode_i => id_ex_opcode,
            immediate_i => id_ex_immediate,
            rs1_adr_i => id_rs1_adr_latch,
            rs1_dat_i => rs1,
            rs2_adr_i => id_rs2_adr_latch,
            rs2_dat_i => rs2,
            rd_adr_i => id_ex_rd_adr,
            rd_we_i => id_ex_rd_we,
            funct3_i => id_ex_funct3,
            funct7_i => id_ex_funct7,
            rd_adr_o => ex_rd_adr,
            rd_dat_o => ex_rd_dat,
            rd_we_o => ex_rd_we,
            funct3_o => ex_funct3,
            funct7_o => ex_funct7,
            writeback_valid_o => ex_wb_vld,
            writeback_ready_i => wb_ex_rdy,
            pc_o => if_pc,
            load_pc_o => if_load_pc,
            memory_rd_adr_o => ex_mem_rd_adr,
            memory_valid_o => ex_mem_vld,
            memory_address_o => ex_mem_adr,
            memory_data_o => ex_mem_dat,
            memory_we_o => ex_mem_we,
            memory_size_o => ex_mem_siz,
            memory_ready_i => mem_rdy,
            csr_rd_adr_o => ex_csr_rd_adr,
            csr_valid_o => ex_csr_vld,
            csr_address_o => ex_csr_adr,
            csr_data_o => ex_csr_dat,
            csr_ready_i => csr_rdy,
            exception_valid_i => exception_valid,
            trap_vector_i => mtvec,
            exception_pc_i => csr_exception_pc,
            exception_pc_o => ex_exception_pc,
            exception_taken_o => exception_taken,
            exception_exit_o => exception_exit,
            mret_o => mret,
            ecall_o => ecall,
            ebreak_o => ebreak,
            ready_o => execute_ready
        );
    
end block;

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
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => srst_i,
            valid_i => ex_csr_vld,
            rd_adr_i => ex_csr_rd_adr,
            address_i => ex_csr_adr,
            data_i => ex_csr_dat,
            funct3_i => ex_funct3,
            valid_o => csr_wb_vld,
            rd_adr_o => csr_wb_rd_adr,
            rd_dat_o => csr_wb_rd_dat,
            rd_we_o => csr_wb_rd_we,
            ready_i => wb_csr_rdy,
            ready_o => csr_rdy,
            exception_pc_i => ex_exception_pc,
            exception_taken_i => exception_taken,
            exception_exit_i => exception_exit,
            ecall_i => ecall,
            ebreak_i => ebreak,
            cause_external_irq_i => cause_external_irq,
            cause_timer_irq_i => cause_timer_irq,
            mstatus_o => mstatus,
            mie_o => mie,
            mtvec_o => mtvec,
            mepc_o => csr_exception_pc
        );

-- writeback
    ex_wb_rd_we <= ex_rd_we and ex_wb_vld;
    u_wb : entity work.writeback
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => srst_i,
            memory_rd_we_i => mem_wb_rd_we,
            memory_rd_adr_i => mem_wb_rd_adr,
            memory_rd_dat_i => mem_wb_rd_dat,
            execute_rd_we_i => ex_wb_rd_we,
            execute_rd_adr_i => ex_rd_adr,
            execute_rd_dat_i => ex_rd_dat,
            csr_rd_we_i => csr_wb_rd_we,
            csr_rd_adr_i => csr_wb_rd_adr,
            csr_rd_dat_i => csr_wb_rd_dat,
            rd_we_o => wb_rd_we,
            rd_adr_o => wb_rd_adr,
            rd_dat_o => wb_rd_dat,
            execute_ready_o => wb_ex_rdy,
            csr_ready_o => wb_csr_rdy
        );

-- control unit
    u_control_unit : entity work.control_unit
        generic map (
            G_WRITEBACK_BYPASS => G_WRITEBACK_BYPASS
        )
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => srst_i,
            decode_valid_i => id_ex_vld,
            decode_opcode_i => id_ex_opcode,
            decode_rs1_adr_i => id_rs1_adr_latch,
            decode_rs2_adr_i => id_rs2_adr_latch,
            decode_rd_adr_i => id_ex_rd_adr,
            decode_rd_we_i => id_ex_rd_we,
            decode_funct3_i => id_ex_funct3,
            execute_ready_i => ex_rdy,
            execute_branch_i => if_load_pc,
            writeback_rd_adr_i => wb_rd_adr,
            writeback_rd_we_i => wb_rd_we,
            writeback_branch_i => if_load_pc,
            fetch_reset_o => cu_if_rst,
            decode_reset_o => cu_id_rst,
            execute_enable_o => cu_ex_en,
            rs1_writeback_bypass_o => cu_rs1_wb_bypass,
            rs2_writeback_bypass_o => cu_rs2_wb_bypass
        );

-- interrupt handler
    u_interrupt_handler : entity work.interrupt_handler
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => srst_i,
            mstatus_i => mstatus,
            mie_i => mie,
            external_irq_i => external_irq_i,
            timer_irq_i => timer_irq_i,
            exception_valid_o => exception_valid,
            cause_external_irq_o => cause_external_irq,
            cause_timer_irq_o => cause_timer_irq
        );

end architecture rtl;
