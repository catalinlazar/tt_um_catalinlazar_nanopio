#!/usr/bin/env python3
"""
nanopio_asm.py -- tiny assembler for the nanoPIO ISA (v0.1).

Syntax (one instruction per line, labels on their own line ending in ':'):

    label:
    SET X, <imm7>                  ; X <= imm7 (0-127)
    IN                             ; X <= ui_in
    OUT PINS, X   [delay]          ; uo_out <= X
    OUT UIO,  X   [delay]          ; uio_out <= X
    WAIT 0 PIN <n> [delay]         ; stall until ui_in[n] == 0
    WAIT 1 PIN <n> [delay]         ; stall until ui_in[n] == 1
    JMP ALWAYS <label>  [delay]
    JMP X==0   <label>  [delay]
    JMP X!=0   <label>  [delay]
    JMP DEC    <label>  [delay]    ; jump if X!=0, then X--

';' or '#' start a comment. [delay] is an optional 0-7 in square brackets,
appended after the instruction.

Usage:
    python3 nanopio_asm.py program.asm             # print hex + binary listing
    python3 nanopio_asm.py program.asm --frames     # print loader bitstream (addr+instr, MSB first)
"""

import re
import sys

OPCODES = {"JMP": 0b000, "WAIT": 0b001, "IN": 0b010, "OUT": 0b011, "SET": 0b100}
JMP_COND = {"ALWAYS": 0b00, "X==0": 0b01, "X!=0": 0b10, "DEC": 0b11}

AWIDTH = 4   # matches nanopio_progmem's AWIDTH in tt_um_catalinlazar_nanopio.v
WWIDTH = 13  # instruction word width
DEPTH = 1 << AWIDTH
ADDR_MASK = DEPTH - 1

LINE_RE = re.compile(r"[;#].*$")
DELAY_RE = re.compile(r"\[(\d+)\]\s*$")


def strip_comment(line):
    return LINE_RE.sub("", line).strip()


def take_delay(line):
    m = DELAY_RE.search(line)
    if not m:
        return line.strip(), 0
    delay = int(m.group(1))
    if not (0 <= delay <= 7):
        raise ValueError(f"delay out of range 0-7: {delay}")
    return line[: m.start()].strip(), delay


def assemble(text):
    labels = {}
    raw_lines = []

    # pass 1: strip comments/blank lines, record label addresses
    addr = 0
    for lineno, line in enumerate(text.splitlines(), 1):
        line = strip_comment(line)
        if not line:
            continue
        if line.endswith(":"):
            labels[line[:-1].strip()] = addr
            continue
        raw_lines.append((lineno, line))
        addr += 1

    words = []

    # pass 2: encode
    for lineno, line in raw_lines:
        body, delay = take_delay(line)
        parts = re.split(r"[,\s]+", body.strip())
        mnem = parts[0].upper()

        if mnem == "SET":
            # SET X, imm
            imm = int(parts[2], 0)
            if not (0 <= imm <= 127):
                raise ValueError(f"line {lineno}: SET imm out of range 0-127: {imm}")
            operand = imm & 0x7F
            opcode = OPCODES["SET"]

        elif mnem == "IN":
            operand = 0
            opcode = OPCODES["IN"]

        elif mnem == "OUT":
            dest = parts[1].upper()
            dest_bit = 1 if dest == "UIO" else 0
            operand = (dest_bit << 6)
            opcode = OPCODES["OUT"]

        elif mnem == "WAIT":
            pol = int(parts[1])
            if parts[2].upper() != "PIN":
                raise ValueError(f"line {lineno}: expected PIN, got {parts[2]}")
            idx = int(parts[3])
            if not (0 <= idx <= 7):
                raise ValueError(f"line {lineno}: pin index out of range 0-7: {idx}")
            operand = (pol << 6) | (idx & 0x7)
            opcode = OPCODES["WAIT"]

        elif mnem == "JMP":
            cond = parts[1].upper()
            if cond not in JMP_COND:
                raise ValueError(f"line {lineno}: unknown JMP condition {cond}")
            target = parts[2]
            if target not in labels:
                raise ValueError(f"line {lineno}: unknown label {target}")
            addr_bits = labels[target]
            if not (0 <= addr_bits <= ADDR_MASK):
                raise ValueError(
                    f"line {lineno}: jump target out of range 0-{ADDR_MASK}"
                )
            operand = (JMP_COND[cond] << 5) | (addr_bits & ADDR_MASK)
            opcode = OPCODES["JMP"]

        else:
            raise ValueError(f"line {lineno}: unknown mnemonic {mnem}")

        instr = (opcode << 10) | (delay << 7) | operand
        words.append(instr)

    if len(words) > DEPTH:
        raise ValueError(
            f"program has {len(words)} instructions, exceeds progmem depth {DEPTH}"
        )

    return words


def print_listing(words):
    for i, w in enumerate(words):
        print(f"{i:2d}: 0x{w:04x}  {w:013b}")


def print_frames(words):
    # Each frame: addr(AWIDTH bits) + instr(WWIDTH bits), MSB first, as
    # sent over ui_in[5] (data) clocked by ui_in[6] while ui_in[7]=1.
    frame_bits = AWIDTH + WWIDTH
    for addr, w in enumerate(words):
        frame = (addr << WWIDTH) | w
        bits = format(frame, f"0{frame_bits}b")
        print(f"addr {addr:2d} -> frame bits (MSB first): {bits}")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    with open(sys.argv[1]) as f:
        text = f.read()

    words = assemble(text)

    if "--frames" in sys.argv:
        print_frames(words)
    else:
        print_listing(words)


if __name__ == "__main__":
    main()
