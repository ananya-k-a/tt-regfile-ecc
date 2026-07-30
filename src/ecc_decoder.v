// SEC-DED decoder for a 32-bit data word.
// Recomputes the 7 checkbits from the received data, compares against the
// received checkbits to form a 7-bit syndrome, then:
//   - syndrome == 0                     -> no error
//   - syndrome[6]==1, matches table     -> single-bit error, corrected
//   - syndrome[6]==1, no table match    -> single check-bit error (data OK, flagged)
//   - syndrome[6]==0, syndrome!=0       -> double-bit error, detected only
//   - syndrome[6]==1, syndrome[5:0]>38  -> flagged uncorrectable (multi-bit)
//
// error_type: 00 = no error, 01 = single (corrected), 10 = double error,
//             11 = uncorrectable / multiple error detected

module ecc_decoder (
    input  wire [31:0] data_in_dec,
    input  wire [6:0]  checkbits_in,
    output wire [1:0]  error_type,
    output wire [31:0] data_out_dec
);

    wire [31:0] dec_in = data_in_dec;
    wire [6:0]  chk_in = checkbits_in;

    wire [6:0]  dec_checkbits;
    wire [6:0]  syndrome;
    reg  [31:0] mask;

    assign dec_checkbits[0] =
        dec_in[0]  ^ dec_in[1]  ^ dec_in[3]  ^ dec_in[4]  ^ dec_in[6]  ^ dec_in[8]  ^ dec_in[10] ^ dec_in[11] ^
        dec_in[13] ^ dec_in[15] ^ dec_in[17] ^ dec_in[19] ^ dec_in[21] ^ dec_in[23] ^ dec_in[25] ^ dec_in[26] ^
        dec_in[28] ^ dec_in[30];

    assign dec_checkbits[1] =
        dec_in[0]  ^ dec_in[2]  ^ dec_in[3]  ^ dec_in[5]  ^ dec_in[6]  ^ dec_in[9]  ^ dec_in[10] ^ dec_in[12] ^
        dec_in[13] ^ dec_in[16] ^ dec_in[17] ^ dec_in[20] ^ dec_in[21] ^ dec_in[24] ^ dec_in[25] ^ dec_in[27] ^
        dec_in[28] ^ dec_in[31];

    assign dec_checkbits[2] =
        dec_in[1]  ^ dec_in[2]  ^ dec_in[3]  ^ dec_in[7]  ^ dec_in[8]  ^ dec_in[9]  ^ dec_in[10] ^ dec_in[14] ^
        dec_in[15] ^ dec_in[16] ^ dec_in[17] ^ dec_in[22] ^ dec_in[23] ^ dec_in[24] ^ dec_in[25] ^ dec_in[29] ^
        dec_in[30] ^ dec_in[31];

    assign dec_checkbits[3] =
        dec_in[4]  ^ dec_in[5]  ^ dec_in[6]  ^ dec_in[7]  ^ dec_in[8]  ^ dec_in[9]  ^ dec_in[10] ^ dec_in[18] ^
        dec_in[19] ^ dec_in[20] ^ dec_in[21] ^ dec_in[22] ^ dec_in[23] ^ dec_in[24] ^ dec_in[25];

    assign dec_checkbits[4] =
        dec_in[11] ^ dec_in[12] ^ dec_in[13] ^ dec_in[14] ^ dec_in[15] ^ dec_in[16] ^ dec_in[17] ^ dec_in[18] ^
        dec_in[19] ^ dec_in[20] ^ dec_in[21] ^ dec_in[22] ^ dec_in[23] ^ dec_in[24] ^ dec_in[25];

    assign dec_checkbits[5] =
        dec_in[26] ^ dec_in[27] ^ dec_in[28] ^ dec_in[29] ^ dec_in[30] ^ dec_in[31];

    // NOTE: this checkbit(6) formula XORs the received chk_in[5:0] directly
    // (not the recomputed dec_checkbits[5:0]), so that syndrome[6] below works
    // out to the overall parity of all 39 received bits.
    assign dec_checkbits[6] = (^dec_in) ^ (^chk_in[5:0]);

    assign syndrome = chk_in ^ dec_checkbits;

    assign data_out_dec = dec_in ^ mask;

    // Error/correction mask: identifies which single data bit (if any) to flip
    always @(*) begin
        case (syndrome)
            7'b0000000: mask = 32'h00000000; // no error

            7'b1000011: mask = 32'h00000001; // bit 0
            7'b1000101: mask = 32'h00000002; // bit 1
            7'b1000110: mask = 32'h00000004; // bit 2
            7'b1000111: mask = 32'h00000008; // bit 3
            7'b1001001: mask = 32'h00000010; // bit 4
            7'b1001010: mask = 32'h00000020; // bit 5
            7'b1001011: mask = 32'h00000040; // bit 6
            7'b1001100: mask = 32'h00000080; // bit 7
            7'b1001101: mask = 32'h00000100; // bit 8
            7'b1001110: mask = 32'h00000200; // bit 9
            7'b1001111: mask = 32'h00000400; // bit 10
            7'b1010001: mask = 32'h00000800; // bit 11
            7'b1010010: mask = 32'h00001000; // bit 12
            7'b1010011: mask = 32'h00002000; // bit 13
            7'b1010100: mask = 32'h00004000; // bit 14
            7'b1010101: mask = 32'h00008000; // bit 15
            7'b1010110: mask = 32'h00010000; // bit 16
            7'b1010111: mask = 32'h00020000; // bit 17
            7'b1011000: mask = 32'h00040000; // bit 18
            7'b1011001: mask = 32'h00080000; // bit 19
            7'b1011010: mask = 32'h00100000; // bit 20
            7'b1011011: mask = 32'h00200000; // bit 21
            7'b1011100: mask = 32'h00400000; // bit 22
            7'b1011101: mask = 32'h00800000; // bit 23
            7'b1011110: mask = 32'h01000000; // bit 24
            7'b1011111: mask = 32'h02000000; // bit 25
            7'b1100001: mask = 32'h04000000; // bit 26
            7'b1100010: mask = 32'h08000000; // bit 27
            7'b1100011: mask = 32'h10000000; // bit 28
            7'b1100100: mask = 32'h20000000; // bit 29
            7'b1100101: mask = 32'h40000000; // bit 30
            7'b1100110: mask = 32'h80000000; // bit 31

            default:   mask = 32'h00000000; // check-bit-only error, or no known match
        endcase
    end

    // Error classification. Positions 1..38 cover the whole codeword (32 data
    // bits + 6 SEC checkbits) with no gaps, so a valid single-bit error always
    // has syndrome[5:0] <= 38; anything above that is uncorrectable.
    reg [1:0] error_type_r;
    always @(*) begin
        if (syndrome[6] == 1'b0) begin
            error_type_r = (syndrome[5:0] == 6'b000000) ? 2'b00 : 2'b10; // no error : double error
        end else begin
            error_type_r = (syndrome[5:0] <= 6'd38) ? 2'b01 : 2'b11; // single (or check-bit) : uncorrectable
        end
    end
    assign error_type = error_type_r;

endmodule
