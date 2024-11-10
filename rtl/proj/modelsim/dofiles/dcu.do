onerror {resume}

add wave -noupdate /tb_dcu/u_dcu/arst_i
add wave -noupdate /tb_dcu/u_dcu/clk_i

add wave -noupdate -group "cpu if" /tb_dcu/u_dcu/cpu_adr_i
add wave -noupdate -group "cpu if" /tb_dcu/u_dcu/cpu_dat_i
add wave -noupdate -group "cpu if" /tb_dcu/u_dcu/cpu_siz_i
add wave -noupdate -group "cpu if" /tb_dcu/u_dcu/cpu_wr_i
add wave -noupdate -group "cpu if" /tb_dcu/u_dcu/cpu_vld_i
add wave -noupdate -group "cpu if" /tb_dcu/u_dcu/cpu_rdy_o
add wave -noupdate -group "cpu if" /tb_dcu/u_dcu/cpu_dat_o
add wave -noupdate -group "cpu if" /tb_dcu/u_dcu/cpu_vld_o

add wave -noupdate -group "biu if" /tb_dcu/u_dcu/biu_adr_o
add wave -noupdate -group "biu if" /tb_dcu/u_dcu/biu_dat_o
add wave -noupdate -group "biu if" /tb_dcu/u_dcu/biu_wr_o
add wave -noupdate -group "biu if" /tb_dcu/u_dcu/biu_vld_o
add wave -noupdate -group "biu if" /tb_dcu/u_dcu/biu_rdy_i
add wave -noupdate -group "biu if" /tb_dcu/u_dcu/biu_dat_i
add wave -noupdate -group "biu if" /tb_dcu/u_dcu/biu_vld_i
add wave -noupdate -group "biu if" /tb_dcu/u_dcu/cpu_vld
add wave -noupdate -group "biu if" /tb_dcu/u_dcu/cpu_vld_q
add wave -noupdate -group "biu if" /tb_dcu/u_dcu/cpu_miss
add wave -noupdate -group "biu if" /tb_dcu/u_dcu/cpu_miss_q
add wave -noupdate -group "biu if" /tb_dcu/u_dcu/stb_miss
add wave -noupdate -group "biu if" /tb_dcu/u_dcu/stb_miss_q

add wave -noupdate -group "cache" /tb_dcu/u_dcu/tag_ram
add wave -noupdate -group "cache" /tb_dcu/u_dcu/data_ram
add wave -noupdate -group "cache" /tb_dcu/u_dcu/cache_init_addr_q
add wave -noupdate -group "cache" /tb_dcu/u_dcu/cache_init_done
add wave -noupdate -group "cache" /tb_dcu/u_dcu/cache_vld_q
add wave -noupdate -group "cache" /tb_dcu/u_dcu/cache_tag_addr
add wave -noupdate -group "cache" /tb_dcu/u_dcu/cache_tag_dirty
add wave -noupdate -group "cache" /tb_dcu/u_dcu/cache_tag_vld
add wave -noupdate -group "cache" /tb_dcu/u_dcu/cache_tag_match
add wave -noupdate -group "cache" /tb_dcu/u_dcu/cache_tag_hit
add wave -noupdate -group "cache" /tb_dcu/u_dcu/cache_tag_miss
add wave -noupdate -group "cache" /tb_dcu/u_dcu/cache_cpu_addr_q
add wave -noupdate -group "cache" /tb_dcu/u_dcu/cache_biu_alloc_vld
add wave -noupdate -group "cache" /tb_dcu/u_dcu/cache_biu_alloc_rdy
add wave -noupdate -group "cache" /tb_dcu/u_dcu/cache_cpu_vld
add wave -noupdate -group "cache" /tb_dcu/u_dcu/cache_cpu_rdy
add wave -noupdate -group "cache" /tb_dcu/u_dcu/cache_stb_vld
add wave -noupdate -group "cache" /tb_dcu/u_dcu/cache_stb_rdy
add wave -noupdate -group "cache" /tb_dcu/u_dcu/cache_priority_stb
add wave -noupdate -group "cache" -divider "New Divider"

add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_slot_wr
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_full
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_slot_nxt_state
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_slot_state_q
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_slot_vld_q
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_slot_addr_q
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_slot_data_q
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_slot_strb_q
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_slot_dirty_q
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_tag_wr_vld
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_dat_wr_vld
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_tag_rdy
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_alloc_biu_vld
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_alloc_biu_strb
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_evict_biu_vld
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_evict_biu_strb
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_index_match
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_index_hit
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_tag_match
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_tag_hit
add wave -noupdate -group "stb" /tb_dcu/u_dcu/stb_hit
add wave -noupdate -group "stb" -divider "New Divider"

add wave -noupdate -group "biu" /tb_dcu/u_dcu/biu_nxt_state
add wave -noupdate -group "biu" /tb_dcu/u_dcu/biu_state_q
add wave -noupdate -group "biu" /tb_dcu/u_dcu/biu_addr_q
add wave -noupdate -group "biu" /tb_dcu/u_dcu/biu_data_q
add wave -noupdate -group "biu" /tb_dcu/u_dcu/biu_valid_q
add wave -noupdate -group "biu" /tb_dcu/u_dcu/biu_dirty_q
add wave -noupdate -group "biu" /tb_dcu/u_dcu/biu_strb_q
add wave -noupdate -group "biu" /tb_dcu/u_dcu/biu_alloc_vld
add wave -noupdate -group "biu" -divider "New Divider"

config wave -signalnamewidth 1