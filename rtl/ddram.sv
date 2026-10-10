//
// ddram.v
// Copyright (c) 2020 Sorgelig
//
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version. 
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
// ------------------------------------------
//


module ddram
(
	output         DDRAM_CLK,
	input          DDRAM_BUSY,
	output [ 7: 0] DDRAM_BURSTCNT,
	output [28: 0] DDRAM_ADDR,
	input  [63: 0] DDRAM_DOUT,
	input          DDRAM_DOUT_READY,
	output         DDRAM_RD,
	output [63: 0] DDRAM_DIN,
	output [ 7: 0] DDRAM_BE,
	output         DDRAM_WE,
	
	input          clk,
	input          rst,

	input  [17: 1] ramh_addr,
	output [15: 0] ramh_dout,
	input  [15: 0] ramh_din,
	input          ramh_rd,
	input  [ 1: 0] ramh_wr,
	output         ramh_busy
);

reg  [ 26:  1] ram_address;
reg  [ 63:  0] ram_din;
reg  [  7:  0] ram_be;
reg  [  7:  0] ram_burst;
reg            ram_read = 0;
reg            ram_write = 0;
reg  [  3:  0] ram_chan;

reg  [ 17:  1] ramh_rcache_addr[4];
reg            ramh_rcache_dirty[4];
reg            ramh_rcache_busy;
reg            ramh_read_busy[4];
reg  [  1:  0] ramh_rcache_curr;
reg  [  1:  0] ramh_rcache_lru[4];

reg  [  2:  0] state = 0;

reg  [  6:  0] cache_wraddr;
reg            cache_update;

reg            old_rst;
reg            ramh_rd_old,ramh_wr_old;
always @(posedge clk) begin
	{ramh_rd_old,ramh_wr_old} <= {ramh_rd,|ramh_wr};
	old_rst <= rst;
end
wire           rst_pulse = (rst && !old_rst);

wire           ramh_fifo_wrreq,ramh_fifo_rdreq;
always_comb begin
	ramh_fifo_wrreq = (|ramh_wr && !ramh_wr_old);
	ramh_fifo_rdreq = (state == 3'h1 && !DDRAM_BUSY && ram_chan == 4'd0);
end

wire [ 34:  0] ramh_fifo_dout;
wire           ramh_fifo_empty,ramh_fifo_full;

ddr_infifo #(3) ramh_fifo (clk, rst_pulse, {ramh_addr,ramh_wr,ramh_din}, ramh_fifo_wrreq, ramh_fifo_rdreq, ramh_fifo_dout, ramh_fifo_empty, ramh_fifo_full);

wire [ 17:  1] ramh_write_addr;
wire [ 15:  0] ramh_write_data;
wire [  1:  0] ramh_write_be;

assign {ramh_write_addr,ramh_write_be,ramh_write_data} = ramh_fifo_dout;

wire           ramh_ram_sel = !ramh_addr[17:15];
wire [ 15:  0] ramh_ram_q;
ddr_ram #(14) ramh_ram (clk, ramh_addr[14:1], ramh_din, ramh_wr & {2{ramh_ram_sel}}, ramh_addr[14:1], ramh_ram_q);

always @(posedge clk) begin
	bit write,read,burst_read;
	bit [3:0] chan;
	bit [6:0] word_cnt;

	{ramh_rcache_busy} <= '0;
	if (rst_pulse) begin		
		{ramh_rcache_dirty[0],ramh_rcache_dirty[1],ramh_rcache_dirty[2],ramh_rcache_dirty[3]} <= '1;
		{ramh_read_busy[0],ramh_read_busy[1],ramh_read_busy[2],ramh_read_busy[3]} <= '0;
		ramh_rcache_curr <= 2'd0;
		ramh_rcache_lru[0] <= 2'd3; 
		ramh_rcache_lru[1] <= 2'd2;
		ramh_rcache_lru[2] <= 2'd1;
		ramh_rcache_lru[3] <= 2'd0;
	end
	else begin
		if (ramh_rd && !ramh_rd_old && !ramh_ram_sel) begin
			if (ramh_addr[17:5] == ramh_rcache_addr[0][17:5] && !ramh_rcache_dirty[0]) begin
				ramh_rcache_addr[0] <= ramh_addr[17:1];
				ramh_rcache_curr <= 2'd0;
				if (ramh_rcache_lru[0] == 2'd0) begin ramh_rcache_lru[0] <= ramh_rcache_lru[1]; ramh_rcache_lru[1] <= ramh_rcache_lru[2]; ramh_rcache_lru[2] <= ramh_rcache_lru[3];  ramh_rcache_lru[3] <= 2'd0; end
				if (ramh_rcache_lru[1] == 2'd0) begin                                           ramh_rcache_lru[1] <= ramh_rcache_lru[2]; ramh_rcache_lru[2] <= ramh_rcache_lru[3];  ramh_rcache_lru[3] <= 2'd0; end
				if (ramh_rcache_lru[2] == 2'd0) begin                                                                                     ramh_rcache_lru[2] <= ramh_rcache_lru[3];  ramh_rcache_lru[3] <= 2'd0; end
			end
			else if (ramh_addr[17:5] == ramh_rcache_addr[1][17:5] && !ramh_rcache_dirty[1]) begin
				ramh_rcache_addr[1] <= ramh_addr[17:1];
				ramh_rcache_curr <= 2'd1;
				if (ramh_rcache_lru[0] == 2'd1) begin ramh_rcache_lru[0] <= ramh_rcache_lru[1]; ramh_rcache_lru[1] <= ramh_rcache_lru[2]; ramh_rcache_lru[2] <= ramh_rcache_lru[3];  ramh_rcache_lru[3] <= 2'd1; end
				if (ramh_rcache_lru[1] == 2'd1) begin                                           ramh_rcache_lru[1] <= ramh_rcache_lru[2]; ramh_rcache_lru[2] <= ramh_rcache_lru[3];  ramh_rcache_lru[3] <= 2'd1; end
				if (ramh_rcache_lru[2] == 2'd1) begin                                                                                     ramh_rcache_lru[2] <= ramh_rcache_lru[3];  ramh_rcache_lru[3] <= 2'd1; end
			end
			else if (ramh_addr[17:5] == ramh_rcache_addr[2][17:5] && !ramh_rcache_dirty[2]) begin
				ramh_rcache_addr[2] <= ramh_addr[17:1];
				ramh_rcache_curr <= 2'd2;
				if (ramh_rcache_lru[0] == 2'd2) begin ramh_rcache_lru[0] <= ramh_rcache_lru[1]; ramh_rcache_lru[1] <= ramh_rcache_lru[2]; ramh_rcache_lru[2] <= ramh_rcache_lru[3];  ramh_rcache_lru[3] <= 2'd2; end
				if (ramh_rcache_lru[1] == 2'd2) begin                                           ramh_rcache_lru[1] <= ramh_rcache_lru[2]; ramh_rcache_lru[2] <= ramh_rcache_lru[3];  ramh_rcache_lru[3] <= 2'd2; end
				if (ramh_rcache_lru[2] == 2'd2) begin                                                                                     ramh_rcache_lru[2] <= ramh_rcache_lru[3];  ramh_rcache_lru[3] <= 2'd2; end
			end
			else if (ramh_addr[17:5] == ramh_rcache_addr[3][17:5] && !ramh_rcache_dirty[3]) begin
				ramh_rcache_addr[3] <= ramh_addr[17:1];
				ramh_rcache_curr <= 2'd3;
				if (ramh_rcache_lru[0] == 2'd3) begin ramh_rcache_lru[0] <= ramh_rcache_lru[1]; ramh_rcache_lru[1] <= ramh_rcache_lru[2]; ramh_rcache_lru[2] <= ramh_rcache_lru[3];  ramh_rcache_lru[3] <= 2'd3; end
				if (ramh_rcache_lru[1] == 2'd3) begin                                           ramh_rcache_lru[1] <= ramh_rcache_lru[2]; ramh_rcache_lru[2] <= ramh_rcache_lru[3];  ramh_rcache_lru[3] <= 2'd3; end
				if (ramh_rcache_lru[2] == 2'd3) begin                                                                                     ramh_rcache_lru[2] <= ramh_rcache_lru[3];  ramh_rcache_lru[3] <= 2'd3; end
			end
			else begin
				ramh_rcache_addr[ramh_rcache_lru[0]] <= ramh_addr[17:1];
				ramh_read_busy[ramh_rcache_lru[0]] <= 1;
				ramh_rcache_dirty[ramh_rcache_lru[0]] <= 0;
				ramh_rcache_curr <= ramh_rcache_lru[0];
				ramh_rcache_lru[0] <= ramh_rcache_lru[1]; ramh_rcache_lru[1] <= ramh_rcache_lru[2]; ramh_rcache_lru[2] <= ramh_rcache_lru[3];  ramh_rcache_lru[3] <= ramh_rcache_lru[0];
			end
		end
	end
		
	if (rst_pulse) begin
		
	end
	else begin
		if (|ramh_wr && !ramh_wr_old) begin
			if (ramh_addr[17:5] == ramh_rcache_addr[0][17:5]) begin
				ramh_rcache_addr[0] <= '1;
				ramh_rcache_dirty[0] <= 1;
			end	
			if (ramh_addr[17:5] == ramh_rcache_addr[1][17:5]) begin
				ramh_rcache_addr[1] <= '1;
				ramh_rcache_dirty[1] <= 1;
			end
			if (ramh_addr[17:5] == ramh_rcache_addr[2][17:5]) begin
				ramh_rcache_addr[2] <= '1;
				ramh_rcache_dirty[2] <= 1;
			end
			if (ramh_addr[17:5] == ramh_rcache_addr[3][17:5]) begin
				ramh_rcache_addr[3] <= '1;
				ramh_rcache_dirty[3] <= 1;
			end
		end
	end
	
	if (rst_pulse) begin
		state <= '0;
		ram_write <= 0;
		ram_read  <= 0;
	end
	else if(!DDRAM_BUSY) begin
		ram_write <= 0;
		ram_read  <= 0;

		case (state)
			0: begin
				if (!ramh_fifo_empty) begin
					ram_address <= {9'b000000000,ramh_write_addr[17:3],2'b00};
					ram_din		<= {4{ramh_write_data}};
					case (ramh_write_addr[2:1])
						2'b00: ram_be <= {ramh_write_be,6'b000000};
						2'b01: ram_be <= {2'b00,ramh_write_be,4'b0000};
						2'b10: ram_be <= {4'b0000,ramh_write_be,2'b00};
						2'b11: ram_be <= {6'b000000,ramh_write_be};
					endcase
					ram_write 	<= 1;
					ram_burst   <= 1;
					ram_chan    <= 4'd0;
					state       <= 3'h1;
				end
				else if (ramh_read_busy[0]) begin
					ram_address <= {9'b000000000,ramh_rcache_addr[0][17:5],4'b0000};
					ram_be      <= 8'hFF;
					ram_read    <= 1;
					ram_burst   <= 4;
					ram_chan    <= 4'd0;
					cache_wraddr<= '0;
					word_cnt    <= '0;
					state       <= 3'h2;
				end
				else if (ramh_read_busy[1]) begin
					ram_address <= {9'b000000000,ramh_rcache_addr[1][17:5],4'b0000};
					ram_be      <= 8'hFF;
					ram_read    <= 1;
					ram_burst   <= 4;
					ram_chan    <= 4'd0;
					cache_wraddr<= '0;
					word_cnt    <= '0;
					state       <= 3'h2;
				end
				else if (ramh_read_busy[2]) begin
					ram_address <= {9'b000000000,ramh_rcache_addr[2][17:5],4'b0000};
					ram_be      <= 8'hFF;
					ram_read    <= 1;
					ram_burst   <= 4;
					ram_chan    <= 4'd0;
					cache_wraddr<= '0;
					word_cnt    <= '0;
					state       <= 3'h2;
				end
				else if (ramh_read_busy[3]) begin
					ram_address <= {9'b000000000,ramh_rcache_addr[3][17:5],4'b0000};
					ram_be      <= 8'hFF;
					ram_read    <= 1;
					ram_burst   <= 4;
					ram_chan    <= 4'd0;
					cache_wraddr<= '0;
					word_cnt    <= '0;
					state       <= 3'h2;
				end
			end

			3'h1: begin
				state <= 0;
			end
		
			3'h2: if (DDRAM_DOUT_READY) begin
				cache_wraddr <= cache_wraddr + 7'd1;
				word_cnt <= word_cnt + 7'd1;
				if (word_cnt == ram_burst[6:0] - 7'd1) begin
					if (ram_chan == 4'd0 ) begin ramh_read_busy[ramh_rcache_curr] <= 0; ramh_rcache_busy <= 1; end
					state <= 0;
				end
			end
		endcase
	end
end

wire           cache_wren = (state == 3'h2) && DDRAM_DOUT_READY && !DDRAM_BUSY;
wire [ 63:  0] ramh_cache_q;

ddr_cache_ram2 #(4) cache0 (clk, {ramh_rcache_curr,cache_wraddr[1:0]}, DDRAM_DOUT, cache_wren & ram_chan == 0, {ramh_rcache_curr,ramh_addr[4:3]}, ramh_cache_q);

always_comb begin
	if (ramh_ram_sel)
		ramh_dout = ramh_ram_q;
	else
		case (ramh_rcache_addr[ramh_rcache_curr][2:1])
			2'b00: ramh_dout = ramh_cache_q[63:48];
			2'b01: ramh_dout = ramh_cache_q[47:32];
			2'b10: ramh_dout = ramh_cache_q[31:16];
			2'b11: ramh_dout = ramh_cache_q[15:00];
		endcase
	ramh_busy = ramh_fifo_full | ramh_read_busy[0] | ramh_read_busy[1] | ramh_read_busy[2] | ramh_read_busy[3] | ramh_rcache_busy;
end

assign DDRAM_CLK      = clk;
assign DDRAM_BURSTCNT = ram_burst;
assign DDRAM_BE       = ram_be;
assign DDRAM_ADDR     = {5'b00110, ram_address[26:3]}; // RAM at 0x30000000
assign DDRAM_RD       = ram_read;
assign DDRAM_DIN      = ram_din;
assign DDRAM_WE       = ram_write;

endmodule


module ddr_cache_ram #(parameter wa = 2) (
	clock,
	wraddress,
	data,
	wren,
	rdaddress,
	q);

	input	  clock;
	input	[wa-1:0]  wraddress;
	input	[63:0] data;
	input	       wren;
	input	[wa-1:0]  rdaddress;
	output	[63:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0	  wren;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire [63:0] sub_wire0;
	wire [63:0] q = sub_wire0;

	altdpram	altdpram_component (
				.data (data),
				.inclock (clock),
				.rdaddress (rdaddress),
				.wraddress (wraddress),
				.wren (wren),
				.q (sub_wire0),
				.aclr (1'b0),
				.byteena (1'b1),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
				//.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram_component.indata_aclr = "OFF",
		altdpram_component.indata_reg = "INCLOCK",
		altdpram_component.intended_device_family = "Cyclone V",
		altdpram_component.lpm_type = "altdpram",
		altdpram_component.outdata_aclr = "OFF",
		altdpram_component.outdata_reg = "UNREGISTERED",
		altdpram_component.power_up_uninitialized = "TRUE",
		altdpram_component.ram_block_type = "MLAB",
		altdpram_component.rdaddress_aclr = "OFF",
		altdpram_component.rdaddress_reg = "UNREGISTERED",
		altdpram_component.rdcontrol_aclr = "OFF",
		altdpram_component.rdcontrol_reg = "UNREGISTERED",
		altdpram_component.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component.width = 64,
		altdpram_component.widthad = wa,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";

endmodule

module ddr_cache_ram2 #(parameter wa = 2) (
	clock,
	wraddress,
	data,
	wren,
	rdaddress,
	q);

	input	  clock;
	input	[wa-1:0]  wraddress;
	input	[63:0] data;
	input	       wren;
	input	[wa-1:0]  rdaddress;
	output	[63:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0	  wren;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire [63:0] sub_wire0;
	wire [63:0] q = sub_wire0;

	altsyncram	altsyncram_component (
				.address_a (wraddress),
				.byteena_a (1'b1),
				.clock0 (clock),
				.data_a (data),
				.wren_a (wren),
				.address_b (rdaddress),
				.q_b (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({64{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**wa,
		altsyncram_component.numwords_b = 2**wa,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.ram_block_type = "M10K",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.widthad_a = wa,
		altsyncram_component.widthad_b = wa,
		altsyncram_component.width_a = 64,
		altsyncram_component.width_b = 64,
		altsyncram_component.width_byteena_a = 1;

endmodule

module ddr_ram #(parameter wa = 10) (
	clock,
	wraddress,
	data,
	wren,
	rdaddress,
	q);

	input	  clock;
	input	[wa-1:0]  wraddress;
	input	[15:0] data;
	input	[ 1:0] wren;
	input	[wa-1:0]  rdaddress;
	output	[15:0]  q;

	wire [15:0] sub_wire0;
	wire [15:0] q = sub_wire0;

	altsyncram	altsyncram_component (
				.address_a (wraddress),
				.byteena_a (wren),
				.clock0 (clock),
				.data_a (data),
				.wren_a (|wren),
				.address_b (rdaddress),
				.q_b (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({16{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**wa,
		altsyncram_component.numwords_b = 2**wa,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.ram_block_type = "M10K",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.widthad_a = wa,
		altsyncram_component.widthad_b = wa,
		altsyncram_component.width_a = 16,
		altsyncram_component.width_b = 16,
		altsyncram_component.width_byteena_a = 2;

endmodule

module ddr_infifo 
#(parameter l = 3)
(
	input	         CLK,
	input          RST,
	
	input	 [34: 0] DATA,
	input	         WRREQ,
	
	input	         RDREQ,
	output [34: 0] Q,
	output	      EMPTY,
	output	      FULL
);

	wire [ 34: 0] sub_wire0;
	bit  [l-1: 0] RADDR;
	bit  [l-1: 0] WADDR;
	bit  [  l: 0] AMOUNT;
	
	always @(posedge CLK) begin
		if (RST) begin
			AMOUNT <= '0;
			RADDR <= '0;
			WADDR <= '0;
		end
		else begin
			if (WRREQ && !AMOUNT[l]) begin
				WADDR <= WADDR + 1'd1;
			end
			if (RDREQ && AMOUNT) begin
				RADDR <= RADDR + 1'd1;
			end
			
			if (WRREQ && !RDREQ && !AMOUNT[l]) begin
				AMOUNT <= AMOUNT + 1'd1;
			end else if (!WRREQ && RDREQ && AMOUNT) begin
				AMOUNT <= AMOUNT - 1'd1;
			end
		end
	end
	assign EMPTY = ~|AMOUNT;
	assign FULL = AMOUNT[l];
	
	altdpram	altdpram_component (
				.data (DATA),
				.inclock (CLK),
				.rdaddress (RADDR),
				.wraddress (WADDR),
				.wren (WRREQ),
				.q (sub_wire0),
				.aclr (1'b0),
				.byteena (1'b1),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
//				.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram_component.indata_aclr = "OFF",
		altdpram_component.indata_reg = "INCLOCK",
		altdpram_component.intended_device_family = "Cyclone V",
		altdpram_component.lpm_type = "altdpram",
		altdpram_component.outdata_aclr = "OFF",
		altdpram_component.outdata_reg = "UNREGISTERED",
		altdpram_component.ram_block_type = "MLAB",
		altdpram_component.rdaddress_aclr = "OFF",
		altdpram_component.rdaddress_reg = "UNREGISTERED",
		altdpram_component.rdcontrol_aclr = "OFF",
		altdpram_component.rdcontrol_reg = "UNREGISTERED",
		altdpram_component.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component.width = 35,
		altdpram_component.widthad = l,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";
		
	assign Q = sub_wire0;

endmodule
