#include <stdio.h>
#include <string.h>
#include "TcpServer.hpp"
#include "vpi_user.h"
#include <ctype.h>


#define CMD_RESET               0
#define CMD_TMS_SEQ             1
#define CMD_SCAN_CHAIN          2
#define CMD_SCAN_CHAIN_FLIP_TMS	3
#define CMD_STOP_SIMU           4

#define	XFERT_MAX_SIZE	512

struct jtag_cmd {
    uint32_t cmd;
    unsigned char buffer_out[XFERT_MAX_SIZE];
    unsigned char buffer_in[XFERT_MAX_SIZE];
    uint32_t length;
    uint32_t nb_bits;
};

TcpServer server;

char clk_path[] = "tb_xtr_soc.u_jtag.clk_i";
char tck_path[] = "tb_xtr_soc.u_jtag.tck_o";
char tdi_path[] = "tb_xtr_soc.u_jtag.tdi_o";
char tdo_path[] = "tb_xtr_soc.u_jtag.tdo_i";
char tms_path[] = "tb_xtr_soc.u_jtag.tms_o";

PLI_INT32 jtag_process(p_cb_data data) {
    static bool connected = false;
    static int state = 0;
    static struct jtag_cmd packet;
    static uint8_t rx_buffer[sizeof(packet)];
    int rx_len;
    static uint32_t idx;
    static uint32_t rx_size = 0;
    static bool flip_tms = false;

    int clk, tck, tdi, tdo, tms;

    vpiHandle vpi_handle = NULL;
    s_vpi_value vpi_value;
    vpi_value.format = vpiIntVal;
    vpi_handle = vpi_handle_by_name(clk_path, NULL);
    vpi_get_value(vpi_handle, &vpi_value);
    clk = vpi_value.value.integer;
    vpi_handle = vpi_handle_by_name(tck_path, NULL);
    vpi_get_value(vpi_handle, &vpi_value);
    tck = vpi_value.value.integer;
    vpi_handle = vpi_handle_by_name(tdi_path, NULL);
    vpi_get_value(vpi_handle, &vpi_value);
    tdi = vpi_value.value.integer;
    vpi_handle = vpi_handle_by_name(tdo_path, NULL);
    vpi_get_value(vpi_handle, &vpi_value);
    tdo = vpi_value.value.integer;
    vpi_handle = vpi_handle_by_name(tms_path, NULL);
    vpi_get_value(vpi_handle, &vpi_value);
    tms = vpi_value.value.integer;

    if (!connected && server.is_listening()) {
        if (server.accept()) {
            connected = true;
            printf("Got a connection\n");
        }
    }

    if (connected && state == 0) {
        rx_len = server.recv(rx_buffer+rx_size, sizeof(rx_buffer)-rx_size, false);
        // printf("rx_len = %d\n", rx_len);
        if (rx_len > 0) {
            rx_size += rx_len;
        } else if (rx_len < 0) {
            printf("Dropped connection...\n");
            server.close_client();
            connected = false;
            rx_size = 0;
        }
        if (rx_size >= sizeof(rx_buffer)) {
            memcpy(&packet, rx_buffer, sizeof(rx_buffer));
            state = 1;
            idx = 0;
            if (packet.cmd == CMD_SCAN_CHAIN_FLIP_TMS) {
                flip_tms = true;
            } else if (packet.cmd == CMD_SCAN_CHAIN) {
                flip_tms = false;
            }
        }
    }

    if (state) {
        tck = clk;
        switch (packet.cmd) {
            case CMD_STOP_SIMU:
                if (server.is_connected()) {
                    server.close_client();
                }
            case CMD_RESET:
                tms = 1;
                if (tck == 1) {
                    idx++;
                    if (idx >= 5) {
                        state = 0;
                        rx_size = 0;
                    }
                }
                break;
            case CMD_TMS_SEQ:
                tdi = ((packet.buffer_out[idx/8] >> (idx % 8)) & 0x1) ? 1 : 0;
                tms = tdi;
                if (tck == 1) {
                    idx++;
                    if (idx >= packet.nb_bits) {
                        state = 0;
                        rx_size = 0;
                    }
                }
                break;
            case CMD_SCAN_CHAIN_FLIP_TMS:
            case CMD_SCAN_CHAIN:
                if (packet.cmd == CMD_SCAN_CHAIN_FLIP_TMS) {
                    tms = idx >= (packet.nb_bits - 1) ? 1 : 0;
                } else {
                    tms = 0;
                }
                tdi = ((packet.buffer_out[idx/8] >> (idx % 8)) & 0x1) ? 1 : 0;
                if (tck == 1) {
                    if (idx % 8 == 0) {
                        packet.buffer_in[idx/8] = 0;
                    }
                    packet.buffer_in[idx/8] |= ((tdo == 1) ? 1 : 0) << (idx % 8);
                    idx++;
                    if (idx >= packet.nb_bits) {
                        state = 0;
                        rx_size = 0;
                        server.send(&packet, sizeof(packet));
                    }
                }
                break;
            default:
                printf("Unknown command\n");
                state = 0;
                break;
        }
    } else {
        tck = 0;
    }

    vpi_value.format = vpiIntVal;
    vpi_handle = vpi_handle_by_name(tck_path, NULL);
    vpi_value.value.integer = tck;
    vpi_put_value(vpi_handle, &vpi_value, NULL, vpiForceFlag);
    vpi_handle = vpi_handle_by_name(tdi_path, NULL);
    vpi_value.value.integer = tdi;
    vpi_put_value(vpi_handle, &vpi_value, NULL, vpiForceFlag);
    vpi_handle = vpi_handle_by_name(tms_path, NULL);
    vpi_value.value.integer = tms;
    vpi_put_value(vpi_handle, &vpi_value, NULL, vpiForceFlag);

    return 0;
}

PLI_INT32 jtag_setup(p_cb_data data) {
    s_cb_data cb_data;

    cb_data.cb_rtn = jtag_process;
    cb_data.reason = cbValueChange;
    cb_data.obj = vpi_handle_by_name(clk_path, NULL);
    cb_data.value = NULL;
    cb_data.user_data = NULL;

    vpiHandle ret = vpi_register_cb(&cb_data);

    if (ret == NULL) {
        printf("Could not register jtag_vpi callback!\n");
    }

    return 0;
}

void entry_point_cb() {
    s_cb_data cb_data;

    cb_data.cb_rtn = jtag_setup;
    cb_data.reason = cbStartOfSimulation;
    cb_data.obj = NULL;
    cb_data.value = NULL;
    cb_data.user_data = NULL;

    vpiHandle ret = vpi_register_cb(&cb_data);

    if (ret == NULL) {
        printf("Could not register jtag_setup!\n");
    }

    if (server.is_listening() || server.is_connected()) {
        server.end();
    }

    if (server.init(5555)) {
        printf("Could not start jtag server!\n");
    } else {
        server.listen(false);
    }
}

void (*vlog_startup_routines[])() = {
    entry_point_cb,
    0
};
