`default_nettype none
`timescale 1ns / 1ps
`include "nanopio_defs.vh"

// nanoPIO fetch/decode/execute core. Single 8-bit scratch register X,
// program counter, and a per-instruction delay counter. See
// nanopio_defs.vh for the instruction encoding.
module nanopio_core #(
    parameter AWIDTH = 5
) (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              run_en,   // 0 while the loader owns progmem
    input  wire [7:0]        ui_in,
    output reg  [7:0]        uo_out,
    output reg  [7:0]        uio_out,

    output wire [AWIDTH-1:0] pc_o,
    input  wire [12:0]       instr
);

    reg [7:0]        x;
    reg [AWIDTH-1:0] pc;
    reg [2:0]        delay_cnt;

    wire [2:0] opcode  = instr[12:10];
    wire [2:0] delay_f = instr[9:7];
    wire [6:0] operand = instr[6:0];

    // JMP fields
    wire [1:0]        jmp_cond = operand[6:5];
    wire [AWIDTH-1:0] jmp_addr = operand[AWIDTH-1:0];

    // WAIT fields
    wire       wait_pol   = operand[6];
    wire [2:0] wait_idx   = operand[2:0];
    wire       wait_match = (ui_in[wait_idx] == wait_pol);

    // OUT fields
    wire out_dest_uio = operand[6];

    // SET fields
    wire [6:0] set_imm = operand[6:0];

    wire jmp_taken = (jmp_cond == `JMP_ALWAYS) ? 1'b1 :
                     (jmp_cond == `JMP_XZ)     ? (x == 8'd0) :
                     (jmp_cond == `JMP_XNZ)    ? (x != 8'd0) :
                     /* JMP_DEC */                (x != 8'd0);

    assign pc_o = pc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc        <= {AWIDTH{1'b0}};
            x         <= 8'd0;
            delay_cnt <= 3'd0;
            uo_out    <= 8'd0;
            uio_out   <= 8'd0;
        end else if (!run_en) begin
            // held while the reprogramming loader is active
            pc        <= {AWIDTH{1'b0}};
            x         <= 8'd0;
            delay_cnt <= 3'd0;
        end else if (delay_cnt != 3'd0) begin
            delay_cnt <= delay_cnt - 3'd1;
        end else begin
            case (opcode)
                `OP_JMP: begin
                    pc <= jmp_taken ? jmp_addr : pc + 1'b1;
                    if (jmp_cond == `JMP_DEC && x != 8'd0)
                        x <= x - 8'd1;
                    delay_cnt <= delay_f;
                end
                `OP_WAIT: begin
                    if (wait_match) begin
                        pc        <= pc + 1'b1;
                        delay_cnt <= delay_f;
                    end
                    // else: hold PC, keep polling every cycle, no delay yet
                end
                `OP_IN: begin
                    x         <= ui_in;
                    pc        <= pc + 1'b1;
                    delay_cnt <= delay_f;
                end
                `OP_OUT: begin
                    if (out_dest_uio) uio_out <= x;
                    else              uo_out  <= x;
                    pc        <= pc + 1'b1;
                    delay_cnt <= delay_f;
                end
                `OP_SET: begin
                    x         <= {1'b0, set_imm};
                    pc        <= pc + 1'b1;
                    delay_cnt <= delay_f;
                end
                default: begin
                    // reserved opcodes: NOP
                    pc        <= pc + 1'b1;
                    delay_cnt <= delay_f;
                end
            endcase
        end
    end

endmodule
