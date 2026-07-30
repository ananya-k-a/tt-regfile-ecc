// ECC-protected register bank: NUM_REG registers x 32 bits.
// Data and checkbits are stored in flip-flops.
// One shared encoder on the write port, two decoders (one per read port).

module regfile_ecc #(
    parameter NUM_REG = 16,
    localparam ADDR_W = (NUM_REG > 1) ? $clog2(NUM_REG) : 1
) (
    input  wire        clk,
    input  wire        we,
    input  wire [ADDR_W-1:0] waddr,
    input  wire [31:0] wdata,
    input  wire [ADDR_W-1:0] raddr1,
    input  wire [ADDR_W-1:0] raddr2,
    input wire [31:0] data_error_mask1,
    input wire [6:0]  chk_error_mask1,
    input wire [31:0] data_error_mask2,
    input wire [6:0]  chk_error_mask2,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2,
    output wire  [1:0] error_type1,
    output wire  [1:0] error_type2
);

    // NUM_REG registers of 32-bit data
    reg [31:0] data_mem [0:NUM_REG-1];

    // NUM_REG registers of 7-bit ECC checkbits
    reg [6:0] chk_mem [0:NUM_REG-1];

    wire [6:0] wchk;

    // Generate ECC bits for incoming data
    ecc_encoder enc (
        .data_in_enc   (wdata),
        .checkbits_out (wchk),
        .data_out_enc  ()
    );


    // Write port
    always @(posedge clk) begin
        if (we) begin
            data_mem[waddr] <= wdata;
            chk_mem[waddr]  <= wchk;
        end
    end


    // Read port 1
    ecc_decoder dec1 (
        .data_in_dec  (data_mem[raddr1] ^ data_error_mask1),
        .checkbits_in (chk_mem[raddr1] ^ chk_error_mask1),
        .error_type   (error_type1),
        .data_out_dec (rdata1)
    );


    // Read port 2
    ecc_decoder dec2 (
        .data_in_dec  (data_mem[raddr2] ^ data_error_mask2),
        .checkbits_in (chk_mem[raddr2] ^ chk_error_mask2),
        .error_type   (error_type2),
        .data_out_dec (rdata2)
    );


endmodule
