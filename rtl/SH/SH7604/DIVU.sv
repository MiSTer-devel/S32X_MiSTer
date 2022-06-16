module SH7604_DIVU (
	input             CLK,
	input             RST_N,
	input             CE_R,
	input             CE_F,
	input             EN,
	
	input             RES_N,
	
	input      [31:0] IBUS_A,
	input      [31:0] IBUS_DI,
	output     [31:0] IBUS_DO,
	input       [3:0] IBUS_BA,
	input             IBUS_WE,
	input             IBUS_REQ,
	output reg        IBUS_BUSY,
	output            IBUS_ACT,
	
	output            IRQ,
	output      [7:0] VEC
);

	import SH7604_PKG::*;
	
	DVSR_t      DVSR;
	DVDNT_t     DVDNTL;
	DVDNT_t     DVDNTH;
	DVCR_t      DVCR;
	VCRDIV_t    VCRDIV;
	bit         BUSY;
	
	wire REG_SEL = (IBUS_A >= 32'hFFFFFF00 && IBUS_A <= 32'hFFFFFF1F);
	wire DIV32_START = REG_SEL && IBUS_A[4:0] == 5'h04 && IBUS_WE && IBUS_REQ;
	wire DIV64_START = REG_SEL && IBUS_A[4:0] == 5'h14 && IBUS_WE && IBUS_REQ;
	
	
	bit    [5:0] STEP;
	bit   [64:0] R;
	bit   [31:0] Q;
	bit          OVF;
	always @(posedge CLK or negedge RST_N) begin
		bit   [64:0] D;
		bit   [64:0] SUM;
		bit   [31:0] TEMP;
//		bit          DIV64;
		
		if (!RST_N) begin
			STEP <= 6'h3F;
			R <= '0;
			D <= '0;
			Q <= '0;
			OVF <= 0;
		end
		else if (EN && CE_R) begin
			if (STEP != 6'h3F) begin
				STEP <= STEP + 6'd1;
			end
			if (STEP == 6'h3F && (DIV32_START || DIV64_START)) begin
				STEP <= 6'd0;
//				DIV64 <= DIV64_START;
				OVF <= 0;
			end
			
			SUM = $signed(R) - $signed(D);
			if (STEP == 6'd0) begin
				Q <= '0;
				R <= DVDNTH[31] ? ~{DVDNTH[31],DVDNTH,DVDNTL} + 1 : {DVDNTH[31],DVDNTH,DVDNTL};
				D <= {DVSR[31] ? ~{DVSR[31],DVSR} + 1 : {DVSR[31],DVSR}, 32'h00000000};
				
				if (!DVSR /*|| (DIV64 && DVDNTH >= DVSR)*/) begin
					OVF <= 1;
				end
			end
			else if (STEP >= 6'd4 && STEP <= 6'd36) begin
				R <= !SUM[64] ? SUM : R;
				Q <= {Q[30:0],~SUM[64]};
				D <= {D[64],D[64:1]};
				
				if (STEP == 6'd5 && OVF) STEP <= 6'd38;
			end
			else if (STEP == 6'd37) begin
				Q <= DVDNTH[31]^DVSR[31] ? (~Q + 1) : Q;
				R <= DVDNTH[31] ? (~R + 1) : R;
			end
			if (STEP == 6'd38) begin
				STEP <= 6'h3F;
			end
		end
	end
	
	wire OPERATE = (STEP != 6'h3F);
	
	
	//Registers
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			DVSR <= DVSR_INIT;
			DVDNTL <= DVDNT_INIT;
			DVDNTH <= DVDNT_INIT;
			DVCR <= DVCR_INIT;
			VCRDIV <= VCRDIV_INIT;
			// synopsys translate_off
			
			// synopsys translate_on
		end
		else if (CE_R) begin
			if (!RES_N) begin
				DVSR <= DVSR_INIT;
				DVDNTL <= DVDNT_INIT;
				DVDNTH <= DVDNT_INIT;
				DVCR <= DVCR_INIT;
				VCRDIV <= VCRDIV_INIT;
			end
			else if (REG_SEL && IBUS_WE && IBUS_REQ && !OPERATE) begin
				case ({IBUS_A[4:2],2'b00})
					5'h00: DVSR <= IBUS_DI & DVSR_WMASK;
					5'h04: {DVDNTH,DVDNTL} <= {{32{IBUS_DI[31]}},IBUS_DI} & {DVDNT_WMASK,DVDNT_WMASK};
					5'h08: begin
						if (IBUS_BA[3:2]) DVCR[31:16] <= IBUS_DI[31:16] & DVCR_WMASK[31:16];
						if (IBUS_BA[1:0]) DVCR[15:0]  <= IBUS_DI[15:0]  & DVCR_WMASK[15:0];
					end
					5'h0C: begin
						if (IBUS_BA[1:0]) VCRDIV[15:0] <= IBUS_DI[15:0] & VCRDIV_WMASK[15:0];
					end
					5'h10: DVDNTH <= IBUS_DI & DVDNT_WMASK;
					5'h14: DVDNTL <= IBUS_DI & DVDNT_WMASK;
					default:;
				endcase
			end
			
			if (STEP == 6'd38) begin
				DVCR.OVF = OVF;
				DVDNTL <= !OVF || DVCR.OVFIE ? Q : {DVDNTH[31]^DVSR[31],{31{~(DVDNTH[31]^DVSR[31])}}};
				DVDNTH <= R[31:0];
			end
		end
	end
	
	assign IRQ = DVCR.OVF & DVCR.OVFIE;
	assign VEC = VCRDIV[7:0];
	
	
	bit [31:0] REG_DO;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			REG_DO <= '0;
		end
		else if (CE_F) begin
			if (REG_SEL && !IBUS_WE && IBUS_REQ) begin
				case ({IBUS_A[4:2],2'b00})
					5'h00: REG_DO <= DVSR & DVSR_RMASK;
					5'h04: REG_DO <= DVDNTL & DVDNT_RMASK;
					5'h08: REG_DO <= DVCR & DVCR_RMASK;
					5'h0C: REG_DO <= {16'h0000,VCRDIV} & VCRDIV_RMASK;
					5'h10: REG_DO <= DVDNTH & DVDNT_RMASK;
					5'h14: REG_DO <= DVDNTL & DVDNT_RMASK;
					5'h18: REG_DO <= DVDNTH & DVDNT_RMASK;
					5'h1C: REG_DO <= DVDNTL & DVDNT_RMASK;
					default:REG_DO <= '0;
				endcase
			end
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			BUSY <= 0;
		end
		else if (EN && CE_R) begin
			if (REG_SEL && IBUS_REQ && STEP < 6'd38 && !BUSY) begin
				BUSY <= 1;
			end else if (STEP == 6'd38 && BUSY) begin
				BUSY <= 0;
			end
		end
	end
	
	assign IBUS_DO = REG_SEL ? REG_DO : '0;
	assign IBUS_BUSY = BUSY;
	assign IBUS_ACT = REG_SEL;

endmodule
