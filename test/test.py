# SPDX-License-Identifier: Apache-2.0
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

LOAD_EN   = 1 << 7
LOAD_CLK  = 1 << 6
LOAD_DATA = 1 << 5

AWIDTH = 4   # matches nanopio_progmem's AWIDTH in tt_um_catalinlazar_nanopio.v
WWIDTH = 13  # instruction word width
FRAME_BITS = AWIDTH + WWIDTH


async def load_program(dut, words):
    """Bit-bang `words` (list of 13-bit ints, index = address) into progmem
    over ui_in using the nanopio_loader protocol: LOAD_EN held high, then
    for each frame shift addr(AWIDTH)+instr(WWIDTH)=FRAME_BITS bits
    MSB-first, toggling LOAD_CLK once per bit and holding LOAD_DATA stable
    around the edge."""

    dut.ui_in.value = LOAD_EN
    await ClockCycles(dut.clk, 2)

    for addr, instr in enumerate(words):
        frame = (addr << WWIDTH) | (instr & 0x1FFF)
        for i in range(FRAME_BITS - 1, -1, -1):
            bit = (frame >> i) & 1
            data_bit = LOAD_DATA if bit else 0

            dut.ui_in.value = LOAD_EN | data_bit
            await ClockCycles(dut.clk, 2)

            dut.ui_in.value = LOAD_EN | data_bit | LOAD_CLK
            await ClockCycles(dut.clk, 2)

            dut.ui_in.value = LOAD_EN | data_bit
            await ClockCycles(dut.clk, 2)

    # drop LOAD_EN, release the core to start executing from address 0
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 2)


async def reset(dut):
    # each cocotb test gets its own forked tasks killed at test end, so
    # every test must start its own clock.
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.uio_in.value = 0
    # hold LOAD_EN through reset: progmem survives across tests in the same
    # simulation, so without this the core would briefly execute whatever
    # the previous test left behind before load_program() gets to run.
    dut.ui_in.value = LOAD_EN
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


@cocotb.test()
async def test_set_out(dut):
    """SET X,imm followed by OUT PINS,X should drive uo_out == imm."""
    await reset(dut)

    # SET X, 0x2A ; OUT PINS, X ; JMP ALWAYS 1  (spin on instr 1..2)
    prog = [
        (0b100 << 10) | (0 << 7) | 0x2A,        # SET X,0x2A
        (0b011 << 10) | (0 << 7) | (0 << 6),    # OUT PINS,X
        (0b000 << 10) | (0 << 7) | (0b00 << 5) | 1,  # JMP ALWAYS ->1
    ]
    await load_program(dut, prog)
    await ClockCycles(dut.clk, 5)

    assert int(dut.uo_out.value) == 0x2A, f"expected 0x2A, got {int(dut.uo_out.value):#x}"


@cocotb.test()
async def test_wait_pin(dut):
    """WAIT should stall the core until ui_in[0] matches, then proceed."""
    await reset(dut)

    prog = [
        (0b001 << 10) | (0 << 7) | (1 << 6) | 0,   # WAIT 1 PIN 0
        (0b100 << 10) | (0 << 7) | 0x11,           # SET X,0x11
        (0b011 << 10) | (0 << 7) | (0 << 6),       # OUT PINS,X
        (0b000 << 10) | (0 << 7) | (0b00 << 5) | 2,  # JMP ALWAYS ->2
    ]
    await load_program(dut, prog)

    # core should be stalled on WAIT: output stays 0
    await ClockCycles(dut.clk, 10)
    assert int(dut.uo_out.value) == 0x00

    # release the wait condition
    dut.ui_in.value = 0x01
    await ClockCycles(dut.clk, 5)

    assert int(dut.uo_out.value) == 0x11, f"expected 0x11, got {int(dut.uo_out.value):#x}"


@cocotb.test()
async def test_dec_loop(dut):
    """JMP DEC should loop X down to zero, OUT-ing X each iteration."""
    await reset(dut)

    prog = [
        (0b100 << 10) | (0 << 7) | 3,                     # 0: SET X,3
        (0b011 << 10) | (0 << 7) | (0 << 6),               # 1: OUT PINS,X
        (0b000 << 10) | (0 << 7) | (0b11 << 5) | 1,        # 2: JMP DEC ->1
        (0b011 << 10) | (0 << 7) | (0 << 6),               # 3: OUT PINS,X (X==0 here)
        (0b000 << 10) | (0 << 7) | (0b00 << 5) | 3,        # 4: JMP ALWAYS ->3
    ]
    await load_program(dut, prog)

    seen = []
    for _ in range(20):
        await RisingEdge(dut.clk)
        seen.append(int(dut.uo_out.value))

    assert 0 in seen, f"expected X to reach 0, saw sequence {seen}"
