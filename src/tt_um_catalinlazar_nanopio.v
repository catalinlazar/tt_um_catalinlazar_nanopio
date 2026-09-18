`default_nettype none
`timescale 1ns / 1ps

// tt_um_catalinlazar_nanopio
//
// nanoPIO: a tiny reprogrammable I/O engine (RP2040 PIO inspired).
//
// Pinout:
//   ui_in[4:0]  general-purpose inputs (WAIT / IN source) while not loading
//   ui_in[5]    LOAD_DATA  (loader serial data in, MSB first)
//   ui_in[6]    LOAD_CLK   (loader bit clock)
//   ui_in[7]    LOAD_EN    (1 = reprogramming mode, core execution held)
//   uo_out[7:0] primary PIO output pins (driven by OUT/SET PINS)
//   uio[7:0]    secondary PIO output pins, always driven as outputs
module tt_um_catalinlazar_nanopio (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    localparam AWIDTH = 4;   // log2(16) -- instruction memory depth
    localparam WWIDTH = 13;  // instruction word width
    localparam DEPTH  = 16;

    wire load_en   = ui_in[7];
    wire load_clk  = ui_in[6];
    wire load_data = ui_in[5];

    wire              loader_we;
    wire [AWIDTH-1:0] loader_waddr;
    wire [WWIDTH-1:0] loader_wdata;

    wire [AWIDTH-1:0] core_pc;
    wire [WWIDTH-1:0] core_instr;

    // ignore program-visible inputs while a reprogramming load is in flight
    wire [7:0] core_ui_in = load_en ? 8'd0 : ui_in;
    wire       run_en     = ena && !load_en;

    nanopio_loader #(
        .AWIDTH (AWIDTH),
        .WWIDTH (WWIDTH)
    ) u_loader (
        .clk       (clk),
        .rst_n     (rst_n),
        .load_en   (load_en),
        .load_clk  (load_clk),
        .load_data (load_data),
        .we        (loader_we),
        .waddr     (loader_waddr),
        .wdata     (loader_wdata)
    );

    nanopio_progmem #(
        .DEPTH  (DEPTH),
        .AWIDTH (AWIDTH),
        .WWIDTH (WWIDTH)
    ) u_progmem (
        .we    (loader_we),
        .waddr (loader_waddr),
        .wdata (loader_wdata),
        .raddr (core_pc),
        .rdata (core_instr)
    );

    nanopio_core #(
        .AWIDTH (AWIDTH)
    ) u_core (
        .clk     (clk),
        .rst_n   (rst_n),
        .run_en  (run_en),
        .ui_in   (core_ui_in),
        .uo_out  (uo_out),
        .uio_out (uio_out),
        .pc_o    (core_pc),
        .instr   (core_instr)
    );

    assign uio_oe = 8'hFF; // uio bus is output-only in v1

    // silence unused-signal lint (uio_in is reserved for a future
    // bidirectional-pin revision; ena already gates run_en)
    wire _unused = &{1'b0, uio_in, ena, 1'b0};

endmodule
