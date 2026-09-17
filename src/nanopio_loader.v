`default_nettype none
`timescale 1ns / 1ps

// Serial reprogramming loader.
//
// Protocol (all relative to ui_in while ui_in[7]=load_en is held high):
//   ui_in[6] = LOAD_CLK  (bit clock, synchronized internally, rising-edge sampled)
//   ui_in[5] = LOAD_DATA (serial data, MSB first)
//
// Each frame is AWIDTH+WWIDTH bits: address (AWIDTH bits) then instruction
// (WWIDTH bits), MSB first. After a full frame is shifted in, it is written
// to progmem[addr] on the same clock edge. Frames can be sent back-to-back
// for as long as load_en stays high; any address can be rewritten at will.
// Dropping load_en resets the bit counter (a partial frame is discarded).
module nanopio_loader #(
    parameter AWIDTH = 5,
    parameter WWIDTH = 13
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  load_en,
    input  wire                  load_clk,
    input  wire                  load_data,
    output reg                   we,
    output reg  [AWIDTH-1:0]     waddr,
    output reg  [WWIDTH-1:0]     wdata
);

    localparam FRAME_BITS = AWIDTH + WWIDTH;
    localparam CNT_W      = $clog2(FRAME_BITS + 1);

    reg [1:0] clk_sync;
    reg [FRAME_BITS-1:0] shreg;
    reg [CNT_W-1:0] bitcnt;

    wire load_clk_rise = (clk_sync == 2'b01);
    wire [FRAME_BITS-1:0] next_shreg = {shreg[FRAME_BITS-2:0], load_data};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_sync <= 2'b00;
            shreg    <= {FRAME_BITS{1'b0}};
            bitcnt   <= {CNT_W{1'b0}};
            we       <= 1'b0;
            waddr    <= {AWIDTH{1'b0}};
            wdata    <= {WWIDTH{1'b0}};
        end else begin
            we <= 1'b0;
            clk_sync <= {clk_sync[0], load_clk};

            if (!load_en) begin
                bitcnt <= {CNT_W{1'b0}};
            end else if (load_clk_rise) begin
                shreg <= next_shreg;
                if (bitcnt == FRAME_BITS - 1) begin
                    waddr  <= next_shreg[FRAME_BITS-1 -: AWIDTH];
                    wdata  <= next_shreg[WWIDTH-1:0];
                    we     <= 1'b1;
                    bitcnt <= {CNT_W{1'b0}};
                end else begin
                    bitcnt <= bitcnt + 1'b1;
                end
            end
        end
    end

endmodule
