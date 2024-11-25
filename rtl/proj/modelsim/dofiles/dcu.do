onerror {resume}

set dcu_path /tb_dcu/u_dcu

add wave -noupdate ${dcu_path}/arst_i
add wave -noupdate ${dcu_path}/clk_i

add wave -noupdate -group "cpu if" ${dcu_path}/cpu_adr_i
add wave -noupdate -group "cpu if" ${dcu_path}/cpu_dat_i
add wave -noupdate -group "cpu if" ${dcu_path}/cpu_siz_i
add wave -noupdate -group "cpu if" ${dcu_path}/cpu_wr_i
add wave -noupdate -group "cpu if" ${dcu_path}/cpu_vld_i
add wave -noupdate -group "cpu if" ${dcu_path}/cpu_rdy_o
add wave -noupdate -group "cpu if" ${dcu_path}/cpu_dat_o
add wave -noupdate -group "cpu if" ${dcu_path}/cpu_vld_o

add wave -noupdate -group "biu if" ${dcu_path}/biu_adr_o
add wave -noupdate -group "biu if" ${dcu_path}/biu_dat_o
add wave -noupdate -group "biu if" ${dcu_path}/biu_wr_o
add wave -noupdate -group "biu if" ${dcu_path}/biu_vld_o
add wave -noupdate -group "biu if" ${dcu_path}/biu_rdy_i
add wave -noupdate -group "biu if" ${dcu_path}/biu_dat_i
add wave -noupdate -group "biu if" ${dcu_path}/biu_vld_i

add wave -noupdate -group "cache" ${dcu_path}/cpu_vld_q
add wave -noupdate -group "cache" ${dcu_path}/cpu_miss_q

add wave -noupdate -group "cache" ${dcu_path}/tag_ram
add wave -noupdate -group "cache" ${dcu_path}/data_ram
add wave -noupdate -group "cache" ${dcu_path}/cache_init_addr_q
add wave -noupdate -group "cache" ${dcu_path}/cache_init_done
add wave -noupdate -group "cache" ${dcu_path}/cache_vld_q
add wave -noupdate -group "cache" ${dcu_path}/cache_tag_addr
add wave -noupdate -group "cache" ${dcu_path}/cache_tag_dirty
add wave -noupdate -group "cache" ${dcu_path}/cache_tag_vld
add wave -noupdate -group "cache" ${dcu_path}/cache_tag_match
add wave -noupdate -group "cache" ${dcu_path}/cache_tag_hit
add wave -noupdate -group "cache" ${dcu_path}/cache_tag_miss
add wave -noupdate -group "cache" ${dcu_path}/cache_cpu_addr_q
add wave -noupdate -group "cache" ${dcu_path}/cache_biu_vld
add wave -noupdate -group "cache" ${dcu_path}/cache_biu_rdy
add wave -noupdate -group "cache" ${dcu_path}/cache_cpu_vld
add wave -noupdate -group "cache" ${dcu_path}/cache_cpu_rdy
add wave -noupdate -group "cache" ${dcu_path}/cache_stb_vld
add wave -noupdate -group "cache" ${dcu_path}/cache_stb_rdy
add wave -noupdate -group "cache" ${dcu_path}/cache_priority_stb
add wave -noupdate -group "cache" -divider "New Divider"

add wave -noupdate -group "stb" ${dcu_path}/stb_slot_wr
add wave -noupdate -group "stb" ${dcu_path}/stb_full
add wave -noupdate -group "stb" ${dcu_path}/stb_slot_nxt_state
add wave -noupdate -group "stb" ${dcu_path}/stb_slot_state_q
add wave -noupdate -group "stb" ${dcu_path}/stb_slot_vld_q
add wave -noupdate -group "stb" ${dcu_path}/stb_slot_addr_q
add wave -noupdate -group "stb" ${dcu_path}/stb_slot_data_q
add wave -noupdate -group "stb" ${dcu_path}/stb_slot_strb_q
add wave -noupdate -group "stb" ${dcu_path}/stb_slot_dirty_q
add wave -noupdate -group "stb" ${dcu_path}/stb_tag_wr_vld
add wave -noupdate -group "stb" ${dcu_path}/stb_dat_wr_vld
add wave -noupdate -group "stb" ${dcu_path}/stb_tag_rdy
add wave -noupdate -group "stb" ${dcu_path}/stb_alloc_biu_vld
add wave -noupdate -group "stb" ${dcu_path}/stb_alloc_biu_strb
add wave -noupdate -group "stb" ${dcu_path}/stb_evict_biu_vld
add wave -noupdate -group "stb" ${dcu_path}/stb_evict_biu_strb
add wave -noupdate -group "stb" ${dcu_path}/stb_index_match
add wave -noupdate -group "stb" ${dcu_path}/stb_index_hit
add wave -noupdate -group "stb" ${dcu_path}/stb_tag_match
add wave -noupdate -group "stb" ${dcu_path}/stb_tag_hit
add wave -noupdate -group "stb" ${dcu_path}/stb_hit
add wave -noupdate -group "stb" -divider "New Divider"

add wave -noupdate -group "biu" ${dcu_path}/biu_nxt_state
add wave -noupdate -group "biu" ${dcu_path}/biu_state_q
add wave -noupdate -group "biu" ${dcu_path}/biu_addr
add wave -noupdate -group "biu" ${dcu_path}/biu_data
add wave -noupdate -group "biu" ${dcu_path}/biu_strb
add wave -noupdate -group "biu" ${dcu_path}/biu_dirty
add wave -noupdate -group "biu" ${dcu_path}/biu_addr_q
add wave -noupdate -group "biu" ${dcu_path}/biu_data_q
add wave -noupdate -group "biu" ${dcu_path}/biu_valid_q
add wave -noupdate -group "biu" ${dcu_path}/biu_dirty_q
add wave -noupdate -group "biu" ${dcu_path}/biu_strb_q
add wave -noupdate -group "biu" ${dcu_path}/biu_alloc_valid_q
add wave -noupdate -group "biu" ${dcu_path}/biu_alloc_vld
add wave -noupdate -group "biu" -divider "New Divider"

config wave -signalnamewidth 1