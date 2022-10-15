#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>

#include "tcp_server/TcpServer.hpp"

_CRT_BEGIN_C_HEADER
#include "mti.h"
_CRT_END_C_HEADER

TcpServer server = TcpServer();

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
    mtiSignalIdT arst_i;
    mtiSignalIdT clk_i;
    mtiDriverIdT tck_o;
    mtiDriverIdT tdi_o;
    mtiDriverIdT tms_o;
    mtiSignalIdT tdo_i;
    int tcp_fd;
} jtag_t;
static void jtag_rtl(void *param)
{
    static bool connected = false;
    static char rx_buffer[2048], tx_buffer[2048];
    static int rx_len = 0, tx_len = 0;
    static int rx_idx = 0, rx_phase = 0;
    jtag_t *ip = (jtag_t *)param;
    static uint8_t last_clk_i = STD_LOGIC_0;
    uint8_t arst_i = (StdLogicT)mti_GetSignalValue(ip->arst_i);
    uint8_t clk_i = (StdLogicT)mti_GetSignalValue(ip->clk_i);
    uint8_t tdo_i = (StdLogicT)mti_GetSignalValue(ip->tdo_i);
    static uint8_t tck = STD_LOGIC_0, tdi = STD_LOGIC_1, tdo = STD_LOGIC_1, tms = STD_LOGIC_1;
    if (clk_i == STD_LOGIC_1 && last_clk_i == STD_LOGIC_0)
    {
        if (connected == false && server.accept() > 0)
            connected = true;
        if (connected)
        {
            if (rx_len == 0)
            {
                rx_len = server.recv(rx_buffer, sizeof(rx_buffer), false);
                if (rx_len > 0)
                {
                    rx_idx = 0;
                    rx_phase = 0;
                }
                if (tx_len > 0)
                {
                    if (server.send(tx_buffer, tx_len) < 0)
                    {
                        mti_PrintFormatted("Something went wrong...\n");
                    }
                    tx_len = 0;
                }
            }
            else
            {
                uint8_t byte = rx_buffer[rx_idx];
                if (rx_phase >= 4)
                    byte = byte >> 4;
                tck = byte & 8 ? STD_LOGIC_1 : STD_LOGIC_0;
                tdi = byte & 2 ? STD_LOGIC_1 : STD_LOGIC_0;
                tms = byte & 1 ? STD_LOGIC_1 : STD_LOGIC_0;
                if (rx_phase == 4) // rising edge of tck
                {
                    if (tdo_i >= STD_LOGIC_0 && tdo_i <= STD_LOGIC_1)
                    {
                        tx_buffer[tx_len] = tdo_i - STD_LOGIC_0;
                        tx_len++;
                    }
                }
                rx_phase = (rx_phase + 1) % 8;
                if (!rx_phase)
                {
                    rx_idx++;
                    rx_len--;
                }
            }
        }
    }
    mti_ScheduleDriver(ip->tck_o, (mtiLongT)tck, 0, MTI_INERTIAL);
    mti_ScheduleDriver(ip->tdi_o, (mtiLongT)tdi, 0, MTI_INERTIAL);
    mti_ScheduleDriver(ip->tms_o, (mtiLongT)tms, 0, MTI_INERTIAL);
    last_clk_i = clk_i;
}

extern "C" __declspec(dllexport) void jtag_init(
   mtiRegionIdT region, // location in the design
   char *parameters, // from vhdl world (not used)
   mtiInterfaceListT *generics, // from vhdl world (not used)
   mtiInterfaceListT *ports // linked list of ports
)
{
    jtag_t *ip = (jtag_t *)(mti_Malloc(sizeof(jtag_t)));
    ip->arst_i = mti_FindPort(ports, "arst_i");
    ip->clk_i = mti_FindPort(ports, "clk_i");
    ip->tdo_i = mti_FindPort(ports, "tdo_i");
    ip->tck_o = mti_CreateDriver(mti_FindPort(ports, "tck_o"));
    ip->tdi_o = mti_CreateDriver(mti_FindPort(ports, "tdi_o"));
    ip->tms_o = mti_CreateDriver(mti_FindPort(ports, "tms_o"));

    mtiProcessIdT process_id = mti_CreateProcess("p_jtag", jtag_rtl, ip);

    mti_Sensitize(process_id, ip->clk_i, MTI_EVENT);
    mti_Sensitize(process_id, ip->arst_i, MTI_EVENT);

    server.init(54000);
    server.listen(false);
    mti_PrintFormatted("calling jtag_init...\n");
}