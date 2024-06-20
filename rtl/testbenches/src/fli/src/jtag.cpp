#include <stdio.h>
#include <stdint.h>
#ifdef WIN32
_CRT_BEGIN_C_HEADER
#include "mti.h"
_CRT_END_C_HEADER
#define DLLEXPORT __declspec(dllexport)
#else
__BEGIN_DECLS
#include "mti.h"
__END_DECLS
#define DLLEXPORT
#endif

#include "TcpServer.hpp"

#define CMD_RESET               0
#define CMD_TMS_SEQ             1
#define CMD_SCAN_CHAIN          2
#define CMD_SCAN_CHAIN_FLIP_TMS	3
#define CMD_STOP_SIMU           4

typedef enum {
    STD_LOGIC_U, /* 'U' */
    STD_LOGIC_X, /* 'X' */
    STD_LOGIC_0, /* '0' */
    STD_LOGIC_1, /* '1' */
    STD_LOGIC_Z, /* 'Z' */
    STD_LOGIC_W, /* 'W' */
    STD_LOGIC_L, /* 'L' */
    STD_LOGIC_H, /* 'H' */
    STD_LOGIC_D  /* '-' */
} StdLogicT;
typedef struct
{
    mtiSignalIdT clk_i;
    mtiDriverIdT tck_o;
    mtiDriverIdT tdi_o;
    mtiDriverIdT tms_o;
    mtiSignalIdT tdo_i;
    int tcp_fd;
} jtag_t;


TcpServer server;

#define	XFERT_MAX_SIZE	512

struct jtag_cmd {
    uint32_t cmd;
    unsigned char buffer_out[XFERT_MAX_SIZE];
    unsigned char buffer_in[XFERT_MAX_SIZE];
    uint32_t length;
    uint32_t nb_bits;
};

void hexdump(const void *ptr_data, const size_t size) {
    const uint8_t *ptr = (const uint8_t*)ptr_data;
    for (size_t i = 0; i < size; i += 16) {
        mti_PrintFormatted("%08lX:", i);
        for (size_t j = 0; j < 16; j++) {
            if (i + j < size) {
                mti_PrintFormatted(" %02X", ptr[i+j]);
            } else {
                mti_PrintFormatted(" XX");
            }
        }
        mti_PrintFormatted(" | ");
        for (size_t j = 0; j < 16; j++) {
            if (i + j < size && isprint(ptr[i+j])) {
                mti_PrintFormatted("%c", ptr[i+j]);
            } else {
                mti_PrintFormatted(".");
            }
        }
        mti_PrintFormatted(" |\n");
    }
}

static void jtag_rtl(void *params) {
    static bool connected = false;
    static int state = 0;
//    static uint8_t rx_buffer[2048], tx_buffer[2048];
    static struct jtag_cmd packet;
    static uint8_t rx_buffer[sizeof(packet)];
    int rx_len;
    static uint32_t idx;
    static uint32_t rx_size = 0;
    static bool flip_tms = false;
    jtag_t *ip = (jtag_t *)params;
    static uint8_t tck = STD_LOGIC_0, tdi = STD_LOGIC_0, tms = STD_LOGIC_0;

    if (!connected && server.is_listening()) {
        if (server.accept()) {
            connected = true;
            mti_PrintFormatted("Got a connection\n");
        }
    }

    if (connected && state == 0) {
        rx_len = server.recv(rx_buffer+rx_size, sizeof(rx_buffer)-rx_size, false);
        if (rx_len > 0) {
            rx_size += rx_len;
        } else if (rx_len < 0) {
            mti_PrintFormatted("Dropped connection...\n");
            server.close_client();
            connected = false;
            rx_size = 0;
        }
        if (rx_size >= sizeof(rx_buffer)) {
            memcpy(&packet, rx_buffer, sizeof(rx_buffer));
//            hexdump(rx_buffer, rx_len);
//            mti_PrintFormatted("packet.cmd = %d\n", packet.cmd);
//            mti_PrintFormatted("packet.length = %d\n", packet.length);
//            mti_PrintFormatted("packet.nb_bits = %d\n", packet.nb_bits);
            state = 1;
            idx = 0;
            if (packet.cmd == CMD_SCAN_CHAIN_FLIP_TMS) {
                flip_tms = true;
            } else if (packet.cmd == CMD_SCAN_CHAIN) {
                flip_tms = false;
            }
        }
    }

//    if (state) {
//        if ((StdLogicT)mti_GetSignalValue(ip->clk_i) == STD_LOGIC_0) {
//            tdi = ((packet.buffer_out[idx/8] >> (idx % 8)) & 0x1) ? STD_LOGIC_1 : STD_LOGIC_0;
//            if ((flip_tms && idx >= (packet.nb_bits - 1)) || (packet.cmd == CMD_TMS_SEQ && tdi))
//                tms = STD_LOGIC_1;
//            else
//                tms = STD_LOGIC_0;
//            idx++;
//        } else {
//            if (idx % 8 == 0) {
//                packet.buffer_in[idx/8] = 0;
//            }
//            packet.buffer_in[idx/8] = (packet.buffer_in[idx/8] << 1) | ((mti_GetSignalValue(ip->tdo_i) == STD_LOGIC_1) ? STD_LOGIC_1 : STD_LOGIC_0);
//            if (idx >= packet.nb_bits) {
//                state = 0;
//            }
//        }
//        tck = mti_GetSignalValue(ip->clk_i);
//    } else {
//        tck = STD_LOGIC_0;
//    }

    if (state) {
        tck = mti_GetSignalValue(ip->clk_i);
        switch (packet.cmd) {
            case CMD_STOP_SIMU:
                if (server.is_connected()) {
                    server.close_client();
                }
            case CMD_RESET:
                tms = STD_LOGIC_1;
                if (tck == STD_LOGIC_1) {
                    idx++;
                    if (idx >= 5) {
                        state = 0;
                        rx_size = 0;
                    }
                }
                break;
            case CMD_TMS_SEQ:
                tdi = ((packet.buffer_out[idx/8] >> (idx % 8)) & 0x1) ? STD_LOGIC_1 : STD_LOGIC_0;
                tms = tdi;
                if (tck == STD_LOGIC_1) {
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
                    tms = idx >= (packet.nb_bits - 1) ? STD_LOGIC_1 : STD_LOGIC_0;
                } else {
                    tms = STD_LOGIC_0;
                }
                tdi = ((packet.buffer_out[idx/8] >> (idx % 8)) & 0x1) ? STD_LOGIC_1 : STD_LOGIC_0;
                if (tck == STD_LOGIC_1) {
                    if (idx % 8 == 0) {
                        packet.buffer_in[idx/8] = 0;
                    }
                    packet.buffer_in[idx/8] |= ((mti_GetSignalValue(ip->tdo_i) == STD_LOGIC_1) ? 1 : 0) << (idx % 8);
                    idx++;
                    if (idx >= packet.nb_bits) {
                        state = 0;
                        rx_size = 0;
//                        hexdump(packet.buffer_in, packet.length);
                        server.send(&packet, sizeof(packet));
                    }
                }
                break;
            default:
                break;
        }
    } else {
        tck = STD_LOGIC_0;
    }

//    tck = STD_LOGIC_0;
//    tdi = STD_LOGIC_Z;
//    tms = STD_LOGIC_1;

    mti_ScheduleDriver(ip->tck_o, (mtiLongT)tck, 0, MTI_INERTIAL);
    mti_ScheduleDriver(ip->tdi_o, (mtiLongT)tdi, 0, MTI_INERTIAL);
    mti_ScheduleDriver(ip->tms_o, (mtiLongT)tms, 0, MTI_INERTIAL);
}

extern "C" DLLEXPORT void jtag_init(
   mtiRegionIdT region, // location in the design
   char *parameters, // from vhdl world (not used)
   mtiInterfaceListT *generics, // from vhdl world (not used)
   mtiInterfaceListT *ports // linked list of ports
) {
    jtag_t *ip = (jtag_t *)(mti_Malloc(sizeof(jtag_t)));
//    ip->arst_i = mti_FindPort(ports, "arst_i");
    ip->clk_i = mti_FindPort(ports, "clk_i");
    ip->tdo_i = mti_FindPort(ports, "tdo_i");
    ip->tck_o = mti_CreateDriver(mti_FindPort(ports, "tck_o"));
    ip->tdi_o = mti_CreateDriver(mti_FindPort(ports, "tdi_o"));
    ip->tms_o = mti_CreateDriver(mti_FindPort(ports, "tms_o"));


    mtiProcessIdT process_id = mti_CreateProcess("p_jtag", jtag_rtl, ip);

    mti_Sensitize(process_id, ip->clk_i, MTI_EVENT);

    if (server.is_listening() || server.is_connected()) {
        server.end();
    }

    if (!server.init(5555))
        server.listen(false);
    mti_PrintFormatted("jtag_init done\n");
}

