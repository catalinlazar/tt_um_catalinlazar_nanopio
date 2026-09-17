# nanoPIO — tt_um_catalinlazar_nanopio

A tiny, reprogrammable programmable-I/O engine for [Tiny Tapeout](https://tinytapeout.com),
inspired by the RP2040's PIO block. It's a small Harvard-core state machine
that runs a 5-instruction ISA out of a 32-word instruction memory, meant for
bit-banging simple protocol timing (UART/SPI/I2C) after fabrication.

- [ISA & datapath overview](docs/info.md)
- [`info.yaml`](info.yaml) — pinout + TT project metadata
- [`tools/nanopio_asm.py`](tools/nanopio_asm.py) — mnemonic assembler + loader bitstream generator
- [`test/test.py`](test/test.py) — cocotb testbench

## Repo layout

```
src/    RTL: core, progmem, loader, top-level TT wrapper
test/   cocotb testbench + Makefile
tools/  Python assembler for the nanoPIO mnemonic language
docs/   long-form ISA / how-it-works writeup
```

## Quick start

Assemble a program and see its loader bitstream:

```bash
python3 tools/nanopio_asm.py my_program.asm --frames
```

Run the RTL testbench (Icarus Verilog + cocotb):

```bash
cd test
pip install -r requirements.txt
make
```

## Status

ISA v0.1: JMP (ALWAYS/X==0/X!=0/DEC), WAIT (pin + polarity), IN, OUT
(PINS/UIO), SET. See [docs/info.md](docs/info.md) for the full instruction
encoding and the reprogramming (bit-bang loader) protocol.
