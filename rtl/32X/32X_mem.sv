// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module VDPFIFO (
	CLK,
	DATA,
	WRREQ,
	RDREQ,
	Q,
	EMPTY,
	FULL);

	input	  CLK;
	input	[34:0]  DATA;
	input	  RDREQ;
	input	  WRREQ;
	output	  EMPTY;
	output	  FULL;
	output	[34:0]  Q;

	wire  sub_wire0;
	wire  sub_wire1;
	wire [34:0] sub_wire2;
	wire  EMPTY = sub_wire0;
	wire  FULL = sub_wire1;
	wire [34:0] Q = sub_wire2[34:0];

	scfifo	scfifo_component (
				.clock (CLK),
				.data (DATA),
				.rdreq (RDREQ),
				.wrreq (WRREQ),
				.empty (sub_wire0),
				.full (sub_wire1),
				.q (sub_wire2),
				.aclr (),
				.almost_empty (),
				.almost_full (),
				.sclr (),
				.usedw ());
	defparam
		scfifo_component.add_ram_output_register = "OFF",
		scfifo_component.intended_device_family = "Cyclone III",
		scfifo_component.lpm_numwords = 4,
		scfifo_component.lpm_showahead = "ON",
		scfifo_component.lpm_type = "scfifo",
		scfifo_component.lpm_width = 35,
		scfifo_component.lpm_widthu = 2,
		scfifo_component.overflow_checking = "ON",
		scfifo_component.underflow_checking = "ON",
		scfifo_component.use_eab = "ON";

//	scfifo	scfifo_component (
//				.clock (CLK),
//				.data (DATA),
//				.rdreq (RDREQ),
//				.wrreq (WRREQ),
//				.empty (sub_wire0),
//				.full (sub_wire1),
//				.q (sub_wire2),
//				.aclr (),
//				.almost_empty (),
//				.almost_full (),
//				.sclr (),
//				.usedw ());
//	defparam
//		scfifo_component.add_ram_output_register = "OFF",
//		scfifo_component.intended_device_family = "Cyclone V",
//		scfifo_component.lpm_hint = "RAM_BLOCK_TYPE=MLAB",
//		scfifo_component.lpm_numwords = 4,
//		scfifo_component.lpm_showahead = "ON",
//		scfifo_component.lpm_type = "scfifo",
//		scfifo_component.lpm_width = 35,
//		scfifo_component.lpm_widthu = 2,
//		scfifo_component.overflow_checking = "ON",
//		scfifo_component.underflow_checking = "ON",
//		scfifo_component.use_eab = "ON";
		
endmodule


module VDPPAL (
	CLK,
	ADDR_A,
	DATA_A,
	WREN_A,
	Q_A,
	ADDR_B,
	DATA_B,
	WREN_B,
	Q_B);

	input	[7:0]  ADDR_A;
	input	[7:0]  ADDR_B;
	input	  CLK;
	input	[15:0]  DATA_A;
	input	[15:0]  DATA_B;
	input	  WREN_A;
	input	  WREN_B;
	output	[15:0]  Q_A;
	output	[15:0]  Q_B;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri1	  CLK;
	tri0	  WREN_A;
	tri0	  WREN_B;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire [15:0] sub_wire0;
	wire [15:0] sub_wire1;
	wire [15:0] Q_A = sub_wire0[15:0];
	wire [15:0] Q_B = sub_wire1[15:0];

	altsyncram	altsyncram_component (
				.address_a (ADDR_A),
				.address_b (ADDR_B),
				.clock0 (CLK),
				.data_a (DATA_A),
				.data_b (DATA_B),
				.wren_a (WREN_A),
				.wren_b (WREN_B),
				.q_a (sub_wire0),
				.q_b (sub_wire1),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_a (1'b1),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.eccstatus (),
				.rden_a (1'b1),
				.rden_b (1'b1));
	defparam
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_a = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.indata_reg_b = "CLOCK0",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 256,
		altsyncram_component.numwords_b = 256,
		altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
		altsyncram_component.outdata_aclr_a = "NONE",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_a = "UNREGISTERED",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.widthad_a = 8,
		altsyncram_component.widthad_b = 8,
		altsyncram_component.width_a = 16,
		altsyncram_component.width_b = 16,
		altsyncram_component.width_byteena_a = 1,
		altsyncram_component.width_byteena_b = 1,
		altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK0";


endmodule
