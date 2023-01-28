import cocotb
from cocotb.triggers import Timer


@cocotb.test()
async def cocotb_main(dut):
    # cocotb.handle.
    await Timer(1000, units="ms")
