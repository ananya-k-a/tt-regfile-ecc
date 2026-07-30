// tt_um_aka_regfile_ecc.v
// TinyTapeout top-level wrapper for regfile_ecc_hk (housekeeping SPI +
// ECC-protected single-register regfile_ecc, NUM_REG=1).
//
// Pin mapping:
//   ui_in[0]  -> SCK
//   ui_in[1]  -> SDI
//   ui_in[2]  -> CSB
//   ui_in[3:7]  unused
//   uio_out[0] -> SDO
//   uio_oe[0]  -> sdo_ena (output enable for SDO)
//   uio[1:7]    unused (set as inputs, driven low)
//   uo_out[7:0] unused (tied to 0)
//   mask_rev_in tied to a constant (metal-programmed in a real chip; no pin needed)
//   clk, rst_n use TinyTapeout's built-in clk / rst_n

`default_nettype none

module tt_um_aka_regfile_ecc (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // Unused TinyTapeout signals
    wire _unused = &{ena, uio_in[7:1], 1'b0};

    // No dedicated outputs used on uo_out
    assign uo_out = 8'd0;

    // Only uio[0] is used (SDO / sdo_ena); rest are inputs, driven low
    assign uio_oe[7:1]  = 7'd0;
    assign uio_out[7:1] = 7'd0;

    regfile_ecc_hk wrapper (
        .clk(clk),
        .RSTB(rst_n),
        .SCK(ui_in[0]),
        .SDI(ui_in[1]),
        .CSB(ui_in[2]),
        .SDO(uio_out[0]),
        .sdo_ena(uio_oe[0]),
        .mask_rev_in(32'd0)
    );

endmodule

`default_nettype wire
