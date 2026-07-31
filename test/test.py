# SPDX-License-Identifier: Apache-2.0
#
# Adapted from test_regfile_ecc_hk.py (which tested regfile_ecc_hk directly)
# to instead drive the SPI signals through the TinyTapeout top module's
# ui_in / uio_out pins, per the mapping in tt_um_aka_regfile_ecc.v:
#   ui_in[0]   -> SCK
#   ui_in[1]   -> SDI
#   ui_in[2]   -> CSB
#   uio_out[0] -> SDO
#   uio_oe[0]  -> sdo_ena

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

SCK_BIT = 0
SDI_BIT = 1
CSB_BIT = 2

# Track ui_in's value ourselves rather than reading it back from the DUT:
# a `.value =` write doesn't take effect until the next sim time step, so
# reading dut.ui_in.value right after setting it would see the old value.
_ui_in_state = 0


def _set_ui_bit(dut, bit, value):
    """Set a single bit of ui_in, leaving the other bits untouched."""
    global _ui_in_state
    if value:
        _ui_in_state |= (1 << bit)
    else:
        _ui_in_state &= ~(1 << bit)
    dut.ui_in.value = _ui_in_state


async def spi_send_byte(dut, byte_val):
    """Shift one byte out on SDI, MSB first, toggling SCK manually."""
    for i in range(8):
        bit = (byte_val >> (7 - i)) & 1
        _set_ui_bit(dut, SDI_BIT, bit)
        await Timer(50, units="ns")
        _set_ui_bit(dut, SCK_BIT, 1)
        await Timer(50, units="ns")
        _set_ui_bit(dut, SCK_BIT, 0)


async def spi_write_byte(dut, addr, data):
    """Single-byte SPI write transaction: command, address, data."""
    _set_ui_bit(dut, CSB_BIT, 0)
    await Timer(20, units="ns")

    await spi_send_byte(dut, 0b10000000)  # write-until-CSB-raised
    await spi_send_byte(dut, addr)
    await spi_send_byte(dut, data)

    _set_ui_bit(dut, CSB_BIT, 1)
    await Timer(50, units="ns")


async def spi_write_word32(dut, base_addr, value32):
    """Write a 32-bit value across 4 consecutive byte addresses (base_addr
    = LSB byte, base_addr+3 = MSB byte)."""
    for i in range(4):
        byte_val = (value32 >> (8 * i)) & 0xFF
        await spi_write_byte(dut, base_addr + i, byte_val)


async def spi_read_byte(dut, addr):
    """Single-byte SPI read transaction: command, address, clock out data."""
    _set_ui_bit(dut, CSB_BIT, 0)
    await Timer(20, units="ns")

    await spi_send_byte(dut, 0b01000000)  # read-until-CSB-raised
    await spi_send_byte(dut, addr)

    read_val = 0
    for i in range(8):
        await Timer(50, units="ns")
        _set_ui_bit(dut, SCK_BIT, 1)
        await Timer(50, units="ns")
        bit = int(dut.uio_out.value) & 1  # SDO is uio_out[0]
        read_val = (read_val << 1) | bit
        _set_ui_bit(dut, SCK_BIT, 0)

    _set_ui_bit(dut, CSB_BIT, 1)
    await Timer(50, units="ns")
    return read_val


async def spi_read_word32(dut, base_addr):
    """Read a 32-bit value across 4 consecutive byte addresses."""
    value = 0
    for i in range(4):
        b = await spi_read_byte(dut, base_addr + i)
        value |= (b << (8 * i))
    return value


@cocotb.test()
async def test_wdata_write_and_readback(dut):
    """Write a known 32-bit value into wdata via SPI (through ui_in), then
    read rdata1 back via SPI (through uio_out) and check it matches."""

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    global _ui_in_state
    _ui_in_state = 0

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    # CSB idles high
    _set_ui_bit(dut, CSB_BIT, 1)

    await Timer(100, units="ns")
    dut.rst_n.value = 1
    await Timer(100, units="ns")

    test_pattern = 0xDEADBEEF

    # Write the 32-bit pattern into wdata (SPI addr 0x0a-0x0d)
    await spi_write_word32(dut, 0x0a, test_pattern)

    # Pulse 'we' (SPI addr 0x09, bit 0)
    await spi_write_byte(dut, 0x09, 0b00000001)

    # Give the register bank a couple of clock edges to latch the write
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # De-assert we so it doesn't keep rewriting on subsequent clocks
    await spi_write_byte(dut, 0x09, 0b00000000)
    await RisingEdge(dut.clk)

    # Read back rdata1 (SPI addr 0x19-0x1c) and compare
    readback = await spi_read_word32(dut, 0x19)

    dut._log.info(f"Wrote 0x{test_pattern:08x}, read back rdata1 = 0x{readback:08x}")

    assert readback == test_pattern, (
        f"Mismatch: wrote 0x{test_pattern:08x}, "
        f"read back 0x{readback:08x}"
    )
