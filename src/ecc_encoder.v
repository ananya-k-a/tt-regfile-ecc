// Generates 7 ECC check bits for a 32-bit data word.
// The data stays unchanged and only the check bits are added.

module ecc_encoder (
    input  wire [31:0] data_in_enc,
    output wire [6:0]  checkbits_out,
    output wire [31:0] data_out_enc
);

    wire [31:0] enc_in = data_in_enc;
    wire [6:0]  enc_checkbits;

    assign enc_checkbits[0] =
        enc_in[0]  ^ enc_in[1]  ^ enc_in[3]  ^ enc_in[4]  ^ enc_in[6]  ^ enc_in[8]  ^ enc_in[10] ^ enc_in[11] ^
        enc_in[13] ^ enc_in[15] ^ enc_in[17] ^ enc_in[19] ^ enc_in[21] ^ enc_in[23] ^ enc_in[25] ^ enc_in[26] ^
        enc_in[28] ^ enc_in[30];

    assign enc_checkbits[1] =
        enc_in[0]  ^ enc_in[2]  ^ enc_in[3]  ^ enc_in[5]  ^ enc_in[6]  ^ enc_in[9]  ^ enc_in[10] ^ enc_in[12] ^
        enc_in[13] ^ enc_in[16] ^ enc_in[17] ^ enc_in[20] ^ enc_in[21] ^ enc_in[24] ^ enc_in[25] ^ enc_in[27] ^
        enc_in[28] ^ enc_in[31];

    assign enc_checkbits[2] =
        enc_in[1]  ^ enc_in[2]  ^ enc_in[3]  ^ enc_in[7]  ^ enc_in[8]  ^ enc_in[9]  ^ enc_in[10] ^ enc_in[14] ^
        enc_in[15] ^ enc_in[16] ^ enc_in[17] ^ enc_in[22] ^ enc_in[23] ^ enc_in[24] ^ enc_in[25] ^ enc_in[29] ^
        enc_in[30] ^ enc_in[31];

    assign enc_checkbits[3] =
        enc_in[4]  ^ enc_in[5]  ^ enc_in[6]  ^ enc_in[7]  ^ enc_in[8]  ^ enc_in[9]  ^ enc_in[10] ^ enc_in[18] ^
        enc_in[19] ^ enc_in[20] ^ enc_in[21] ^ enc_in[22] ^ enc_in[23] ^ enc_in[24] ^ enc_in[25];

    assign enc_checkbits[4] =
        enc_in[11] ^ enc_in[12] ^ enc_in[13] ^ enc_in[14] ^ enc_in[15] ^ enc_in[16] ^ enc_in[17] ^ enc_in[18] ^
        enc_in[19] ^ enc_in[20] ^ enc_in[21] ^ enc_in[22] ^ enc_in[23] ^ enc_in[24] ^ enc_in[25];

    assign enc_checkbits[5] =
        enc_in[26] ^ enc_in[27] ^ enc_in[28] ^ enc_in[29] ^ enc_in[30] ^ enc_in[31];

    // overall parity: all 32 data bits XOR the 6 SEC checkbits above
    assign enc_checkbits[6] = (^enc_in) ^ (^enc_checkbits[5:0]);

    assign data_out_enc = enc_in;          // data is unchanged (systematic code)
    assign checkbits_out = enc_checkbits;  // the 7 generated checkbits

endmodule
