// SPDX-FileCopyrightText: 2026 Open Circuit Design, LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0
//
// Original SPDX-FileCopyrightText: 2020 Efabless Corporation

`default_nettype none
//----------------------------------------------------------
// SPI controller for Caravel openframe project
//----------------------------------------------------------
// Written by Tim Edwards
// efabless, inc. September 27, 2020
// Modified for the GF180MCU openframe project
// by Tim Edwards, Open Circuit Design, LLC
// December 2025
// Modified for the IHPSG13CMOS5L openframe projects
// by Tim Edwards, Open Circuit Design, LLC
// March 2026
//----------------------------------------------------------

//-----------------------------------------------------------
// This is a standalone SPI for the caravel chip that is
// intended to drive all functions required for the
// user project.
//
// This module has been adapted for the IHPSG13CMOS5L
// openframe architecture.
//
// For this openframe project, the requirement is 128 bits
// of read (status) and write (control) data.
//
//-----------------------------------------------------------

//------------------------------------------------------------
// Caravel openframe project defined registers:
// Register 0:  SPI status and control (unused & reserved)
// Register 1 and 2:  Manufacturer ID (0x0567) (readonly)
// Register 3:  Product ID (= 24) (readonly)
// Register 4-7: Mask revision (readonly) --- Externally programmed
//	with via programming.  Via programmed with a script to match
//	each project ID.
//
// Register 8:    reset (1 bit)
// Register 9-24: control/status bits (TBD by project)
//------------------------------------------------------------

module housekeeping (
`ifdef USE_POWER_PINS
    VPWR, VGND, 
`endif
    RSTB, SCK, SDI, CSB, SDO, sdo_ena,
    reset, mask_rev_in,
    control, status
);

`ifdef USE_POWER_PINS
    inout VPWR;	    // 1.8V supply
    inout VGND;	    // common ground
`endif
    
    input RSTB;	    // from padframe
    input SCK;	    // from padframe
    input SDI;	    // from padframe
    input CSB;	    // from padframe
    output SDO;	    // to padframe
    output sdo_ena; // to padframe
    output [127:0] control;	// to project
    input [127:0]  status;	// from project

    output reset;
    input [31:0] mask_rev_in;	// metal programmed;  3.3V domain

    reg [127:0] control;

    reg reset_reg;

    wire [7:0] odata;
    wire [7:0] idata;
    wire [7:0] iaddr;

    wire rdstb;
    wire wrstb;
    wire loc_sdo;

    assign SDO = loc_sdo;
    assign reset = reset_reg;

    // Instantiate the SPI interface

    housekeeping_spi spi (
	.reset(~RSTB),
    	.SCK(SCK),
    	.SDI(SDI),
    	.CSB(CSB),
    	.SDO(loc_sdo),
    	.sdoena(sdo_ena),
    	.idata(odata),
    	.odata(idata),
    	.oaddr(iaddr),
    	.rdstb(rdstb),
    	.wrstb(wrstb)
    );

    wire [11:0] mfgr_id;
    wire [7:0]  prod_id;
    wire [31:0] mask_rev;

    assign mfgr_id = 12'h567;		// Hard-coded
    assign prod_id = 8'h17;		// Hard-coded
    assign mask_rev = mask_rev_in;	// Copy in to out.

    // Send register contents to odata on SPI read command
    // All values are 1-4 bits and no shadow registers are required.

    assign odata = 
    (iaddr == 8'h00) ? 8'h00 :	// SPI status (fixed)
    (iaddr == 8'h01) ? {4'h0, mfgr_id[11:8]} :	// Manufacturer ID (fixed)
    (iaddr == 8'h02) ? mfgr_id[7:0] :	// Manufacturer ID (fixed)
    (iaddr == 8'h03) ? prod_id :	// Product ID (fixed)
    (iaddr == 8'h04) ? mask_rev[31:24] :	// Mask rev (metal programmed)
    (iaddr == 8'h05) ? mask_rev[23:16] :	// Mask rev (metal programmed)
    (iaddr == 8'h06) ? mask_rev[15:8] :		// Mask rev (metal programmed)
    (iaddr == 8'h07) ? mask_rev[7:0] :		// Mask rev (metal programmed)

    (iaddr == 8'h08) ? {7'b000000, reset} :
    (iaddr == 8'h09) ? control[7:0] :
    (iaddr == 8'h0a) ? control[15:8] :
    (iaddr == 8'h0b) ? control[23:16] :
    (iaddr == 8'h0c) ? control[31:24] :
    (iaddr == 8'h0d) ? control[39:32] :
    (iaddr == 8'h0e) ? control[47:40] :
    (iaddr == 8'h0f) ? control[55:48] :
    (iaddr == 8'h10) ? control[63:56] :
    (iaddr == 8'h11) ? control[71:64] :
    (iaddr == 8'h12) ? control[79:72] :
    (iaddr == 8'h13) ? control[87:80] :
    (iaddr == 8'h14) ? control[95:88] :
    (iaddr == 8'h15) ? control[103:96] :
    (iaddr == 8'h16) ? control[111:104] :
    (iaddr == 8'h17) ? control[119:112] :
    (iaddr == 8'h18) ? control[127:120] :
    (iaddr == 8'h19) ? status[7:0] :
    (iaddr == 8'h1a) ? status[15:8] :
    (iaddr == 8'h1b) ? status[23:16] :
    (iaddr == 8'h1c) ? status[31:24] :
    (iaddr == 8'h1d) ? status[39:32] :
    (iaddr == 8'h1e) ? status[47:40] :
    (iaddr == 8'h1f) ? status[55:48] :
    (iaddr == 8'h20) ? status[63:56] :
    (iaddr == 8'h21) ? status[71:64] :
    (iaddr == 8'h22) ? status[79:72] :
    (iaddr == 8'h23) ? status[87:80] :
    (iaddr == 8'h24) ? status[95:88] :
    (iaddr == 8'h25) ? status[103:96] :
    (iaddr == 8'h26) ? status[111:104] :
    (iaddr == 8'h27) ? status[119:112] :
    (iaddr == 8'h28) ? status[127:120] :
               8'h00;	// Default

    // Register mapping and I/O to module

    always @(posedge SCK or negedge RSTB) begin
    if (RSTB == 1'b0) begin
        // Set trim for DLL at (almost) slowest rate (~90MHz).  However,
        // dll_trim[12] must be set to zero for proper startup.
	control <= 128'd0;
        reset_reg <= 1'b0;
    end else if (wrstb == 1'b1) begin
        case (iaddr)
        8'h08: begin
             reset_reg <= idata[0];
               end
        8'h09: begin
	     control[7:0] <= idata;
               end
        8'h0a: begin
	     control[15:8] <= idata;
               end
        8'h0b: begin
	     control[23:16] <= idata;
               end
        8'h0c: begin
	     control[31:24] <= idata;
               end
        8'h0d: begin
	     control[39:32] <= idata;
               end
        8'h0e: begin
	     control[47:40] <= idata;
               end
        8'h0f: begin
	     control[55:48] <= idata;
               end
        8'h10: begin
	     control[63:56] <= idata;
               end
        8'h11: begin
	     control[71:64] <= idata;
               end
        8'h12: begin
	     control[79:72] <= idata;
               end
        8'h13: begin
	     control[87:80] <= idata;
	       end
        8'h14: begin
	     control[95:88] <= idata;
	       end
        8'h15: begin
	     control[103:96] <= idata;
	       end
        8'h16: begin
	     control[111:104] <= idata;
	       end
        8'h17: begin
	     control[119:112] <= idata;
	       end
        8'h18: begin
	     control[127:120] <= idata;
	       end
        endcase	// (iaddr)
    end
    end
endmodule	// housekeeping

`default_nettype wire
