// SPDX-FileCopyrightText: 2026 Open Circuit Design LLC
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
// Original SPDX-FileCopyrightText: 2020 Efabless Corporation

`default_nettype none

//---------------------------------------------------------------
// housekeeping_spi.v
//---------------------------------------------------------------
// General purpose SPI module for the Caravel chip
//---------------------------------------------------------------
// Written by Tim Edwards
// efabless, inc., September 28, 2020
// Modified 3/2/2026:  Removed pass-through mode for simplicity.
//---------------------------------------------------------------
// This file is distributed free and open source
//---------------------------------------------------------------

// SCK ---   Clock input
// SDI ---   Data  input
// SDO ---   Data  output
// CSB ---   Chip  select (sense negative)
// idata --- Data from chip to transmit out, in 8 bits
// odata --- Input data to chip, in 8 bits
// addr  --- Decoded address to upstream circuits
// rdstb --- Read strobe, tells upstream circuit to supply next byte to idata
// wrstb --- Write strobe, tells upstream circuit to latch odata.

// Data format (general purpose):
// 8 bit format
// 1st byte:   Command word (see below)
// 2nd byte:   Address word (register 0 to 255)
// 3rd byte:   Data word    (value 0 to 255)

// Command format:
// 00000000  No operation
// 10000000  Write until CSB raised
// 01000000  Read  until CSB raised
// 11000000  Simultaneous read/write until CSB raised
// wrnnn000  Read/write as above, for nnn = 1 to 7 bytes, then terminate

// Lower three bits are reserved for future use.
// All serial bytes are read and written msb first.

`define COMMAND  3'b000
`define ADDRESS  3'b001
`define DATA     3'b010

module housekeeping_spi (reset, SCK, SDI, CSB, SDO,
	sdoena, idata, odata, oaddr, rdstb, wrstb);

    input reset;
    input SCK;
    input SDI;
    input CSB;
    output SDO;
    output sdoena;
    input [7:0] idata;
    output [7:0] odata;
    output [7:0] oaddr;
    output rdstb;
    output wrstb; 

    reg  [7:0]  addr;
    reg		wrstb;
    reg		rdstb;
    reg		sdoena;
    reg  [2:0]  state;
    reg  [2:0]  count;
    reg		writemode;
    reg		readmode;
    reg  [2:0]	fixed;
    wire [7:0]  odata;
    reg  [6:0]  predata;
    wire [7:0]  oaddr;
    reg  [7:0]  ldata;
    wire	csb_reset;

    assign odata = {predata, SDI};
    assign oaddr = (state == `ADDRESS) ? {addr[6:0], SDI} : addr;
    assign SDO = ldata[7];
    assign csb_reset = CSB | reset;

    // Readback data is captured on the falling edge of SCK so that
    // it is guaranteed valid at the next rising edge.

    always @(negedge SCK or posedge csb_reset) begin
        if (csb_reset == 1'b1) begin
            wrstb <= 1'b0;
            ldata  <= 8'b00000000;
            sdoena <= 1'b0;
        end else begin

            // After CSB low, 1st SCK starts command

            if (state == `DATA) begin
            	if (readmode == 1'b1) begin
                    sdoena <= 1'b1;
                    if (count == 3'b000) begin
                	ldata <= idata;
                    end else begin
                	ldata <= {ldata[6:0], 1'b0};	// Shift out
                    end
                end else begin
                    sdoena <= 1'b0;
                end

                // Apply write strobe on SCK negative edge on the next-to-last
                // data bit so that it updates data on the rising edge of SCK
                // on the last data bit.
 
                if (count == 3'b111) begin
                    if (writemode == 1'b1) begin
                        wrstb <= 1'b1;
                    end
                end else begin
                    wrstb <= 1'b0;
                end
            end else begin
                wrstb <= 1'b0;
                sdoena <= 1'b0;
            end		// ! state `DATA
        end		// ! csb_reset
    end			// always @ ~SCK

    always @(posedge SCK or posedge csb_reset) begin
        if (csb_reset == 1'b1) begin
            // Default state on reset
            addr <= 8'h00;
            rdstb <= 1'b0;
            predata <= 7'b0000000;
            state  <= `COMMAND;
            count  <= 3'b000;
            readmode <= 1'b0;
            writemode <= 1'b0;
            fixed <= 3'b000;
        end else begin
            // After csb_reset low, 1st SCK starts command
            if (state == `COMMAND) begin
                rdstb <= 1'b0;
                count <= count + 1;
        	if (count == 3'b000) begin
	            writemode <= SDI;
	        end else if (count == 3'b001) begin
	            readmode <= SDI;
	        end else if (count < 3'b101) begin
	            fixed <= {fixed[1:0], SDI}; 
	        end else if (count == 3'b111) begin
	            state <= `ADDRESS;
	        end
            end else if (state == `ADDRESS) begin
	        count <= count + 1;
	        addr <= {addr[6:0], SDI};
	        if (count == 3'b111) begin
	            if (readmode == 1'b1) begin
	            	rdstb <= 1'b1;
	            end
	            state <= `DATA;
		    if (readmode == 1'b1) begin
			rdstb <= 1'b1;
		    end
	        end else begin
	            rdstb <= 1'b0;
	        end
            end else if (state == `DATA) begin
	        predata <= {predata[6:0], SDI};
	        count <= count + 1;
	        if (count == 3'b111) begin
	            if (fixed == 3'b001) begin
	                state <= `COMMAND;
	            end else if (fixed != 3'b000) begin
	                fixed <= fixed - 1;
	                addr <= addr + 1;	// Auto increment address (fixed)
	            end else begin	
	                addr <= addr + 1;	// Auto increment address (streaming)
	            end
		    if (readmode == 1'b1) begin
			rdstb <= 1'b1;
		    end
	        end else begin
	            rdstb <= 1'b0;
	        end
            end		// ! state `DATA
        end		// ! csb_reset 
    end			// always @ SCK

endmodule // housekeeping_spi
`default_nettype wire
