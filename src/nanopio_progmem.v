`default_nettype none
`timescale 1ns / 1ps

// Reprogrammable instruction store, built from per-word level-sensitive
// latches rather than flip-flops. `we`/`waddr`/`wdata` are already
// registered by nanopio_loader, so each is stable for a full clk period;
// gating each word's latch with `we && (waddr == word)` is therefore a
// synchronous, glitch-free one-cycle-wide enable (not a combinational
// clock gate). This roughly halves per-bit storage area vs. a D-FF and
// removes the write-side hold/feedback mux that an enable-less FF would
// otherwise need, which matters because this PDK's standard-cell library
// has no plain (reset-less) D-FF to map an enable-controlled register to.
//
// Single write port (used by the loader), single combinational read port
// (used by the core fetch).
module nanopio_progmem #(
    parameter DEPTH  = 16,
    parameter AWIDTH = 4,
    parameter WWIDTH = 13
) (
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

    // Shared one-hot address decode, reused as each word's latch enable
    // instead of letting synthesis build 32 independent AWIDTH-bit
    // equality comparators (which cost far more logic than one decoder).
    wire [DEPTH-1:0] waddr_1h = {{(DEPTH-1){1'b0}}, 1'b1} << waddr;

    genvar w;
    generate
        for (w = 0; w < DEPTH; w = w + 1) begin : word
            wire gate = we && waddr_1h[w];
            /* verilator lint_off LATCH */
            always @(*)
                if (gate)
                    mem[w] = wdata;
            /* verilator lint_on LATCH */
        end
    endgenerate

    assign rdata = mem[raddr];

endmodule
