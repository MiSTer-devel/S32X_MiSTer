module S32X_VDP 
#(parameter bit USE_ASYNC_FB=1)
(
	input             CLK,
	input             RST_N,
	input             CE_R,
	input             CE_F,
	
	input             MRES_N,
	
	input             VSYNC_N,
	input             HSYNC_N,
	input             EDCLK,
	input             YS_N,
	input             PAL,
	
	input      [17:1] A,
	input      [15:0] DI,
	output     [15:0] DO,
	input             RD_N,
	input             LWR_N,
	input             UWR_N,
	output            ACK_N,
	input             DRAM_CS_N,
	input             REG_CS_N,
	input             PAL_CS_N,
	
	output            VINT,
	output            HINT,
	
	output     [15:0] FB0_A,
	input      [15:0] FB0_DI,
	output     [15:0] FB0_DO,
	output      [1:0] FB0_WE,
	output            FB0_RD,
	
	output     [15:0] FB1_A,
	input      [15:0] FB1_DI,
	output     [15:0] FB1_DO,
	output      [1:0] FB1_WE,
	output            FB1_RD,
	
	output      [4:0] R,
	output      [4:0] G,
	output      [4:0] B,
	output            HS_N,
	output            VS_N,
	output            YSO_N,	//0 - 32X pixel, 1 - MD pixel
	
	output      [7:0] DBG_DOT_TIME
);
	import S32X_PKG::*;
	
	BMMR_t     BMMR;
	PPCR_t     PPCR;
	AFLR_t     AFLR;
	AFAR_t     AFAR;
	AFDR_t     AFDR;
	FBCR_t     FBCR;
	
	bit        DOT_CE;
	bit  [1:0] MODE;
	bit        PRI;
	bit        M240;
	bit        SFT;
	bit        FS;
	bit        PEN;
	bit        FEN;
	
	bit  [8:0] H_CNT;
	bit  [8:0] V_CNT;
	bit        VBLK;
	bit        HBLK;
	bit        HDISP[3];
	bit        RFRH;

	bit [34:0] FIFO_D;
	bit [34:0] FIFO_Q;
	bit        FIFO_WR;
	bit        FIFO_RD;
	bit        FIFO_EMPTY;
	bit        FIFO_FULL;
	bit [17:1] FIFO_FB_A;
	bit [15:0] FIFO_FB_D;
	bit  [1:0] FIFO_FB_WE;
	bit        FIFO_FB_WRITE;
	
	bit        FB_WR;
	bit        FB_RD;

	bit [15:0] FB_DRAW_A;
	bit [15:0] FB_DRAW_D;
	bit  [1:0] FB_DRAW_WE;
	bit        FB_DRAW_RD;
	bit [15:0] FB_DRAW_Q;
	
	bit [15:0] FB_DISP_A;
	bit        FB_DISP_RD;
	bit [15:0] FB_DISP_Q;

	bit        PAL_ACCESS;
	bit        FILL_EXEC;
	bit  [1:0] FILL_WAIT;
	always @(posedge CLK or negedge RST_N) begin
		bit  [7:0] FILL_CNT;
		bit        FILL_PEND;
		bit  [2:0] ACCESS_WAIT;
		
		if (!RST_N) begin
			BMMR <= BMMR_INIT;
			PPCR <= PPCR_INIT;
			AFLR <= AFLR_INIT;
			AFAR <= AFAR_INIT;
			AFDR <= AFDR_INIT;
			FBCR <= FBCR_INIT;
			
			ACK_N <= 1;
			FILL_PEND <= 0;
			FILL_EXEC <= 0;
			FILL_CNT <= '0;
			PAL_ACCESS <= 0;
			ACCESS_WAIT <= 3'd7;
			FILL_WAIT <= '0;
		end
		else begin
			FIFO_WR <= 0;
			if (!REG_CS_N && (!LWR_N || !UWR_N || !RD_N) && ACK_N) begin
				if (!LWR_N || !UWR_N) begin
					case ({A[3:1],1'b0})
						4'h0: begin
							if (!LWR_N) BMMR[ 7:0] <= DI[ 7:0] & BMMR_MASK[ 7:0];
							if (!UWR_N) BMMR[15:8] <= DI[15:8] & BMMR_MASK[15:8];
						end
						4'h2: begin
							if (!LWR_N) PPCR[ 7:0] <= DI[ 7:0] & PPCR_MASK[ 7:0];
							if (!UWR_N) PPCR[15:8] <= DI[15:8] & PPCR_MASK[15:8];
						end
						4'h4: begin
							if (!LWR_N) AFLR[ 7:0] <= DI[ 7:0] & AFLR_MASK;
						end
						4'h6: begin
							if (!LWR_N) AFAR[ 7:0] <= DI[ 7:0] & AFAR_MASK[ 7:0];
							if (!UWR_N) AFAR[15:8] <= DI[15:8] & AFAR_MASK[15:8];
						end
						4'h8: begin
							if (!LWR_N) AFDR[ 7:0] <= DI[ 7:0] & AFDR_MASK[ 7:0];
							if (!UWR_N) AFDR[15:8] <= DI[15:8] & AFDR_MASK[15:8];
							FILL_PEND <= 1;
							FILL_CNT <= AFLR;
						end
						4'hA: begin
							if (!LWR_N) FBCR[ 7:0] <= DI[ 7:0] & FBCR_MASK[ 7:0];
							if (!UWR_N) FBCR[15:8] <= DI[15:8] & FBCR_MASK[15:8];
						end
					endcase
				end else if (!RD_N) begin
					case ({A[3:1],1'b0})
						4'h0: DO <= {~PAL,7'h00,BMMR.PRI,BMMR.M240,4'h0,BMMR.M} & BMMR_MASK;
						4'h2: DO <= PPCR & PPCR_MASK;
						4'h4: DO <= {8'h00,AFLR & AFLR_MASK};
						4'h6: DO <= AFAR & AFAR_MASK;
						4'h8: DO <= AFDR & AFDR_MASK;
						4'hA: DO <= {VBLK,HBLK,PEN,11'h000,FEN,FS};
						default: DO <= '0;
					endcase
				end
				ACK_N <= 0;
			end else if (!PAL_CS_N && (!LWR_N || !UWR_N || !RD_N) && ACK_N && PEN) begin
				PAL_ACCESS <= ~PAL_ACCESS;
				if (PAL_ACCESS) begin
					DO <= PAL_IO_Q;
					ACK_N <= 0;
				end
			end else if (!DRAM_CS_N && (!LWR_N || !UWR_N || !RD_N) && ACK_N && !FEN) begin
				if (!RD_N && !FIFO_FB_WRITE && FIFO_EMPTY) begin
					FB_RD <= 1;
					ACCESS_WAIT <= ACCESS_WAIT - 3'd1;
					if (!ACCESS_WAIT) begin
						DO <= FB_DRAW_Q;
						FB_RD <= 0;
						ACK_N <= 0;
					end
				end else if ((!LWR_N || !UWR_N) && !FIFO_FULL) begin
					FIFO_D <= {A[17:1],~UWR_N,~LWR_N,DI};
					FIFO_WR <= 1;
					ACK_N <= 0;
				end
			end else if (LWR_N && UWR_N && RD_N && !ACK_N) begin
				ACK_N <= 1;
				ACCESS_WAIT <= 3'd6;
			end
			
			if (FILL_PEND && CE_R) begin
				FILL_PEND <= 0;
				FILL_EXEC <= 1;
			end else if (FILL_EXEC && CE_R) begin
				FILL_WAIT <= FILL_WAIT + 2'd1;
				if (FILL_WAIT == 2'd2) begin
					FILL_WAIT <= '0;
					AFAR[ 7:0] <= AFAR[ 7:0] + 8'd1;
					FILL_CNT <= FILL_CNT - 8'd1;
					if (!FILL_CNT) FILL_EXEC <= 0;
				end
			end
		end
	end
	
	VDPFIFO fifo(
		.CLK(CLK), 
		.DATA(FIFO_D), 
		.WRREQ(FIFO_WR), 		
		.RDREQ(FIFO_RD), 
		.Q(FIFO_Q), 
		
		.EMPTY(FIFO_EMPTY), 
		.FULL(FIFO_FULL)
	);
	
	always @(posedge CLK or negedge RST_N) begin
		bit  [2:0] FIFO_FB_WAIT;
		
		if (!RST_N) begin
			FIFO_FB_A <= '0;
			FIFO_FB_D <= '0;
			FIFO_FB_WE <= '0;
			FB_WR <= 0;
			FIFO_RD <= 0;
			FIFO_FB_WRITE <= 0;
		end
		else begin
			FIFO_RD <= 0;
			if (!FIFO_EMPTY && !FIFO_FB_WRITE) begin
				{FIFO_FB_A,FIFO_FB_WE,FIFO_FB_D} <= FIFO_Q;
				FB_WR <= 1;
				FIFO_RD <= 1;
				FIFO_FB_WAIT <= 3'd5;
				FIFO_FB_WRITE <= 1;
			end else if (FIFO_FB_WRITE) begin
				FIFO_FB_WAIT <= FIFO_FB_WAIT - 3'd1;
				if (!FIFO_FB_WAIT) begin
					FIFO_FB_WRITE <= 0;
					FB_WR <= 0;
				end
			end
		end
	end
	
	
	reg        EDCLK_SYNC;
	reg        HSYNC_N_SYNC;
	reg        VSYNC_N_SYNC;
	reg        YS_N_SYNC;
	always @(negedge CLK) begin
		EDCLK_SYNC <= EDCLK;
		HSYNC_N_SYNC <= HSYNC_N;
		VSYNC_N_SYNC <= VSYNC_N;
		YS_N_SYNC <= YS_N;
	end
	
	bit        DOT_CLK;
	bit        EDCLK_OLD;
	always @(posedge CLK or negedge RST_N) begin
		bit        HSYNC_N_OLD;
		bit        VSYNC_N_OLD;
		bit        VSYNC_OCCUR;
		
		if (!RST_N) begin
			DOT_CLK <= 0;
			H_CNT <= '0;
			V_CNT <= '0;
			HSYNC_N_OLD <= 1;
			VSYNC_N_OLD <= 1;
		end
		else begin
			DBG_DOT_TIME <= DBG_DOT_TIME + 8'd1;
			
			EDCLK_OLD <= EDCLK_SYNC;
			if (!EDCLK_SYNC && EDCLK_OLD) begin
				DOT_CLK <= ~DOT_CLK;
				HSYNC_N_OLD <= HSYNC_N_SYNC;
				if (!HSYNC_N_SYNC && HSYNC_N_OLD && (H_CNT >= 9'h160 || VSYNC_N_SYNC)) begin
					H_CNT <= 9'h1CE;
					DOT_CLK <= 1;
				end else if (H_CNT == 9'h16C && DOT_CLK) begin
					H_CNT <= 9'h1C9;
				end else if (DOT_CLK) begin
					H_CNT <= H_CNT + 9'd1;
				end
				
				VSYNC_N_OLD <= VSYNC_N_SYNC;
				if (!VSYNC_N_SYNC && VSYNC_N_OLD) begin
					VSYNC_OCCUR <= 1;
				end
				
				if (H_CNT == 9'h149 && DOT_CLK) begin
					if (VSYNC_OCCUR) begin
						V_CNT <= !PAL ? 9'd236 : 9'd260;
						VSYNC_OCCUR <= 0;
					end else if ((V_CNT == 9'd261 && !PAL) || (V_CNT == 9'd312 && PAL)) begin
						V_CNT <= 9'd0;
					end else begin
						V_CNT <= V_CNT + 9'd1;
					end
				end
				
				if (DOT_CLK) begin
					DBG_DOT_TIME <= '0;
				end
			end
		end
	end
	
	assign DOT_CE = DOT_CLK & ~EDCLK_SYNC & EDCLK_OLD;

	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			HBLK <= 0;
			VBLK <= 0;
			HDISP <= '{0,0,0};
		end
		else if (DOT_CE) begin
			if (H_CNT == 9'h017-1) begin
				HBLK <= 0;
				HDISP[0] <= ~VBLK;
			end else if (H_CNT == 9'h157-1) begin
				HBLK <= 1;
				HDISP[0] <= 0;
			end
			HDISP[1] <= HDISP[0];
			HDISP[2] <= HDISP[1];
			
			if (H_CNT == 9'h1CE-1) begin
				if ((V_CNT == 9'd224 && (!M240 || !PAL)) || (V_CNT == 9'd240 && M240 && PAL)) begin
					VBLK <= 1;
				end else if (V_CNT == 9'd0) begin
					VBLK <= 0;
				end
			end
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		bit  [5:0] RFRH_CNT;
		
		if (!RST_N) begin
			RFRH <= 0;
			RFRH_CNT <= '0;
		end
		else begin
			if (H_CNT == 9'h158-1 && DOT_CE) begin
				RFRH <= 1;
				RFRH_CNT <= 6'd39;
			end else if (RFRH && CE_R) begin
				RFRH_CNT <= RFRH_CNT - 6'd1;
				if (!RFRH_CNT) RFRH <= 0;
			end
		end
	end
	
	wire REG_LATCH_HTIME = H_CNT >= 9'h157;
	always @(posedge CLK or negedge RST_N) begin		
		if (!RST_N) begin
			MODE <= '0;
			PRI <= 0;
			M240 <= 0;
			SFT <= 0;
			FS <= 0;
			PEN <= 0;
		end
		else begin
			if (DOT_CE) begin
				if (REG_LATCH_HTIME) begin
					MODE <= BMMR.M;
					PRI <= BMMR.PRI;
					M240 <= BMMR.M240;
					SFT <= PPCR.SFT;
				end
				
				if (VBLK || MODE == 2'b0) FS <= FBCR.FS;
				
				if (H_CNT == 9'h157+3-1 || VBLK || !MODE[0]) begin
					PEN <= 1;
				end else if (H_CNT == 9'h017-1) begin
					PEN <= 0;
				end
			end
		end
	end
	
	assign FEN = FILL_EXEC | RFRH;
	
	
	bit [16:0] LINE_LEAD;
	bit [15:0] PIX_DATA;
	bit        PIX_BYTE;
	always @(posedge CLK or negedge RST_N) begin		
		if (!RST_N) begin
			LINE_LEAD <= '0;
			PIX_DATA <= '0;
			PIX_BYTE <= 0;
		end
		else begin
			if (DOT_CE) begin
				if (H_CNT == 9'h017-1) begin
					LINE_LEAD <= {FB_DISP_Q, SFT | &MODE};
					PIX_DATA <= '0;
				end
				else if (HDISP[0])  begin
					case (MODE)
						2'b00:;
						2'b01: begin
							LINE_LEAD <= LINE_LEAD + 17'd1;
							PIX_DATA <= FB_DISP_Q;
						end
						2'b10:  begin
							PIX_DATA <= FB_DISP_Q;
							LINE_LEAD <= LINE_LEAD + 17'd2;
						end
						2'b11: begin
							PIX_DATA[15:8] <= PIX_DATA[15:8] - 8'd1;
							if (PIX_DATA[15:8] == 8'd0) begin
								PIX_DATA <= FB_DISP_Q;
								LINE_LEAD <= LINE_LEAD + 17'd2;
							end
						end
					endcase
					PIX_BYTE <= LINE_LEAD[0];
				end
			end
		end
	end
	
	always_comb begin
		if (H_CNT == 9'h017-1) 
			FB_DISP_A = {8'h00,V_CNT[7:0]};
		else
			FB_DISP_A = LINE_LEAD[16:1];
	end
		
	wire  [7:0] PAL_DISP_A = PIX_BYTE ? PIX_DATA[7:0] : PIX_DATA[15:8];
	bit  [15:0] PAL_DISP_Q;
	
	wire  [7:0] PAL_IO_A = A[8:1];
	wire [15:0] PAL_IO_D = DI;
	wire        PAL_IO_WE = ~LWR_N & ~UWR_N & PAL_ACCESS;
	bit  [15:0] PAL_IO_Q;
	
	VDPPAL pal(
		.CLK(CLK), 
		.ADDR_A(PAL_DISP_A), 
		.DATA_A('0), 
		.WREN_A(0), 
		.Q_A(PAL_DISP_Q),
		
		.ADDR_B(PAL_IO_A), 
		.DATA_B(PAL_IO_D), 
		.WREN_B(PAL_IO_WE), 
		.Q_B(PAL_IO_Q)
	);
	
	bit [15:0] PIX_COLOR;
	always @(posedge CLK or negedge RST_N) begin		
		if (!RST_N) begin
			PIX_COLOR <= '0;
		end
		else begin
			if (DOT_CE) begin
				if (HDISP[1])  begin
					case (MODE)
						2'b00: PIX_COLOR <= '0;
						2'b01: PIX_COLOR <= PAL_DISP_Q;
						2'b10: PIX_COLOR <= PIX_DATA;
						2'b11: PIX_COLOR <= PAL_DISP_Q;
					endcase
				end
			end
		end
	end
	
	assign R = PIX_COLOR[ 4: 0] & {5{HDISP[2]&~VBLK}};
	assign G = PIX_COLOR[ 9: 5] & {5{HDISP[2]&~VBLK}};
	assign B = PIX_COLOR[14:10] & {5{HDISP[2]&~VBLK}};
	assign HS_N = HSYNC_N_SYNC & VSYNC_N_SYNC;
	assign VS_N = VSYNC_N_SYNC;
	assign YSO_N = !MODE ? 1'b1 : ~(PRI ^ PIX_COLOR[15]) & YS_N_SYNC;
	
	always @(posedge CLK) FB_DISP_RD <= DOT_CE | USE_ASYNC_FB;
	
	assign FB_DRAW_A  = FILL_EXEC ? AFAR : FB_WR ? FIFO_FB_A[16:1] : A[16:1];
	assign FB_DRAW_D  = FILL_EXEC ? AFDR : FB_WR ? FIFO_FB_D       : DI;
	assign FB_DRAW_WE = FILL_EXEC ? {2{FILL_EXEC & (~|FILL_WAIT | USE_ASYNC_FB)}} : {FB_WR & FIFO_FB_WE[1] & ((|FIFO_FB_D[15:8] & FIFO_FB_A[17]) | ((|FIFO_FB_D[15:8] | FIFO_FB_WE[0]) & ~FIFO_FB_A[17])), 
	                                                                                 FB_WR & FIFO_FB_WE[0] & ((|FIFO_FB_D[ 7:0] & FIFO_FB_A[17]) | ((|FIFO_FB_D[ 7:0] | FIFO_FB_WE[1]) & ~FIFO_FB_A[17]))};
	assign FB_DRAW_RD = FILL_EXEC ? 1'b0 : FB_RD;
	
	assign FB_DRAW_Q = FS ? FB0_DI : FB1_DI;
	assign FB_DISP_Q = FS ? FB1_DI : FB0_DI;
	
	assign FB0_A  = FS ? FB_DRAW_A : FB_DISP_A;
	assign FB0_DO = FB_DRAW_D;
	assign FB0_WE = FS ? FB_DRAW_WE : 2'b00;
	assign FB0_RD = FS ? FB_DRAW_RD : FB_DISP_RD;
	
	assign FB1_A  = FS ? FB_DISP_A : FB_DRAW_A;
	assign FB1_DO = FB_DRAW_D;
	assign FB1_WE = FS ? 2'b00      : FB_DRAW_WE;
	assign FB1_RD = FS ? FB_DISP_RD : FB_DRAW_RD;
	
	assign HINT = HBLK;
	assign VINT = VBLK;
	
endmodule
