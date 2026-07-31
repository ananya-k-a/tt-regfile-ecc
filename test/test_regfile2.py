import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

NO_ERROR = 0b00
SINGLE_ERROR = 0b01
NUM_REG = 16
DATA_BITS = 32
CHK_BITS = 7

TEST_ADDR = 5  # register used for all error-injection checks


async def setup(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.we.value = 0
    dut.waddr.value = 0
    dut.wdata.value = 0
    dut.raddr1.value = 0
    dut.raddr2.value = 0
    dut.data_error_mask1.value = 0
    dut.chk_error_mask1.value = 0
    dut.data_error_mask2.value = 0
    dut.chk_error_mask2.value = 0
    await RisingEdge(dut.clk)


async def write_reg(dut, addr, data):
    dut.we.value = 1
    dut.waddr.value = addr
    dut.wdata.value = data
    await RisingEdge(dut.clk)
    dut.we.value = 0


async def read_reg(dut, addr1, addr2):
    dut.raddr1.value = addr1
    dut.raddr2.value = addr2
    await Timer(1, unit="ns")
    return (
        int(dut.rdata1.value),
        int(dut.rdata2.value),
        int(dut.error_type1.value),
        int(dut.error_type2.value),
    )


async def load_test_data(dut):
    random.seed(42)
    values = {}
    for addr in range(NUM_REG):
        value = random.getrandbits(32)
        values[addr] = value
        await write_reg(dut, addr, value)
    return values


# ---------------------------------------------------------------------
# Test factory: dynamically create one named @cocotb.test() per case
# so each combination shows up as its own individual pass/fail entry.
# ---------------------------------------------------------------------

def _make_single_data_bit_test(bit):
    async def _test(dut):
        await setup(dut)
        values = await load_test_data(dut)
        dut.data_error_mask1.value = 1 << bit
        r1, _, e1, _ = await read_reg(dut, TEST_ADDR, 0)
        assert r1 == values[TEST_ADDR], (
            f"data bit {bit}: expected corrected value 0x{values[TEST_ADDR]:08x}, "
            f"got 0x{r1:08x}"
        )
        assert e1 == SINGLE_ERROR, f"data bit {bit}: expected SINGLE_ERROR, got {e1}"
    _test.__name__ = f"test_single_data_bit_{bit:02d}"
    return _test


def _make_single_checkbit_test(bit):
    async def _test(dut):
        await setup(dut)
        values = await load_test_data(dut)
        dut.chk_error_mask1.value = 1 << bit
        r1, _, e1, _ = await read_reg(dut, TEST_ADDR, 0)
        assert r1 == values[TEST_ADDR], (
            f"checkbit {bit}: expected data unaffected 0x{values[TEST_ADDR]:08x}, "
            f"got 0x{r1:08x}"
        )
        assert e1 != NO_ERROR, f"checkbit {bit}: expected an error flag, got NO_ERROR"
    _test.__name__ = f"test_single_checkbit_{bit:02d}"
    return _test


def _make_double_data_bit_test(bit_a, bit_b):
    async def _test(dut):
        await setup(dut)
        values = await load_test_data(dut)
        dut.data_error_mask1.value = (1 << bit_a) | (1 << bit_b)
        r1, _, e1, _ = await read_reg(dut, TEST_ADDR, 0)
        # Double-bit errors should either be flagged as an error, or if
        # silently miscorrected, that itself is a finding worth catching --
        # so we require the decoder NOT claim NO_ERROR with a wrong value.
        assert not (e1 == NO_ERROR and r1 != values[TEST_ADDR]), (
            f"data bits {bit_a},{bit_b}: silently returned wrong data "
            f"(0x{r1:08x} != 0x{values[TEST_ADDR]:08x}) with NO_ERROR reported"
        )
    _test.__name__ = f"test_double_data_bits_{bit_a:02d}_{bit_b:02d}"
    return _test


def _make_double_checkbit_test(bit_a, bit_b):
    async def _test(dut):
        await setup(dut)
        values = await load_test_data(dut)
        dut.chk_error_mask1.value = (1 << bit_a) | (1 << bit_b)
        r1, _, e1, _ = await read_reg(dut, TEST_ADDR, 0)
        assert not (e1 == NO_ERROR and r1 != values[TEST_ADDR]), (
            f"checkbits {bit_a},{bit_b}: silently returned wrong data "
            f"(0x{r1:08x} != 0x{values[TEST_ADDR]:08x}) with NO_ERROR reported"
        )
    _test.__name__ = f"test_double_checkbits_{bit_a:02d}_{bit_b:02d}"
    return _test


def _make_mixed_double_test(data_bit, chk_bit):
    async def _test(dut):
        await setup(dut)
        values = await load_test_data(dut)
        dut.data_error_mask1.value = 1 << data_bit
        dut.chk_error_mask1.value = 1 << chk_bit
        r1, _, e1, _ = await read_reg(dut, TEST_ADDR, 0)
        assert not (e1 == NO_ERROR and r1 != values[TEST_ADDR]), (
            f"data bit {data_bit} + checkbit {chk_bit}: silently returned wrong "
            f"data (0x{r1:08x} != 0x{values[TEST_ADDR]:08x}) with NO_ERROR reported"
        )
    _test.__name__ = f"test_mixed_data{data_bit:02d}_chk{chk_bit:02d}"
    return _test


# ---------------------------------------------------------------------
# Generate and register every test case
# ---------------------------------------------------------------------

# 32 single-bit data error tests
for _b in range(DATA_BITS):
    fn = _make_single_data_bit_test(_b)
    globals()[fn.__name__] = cocotb.test()(fn)

# 7 single-bit checkbit error tests
for _b in range(CHK_BITS):
    fn = _make_single_checkbit_test(_b)
    globals()[fn.__name__] = cocotb.test()(fn)

# C(32,2) = 496 double data-bit error tests
for _a in range(DATA_BITS):
    for _b in range(_a + 1, DATA_BITS):
        fn = _make_double_data_bit_test(_a, _b)
        globals()[fn.__name__] = cocotb.test()(fn)

# C(7,2) = 21 double checkbit error tests
for _a in range(CHK_BITS):
    for _b in range(_a + 1, CHK_BITS):
        fn = _make_double_checkbit_test(_a, _b)
        globals()[fn.__name__] = cocotb.test()(fn)

# 32 x 7 = 224 mixed data+checkbit double error tests
for _d in range(DATA_BITS):
    for _c in range(CHK_BITS):
        fn = _make_mixed_double_test(_d, _c)
        globals()[fn.__name__] = cocotb.test()(fn)

# Total generated: 32 + 7 + 496 + 21 + 224 = 780 individual test cases
