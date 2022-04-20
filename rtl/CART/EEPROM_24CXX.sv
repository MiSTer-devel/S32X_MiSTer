module EPPROM_24CXX
(
	input clk,                   // Bus clock
	input rst, 
	input en,                // Enable Module
	
	input  [1:0]  mode,
	input  [12:0] mask,
	
	// Chip pins
	output        sda_o,            // Serial Out
	input         sda_i,            // Serial In
	input         scl,           // Serial Clock

	// BRAM Interface
	output [12:0] ram_addr,
	input  [7:0]  ram_q,
	output [7:0]  ram_d,
	output        ram_wr,
	output        ram_rd,
	
	output [6:0]  dbg_last_state
);

	typedef enum bit [6:0] {
		IDLE     = 7'b0000001,
		ADR_7BIT = 7'b0000010, 
		ADR_8BIT = 7'b0000100,
		ADR_DEV  = 7'b0001000,
		START_CHK= 7'b0010000,
		WRITE    = 7'b0100000,
		READ     = 7'b1000000
	} state_t;
	state_t state;
	
	reg [3:0] sda_old = '1;
	reg [3:0] scl_old = '1;
	always @(posedge clk) begin
		if (rst) begin
			sda_old <= '1;
			scl_old <= '1;
		end else if (en) begin
			sda_old <= {sda_old[2:0],sda_i};
			scl_old <= {scl_old[2:0],scl};
		end
	end
	wire sda_rise = (sda_old == 4'b0011);
	wire sda_fall = (sda_old == 4'b1100);
	wire sda_low  = (sda_old == 4'b0000);
	wire sda_high = (sda_old == 4'b1111);
	
	wire scl_rise = (scl_old == 4'b0011);
	wire scl_fall = (scl_old == 4'b1100);
	wire scl_low  = (scl_old == 4'b0000);
	wire scl_high = (scl_old == 4'b1111);
	
	reg       start = 0, stop = 0, cont = 0;
	reg       run = 0;
	reg [3:0] bit_cnt = 0;
	reg [7:0] din;
	reg [7:0] dout;
	reg       sack = 0;
	reg       mack = 0;
	always @(posedge clk) begin
		reg prestart;
		
		if (rst) begin
			prestart <= 0;
			stop <= 0;
			start <= 0;
			cont <= 0;
			run <= 0;
			bit_cnt <= 4'hF;
			sack <= 0;
			mack <= 0;
		end else begin
			start <= 0;
			stop <= 0;
			cont <= 0;
			if (en) begin
				if (sda_fall && scl_high && !run && !prestart) begin
					prestart <= 1;
				end else if (scl_fall && !run && prestart) begin
					prestart <= 0;
					start <= 1;
					run <= 1;
					bit_cnt <= 4'h7;
				end
				
				if (sda_rise && scl_high && run) begin
					stop <= 1;
					run <= 0;
					sack <= 0;
					mack <= 0;
				end
				
				if ((scl_rise || scl_fall) && run) cont <= 1;
				
				if (scl_rise && run) begin
					if (!bit_cnt[3]) begin
						din[bit_cnt[2:0]] <= sda_i;
					end else begin
						mack <= sda_i;
					end
				end else if (scl_fall && run) begin
					bit_cnt <= bit_cnt - 4'h1;
					if (!bit_cnt[3]) begin
						sack <= ~|bit_cnt[2:0];
					end else begin
						sack <= 0;
						bit_cnt <= 4'h7;
					end
				end
			end
		end
	end
	
	assign sda_o = state == ADR_7BIT || state == WRITE ? ~sack : 
	               state == READ                       ? (dout[bit_cnt[2:0]] | bit_cnt[3]) :
						1'b1;
	
	reg [12:0] addr;
	reg        rw;
	reg        write;
	reg        read;
	always @(posedge clk) begin
		reg ack_old;
		reg read_delay;
		reg pre_read_delay;
		
		if (rst) begin
			state <= IDLE;
			addr <= '0;
			rw <= 0;
			write <= 0;
			read <= 0;
		end else begin
			read_delay <= read;
			if (write) addr <= addr + 13'd1;
			if (read_delay) dout <= ram_q;
			
			write <= 0;
			read <= 0;
			case (state)
				IDLE: begin
					if (start) begin
						state <= mode == 2'd0 ? ADR_7BIT : ADR_DEV;
						dbg_last_state = IDLE;
					end
				end
				
				ADR_DEV: begin
					ack_old <= sack;
					if (!sack && ack_old) begin
						addr[10:8] <= din[2:0];
						rw <= din[0];
						if (din[0]) begin
							state <= READ;
						end else begin
							state <= ADR_8BIT;
						end
					end
					dbg_last_state = ADR_DEV;
				end
				
				ADR_7BIT: begin
					ack_old <= sack;
					if (!sack && ack_old) begin
						addr[6:0] <= din[7:1];
						rw <= din[0];
						if (din[0]) begin
							read <= 1;
							state <= READ;
						end else begin
							state <= WRITE;
						end
					end
					dbg_last_state = ADR_7BIT;
				end
				
				ADR_8BIT: begin
					ack_old <= sack;
					if (!sack && ack_old) begin
						addr[7:0] <= din[7:0];
						state <= START_CHK;
					end
					dbg_last_state = ADR_8BIT;
				end
				
				START_CHK: begin
					if (start) state <= ADR_DEV;
					if (cont) state <= WRITE;
				end
				
				READ: begin
					ack_old <= sack;
					if (!sack && ack_old) begin
						addr <= addr + 13'd1;
						read <= 1;
//						if (!mack) begin
//							state <= READ;
//						end
					end
					dbg_last_state = READ;
				end
				
				WRITE: begin
					ack_old <= sack;
					if (!sack && ack_old) begin
						write <= 1;
//						state <= WRITE;
					end
					dbg_last_state = WRITE;
				end
			endcase
			
			if (stop) begin
				state <= IDLE;
			end
		end
	end
	
	assign ram_addr = addr & mask;
	assign ram_d = din;
	assign ram_wr = write;
	assign ram_rd = read;
	

endmodule
