// regfile_ecc_hk.v
// Wrapper connecting regfile_ecc (NUM_REG=1) to the housekeeping SPI
// control/status interface. Only read port 1 is exposed over SPI.

`default_nettype none

module regfile_ecc_hk (
`ifdef USE_POWER_PINS
    inout VPWR,
    inout VGND,
`endif
    input  wire        clk,
    input  wire        RSTB,
    input  wire        SCK,
    input  wire        SDI,
    input  wire        CSB,
    output wire        SDO,
    output wire        sdo_ena,
    input  wire [31:0] mask_rev_in
);

    wire         hk_reset;
    wire [127:0] control;
    wire [127:0] status;

    assign status[127:40] = 88'd0;
    assign status[39:34]  = 6'd0;

    housekeeping hk (
`ifdef USE_POWER_PINS
        .VPWR(VPWR),
        .VGND(VGND),
`endif
        .RSTB(RSTB),
        .SCK(SCK),
        .SDI(SDI),
        .CSB(CSB),
        .SDO(SDO),
        .sdo_ena(sdo_ena),
        .reset(hk_reset),
        .mask_rev_in(mask_rev_in),
        .control(control),
        .status(status)
    );

    regfile_ecc #(
        .NUM_REG(1)
    ) dut (
        .clk(clk),
        .we(control[0]),
        .waddr(1'b0),
        .wdata(control[39:8]),
        .raddr1(1'b0),
        .raddr2(1'b0),
        .data_error_mask1(control[71:40]),
        .chk_error_mask1(control[78:72]),
        .data_error_mask2(32'd0),
        .chk_error_mask2(7'd0),
        .rdata1(status[31:0]),
        .error_type1(status[33:32])
    );

endmodule // regfile_ecc_hk

`default_nettype wire
