// nanopio_defs.vh
// nanoPIO ISA v0.1 -- 13-bit instruction word
//
//   [12:10] opcode
//   [9:7]   delay   (0-7 extra stall cycles after the instruction's effect)
//   [6:0]   operand (meaning depends on opcode, see below)
//
// JMP    operand[6:5]=cond  operand[4:0]=addr
//        cond: 00=ALWAYS 01=X==0(XZ) 10=X!=0(XNZ) 11=DEC (jump if X!=0, then X--)
// WAIT   operand[6]=pol     operand[2:0]=ui_in pin index
// IN     X <= ui_in (operand unused)
// OUT    operand[6]=dest (0=uo_out, 1=uio_out); uo/uio <= X
// SET    operand[6:0]=imm7; X <= {1'b0, imm7}
//
// opcodes 101/110/111 are reserved and behave as NOP (PC+1).

`ifndef NANOPIO_DEFS_VH
`define NANOPIO_DEFS_VH

`define OP_JMP  3'b000
`define OP_WAIT 3'b001
`define OP_IN   3'b010
`define OP_OUT  3'b011
`define OP_SET  3'b100

`define JMP_ALWAYS 2'b00
`define JMP_XZ      2'b01
`define JMP_XNZ     2'b10
`define JMP_DEC      2'b11

`endif
