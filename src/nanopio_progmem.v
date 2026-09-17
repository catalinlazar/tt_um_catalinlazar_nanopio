`default_nettype none
`timescale 1ns / 1ps

// Reprogrammable instruction store. Single synchronous write port (used by
// the loader), single combinational read port (used by the core fetch).
module nanopio_progmem #(
    parameter DEPTH  = 32,
    parameter AWIDTH = 5,
    parameter WWIDTH = 13
) (
    input  wire                 clk,
    input  wire                 we,
    input  wire [AWIDTH-1:0]    waddr,
    input  wire [WWIDTH-1:0]    wdata,
    input  wire [AWIDTH-1:0]    raddr,
    output wire [WWIDTH-1:0]    rdata
);

    reg [WWIDTH-1:0] mem [0:DEPTH-1];

`ifdef COCOTB_SIM
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = {WWIDTH{1'b0}};
    end
`endif

    always @(posedge clk) begin
        if (we)
            mem[waddr] <= wdata;
    end

    assign rdata = mem[raddr];

endmodule
