add wave -group "cpu" -ports /tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/*;
add wave -group "fetch" -position insertpoint /tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/u_fetch/*;
add wave -group "decode" -position insertpoint /tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/u_decode/*;
add wave -group "regfile" -position insertpoint /tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/u_regfile/*;
add wave -group "execute" -position insertpoint /tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/u_execute/*;
add wave -group "memory" -position insertpoint /tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/u_memory/*;
add wave -group "writeback" -position insertpoint /tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/u_writeback/*;
add wave -group "ctl" -position insertpoint /tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/u_control_unit/*;
add wave -group "branch" -position insertpoint /tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/u_branch_unit/*;
add wave -group "lsu" -position insertpoint /tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/u_lsu/*;
if {[find instances /tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/gen_csr/u_csr] != ""} {
    add wave -group "csr" -position insertpoint /tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/gen_csr/u_csr/*
}
add wave -group "verif" -position insertpoint /tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/gen_verif/u_cpu_checker/*;
config wave -signalnamewidth 1