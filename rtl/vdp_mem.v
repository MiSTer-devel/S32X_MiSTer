module vdp_cram (
	input        clock,
	input  [5:0] address_a,
	output [8:0] q_a,
	input  [5:0] address_b,
	input        wren_b,
	input  [8:0] data_b,
	output [8:0] q_b
);

	dpram #(6,9) CRAM
	(
		.clock(clock),
		.data_b(data_b),
		.address_a(address_a),
		.address_b(address_b),
		.wren_b(wren_b),
		.q_a(q_a),
		.q_b(q_b)
	);

endmodule

module vdp_vsram (
	input         clock,
	input   [4:0] address_a,
	output [21:0] q_a,
	input   [5:0] address_b,
	input         wren_b,
	input  [10:0] data_b,
	output [21:0] q_b
);

	dpram_dif #(5,22,6,11) VSRAM
	(
		.clock(clock),
		.data_b(data_b),
		.address_a(address_a),
		.address_b(address_b),
		.wren_b(wren_b),
		.q_a(q_a),
		.q_b(q_b)
	);

endmodule

module vdp_obj_visinfo (
	input         clock,
	input   [5:0] address_a,
	output  [6:0] q_a,
	input   [5:0] address_b,
	input         wren_b,
	input   [6:0] data_b
);

	dpram #(6,7) obj_visinfo
	(
		.clock(clock),
		.address_a(address_a),
		.q_a(q_a),
		.address_b(address_b),
		.data_b(data_b),
		.wren_b(wren_b)
	);

endmodule

module vdp_obj_spinfo (
	input         clock,
	input   [5:0] address_a,
	output [34:0] q_a,
	input   [5:0] address_b,
	input         wren_b,
	input  [34:0] data_b
);

	dpram #(6,35) obj_spinfo
	(
		.clock(clock),
		.address_a(address_a),
		.q_a(q_a),
		.address_b(address_b),
		.data_b(data_b),
		.wren_b(wren_b)
	);

endmodule

module vdp_obj_line (
	input         clock,
	input   [8:0] rdaddress,
	output reg [7:0] q,
	input   [8:0] wraddress,
	input         wren,
	input   [7:0] data
);

	mlab #(9,8) obj_line
	(
		.clock(clock),
		.rdaddress(rdaddress),
		.wraddress(wraddress),
		.data(data),
		.wren(wren),
		.q(q)
	);

endmodule
