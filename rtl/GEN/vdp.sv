module VDP 
(
	input             CLK,
	input             RST_N,
	input             ENABLE,
	
	input             VCLK_ENp,
	input             VCLK_ENn,
	input             SEL,
	input       [4:1] A,
	input             RNW,
	input             AS_N,
	input      [15:0] DI,
	output reg [15:0] DO,
	output            DTACK_N,
	output            BR_N,
	input             BG_N,
	output            BGACK_N,
	output reg  [2:1] IPL_N,

	output            VINT,
	output            HINT,
	input             INTACK_N,
	output            Z80_INT_N,
	output            REFRESH,
		
	output     [23:1] VBUS_A,
	input      [15:0] VBUS_DATA,
	output            VBUS_SEL,
	input             VBUS_DTACK_N,
		
	input             PAL,
	input             HL,
	
	output     [15:0] VRAM_A,
	output      [7:0] VRAM_D,
	input       [7:0] VRAM_Q,
	output            VRAM_WE,

	output  reg       CE_PIX,
	output  reg       FIELD_OUT,
	output            INTERLACE,
	output      [1:0] RESOLUTION,
	output            HBL,
	output            VBL,

	output reg  [3:0] R,
	output reg  [3:0] G,
	output reg  [3:0] B,
	output reg        YS_N,
	output            EDCLK,
	output reg        HS_N,
	output reg        VS_N,
		
	input             BORDER_EN,
	input             VSCROLL_BUG, //'1';
	input             OBJ_MAX,
		
	input             BGA_EN,
	input             BGB_EN,
	input             SPR_EN,
	input       [1:0] BG_GRID_EN,
	input             SPR_GRID_EN,
	
	output            DBG_SLOT0_EXT,
	output            DBG_SLOT1_EXT,
	output            DBG_SLOT2_HSCROLL,
	output            DBG_SLOT2_BGAMAP,
	output            DBG_SLOT2_BGACHAR,
	output            DBG_SLOT2_BGBMAP,
	output            DBG_SLOT2_BGBCHAR,
	output            DBG_SLOT2_SPRMAP,
	output            DBG_SLOT2_SPRCHAR,
	output            DBG_SLOT2_EXT,
	output            DBG_SLOT2_REFRESH,
	output [16:0] DBG_FIFO_ADDR,
	output [15:0] DBG_FIFO_DATA,
	output  [3:0] DBG_FIFO_CODE,
	output        DBG_FIFO_EMPTY,
	output        DBG_FIFO_FULL 
);
	import VDP_PKG::*;
	
	MR1_t      MR1;
	MR2_t      MR2;
	NTA_t      NTA;
	NTW_t      NTW;
	NTB_t      NTB;
	SAT_t      SAT;
	BGC_t      BGC;
	HIR_t      HIR;
	MR3_t      MR3;
	MR4_t      MR4;
	NSDT_t     NSDT;
	AI_t       AI;
	SS_t       SS;
	WHP_t      WHP;
	WVP_t      WVP;
	DLC_t      DLC;
	DSA_t      DSA;
	DBG_t      DBG;
	
	//IO
	bit [16:0] ADDR;
	bit  [5:0] CODE;
	bit        PENDING;
	Fifo_t     FIFO;
	bit [16:0] IO_ADDR;
	bit [15:0] IO_DATA;
	bit        IO_BYTE;
	bit        IO_WE;
	bit        FF_VBUS_SEL;
	bit [15:0] FF_VBUS_DATA;
	bit        FF_DTACK_N;
	bit        FF_BGACK_N;
	bit        FF_BR_N;
	
	typedef enum bit [11:0] {
		DTC_IDLE        = 12'b000000000001,
		DTC_FIFO_PRE_RD = 12'b000000000010,
		DTC_FIFO_RD     = 12'b000000000100,
		DTC_FIFO_PAUSE  = 12'b000000001000,
		DTC_VRAM_WR     = 12'b000000010000,
		DTC_CRAM_WR     = 12'b000000100000,
		DTC_VSRAM_WR    = 12'b000001000000,
		DTC_PRE_RD      = 12'b000010000000,
		DTC_VRAM_RD     = 12'b000100000000,
		DTC_VRAM8_RD    = 12'b001000000000,
		DTC_CRAM_RD     = 12'b010000000000,
		DTC_VSRAM_RD    = 12'b100000000000
	} dtc_t;
	dtc_t DTC;
	bit        DT_RD_PEND;
	bit        DT_RD_EXEC;
	bit  [3:0] DT_RD_CODE;
	bit [15:0] DT_RD_DATA;
	
	typedef enum bit [11:0] {
		DMA_IDLE         = 12'b000000000001,
		DMA_FILL_WR      = 12'b000000000010,
		DMA_FILL_WR2     = 12'b000000000100,
		DMA_COPY_RD      = 12'b000000001000,
		DMA_COPY_WR      = 12'b000000010000,
		DMA_VBUS_WAIT    = 12'b000000100000,
		DMA_VBUS_WAIT2   = 12'b000001000000,
		DMA_VBUS_REFRESH = 12'b000010000000,
		DMA_VBUS_SKIP    = 12'b000100000000,
		DMA_VBUS_RD      = 12'b001000000000,
		DMA_VBUS_WR      = 12'b010000000000,
		DMA_VBUS_END     = 12'b100000000000
	} dmac_t;
	dmac_t DMAC;
	bit        DMA_FILL;
	bit        DMA_FILL_START;
	bit        DMA_FILL_WE;
	bit  [3:0] DMA_FILL_CODE;
	bit        DMA_COPY;
	bit        DMA_COPY_WE;
	bit        DMA_VBUS;
	
	//H/V timing registers
	bit  [8:0] H_CNT;
	bit  [8:0] V_CNT;
	bit        FIELD;
	bit        IN_VBL;
	bit        IN_HBL;
	bit        FF_VS;
	bit        FF_HS;
	bit [15:0] HV;
	
	//Slot
	Slot_t     SLOT_PIPE[3];
	Slot_t     SLOT;
	
	bit [15:0] BG_VRAM_ADDR;
	bit  [5:1] BG_VSRAM_ADDR;
	bit [10:0] VSCRLA;
	bit [10:0] VSCRLB;
	bit  [8:0] DISP_X;
	bit [15:0] SPR_VRAM_ADDR;
	bit        DISP;
	bit        DISP_EN_PIPE[3];
	
	bit        VINT_FLAG;
	bit        HINT_FLAG;
	bit        Z80_INT_FLAG;
	bit        SOVR_FLAG;
	bit        SCOL_FLAG;
	bit        SOVR_FLAG_CLR;
	bit        SCOL_FLAG_CLR;
	
	
	//IO
	wire [16:0] FIFO_ADDR = FIFO.ITEMS[FIFO.RD_POS].ADDR;
	wire [15:0] FIFO_DATA = FIFO.ITEMS[FIFO.RD_POS].DATA;
	wire  [3:0] FIFO_CODE = FIFO.ITEMS[FIFO.RD_POS].CODE;
	wire        FIFO_EMPTY = FIFO.AMOUNT == 3'd0;
	wire        FIFO_FULL = FIFO.AMOUNT[2];
	
	wire [16:0] FIFO_NEXT_ADDR = FIFO.ITEMS[FIFO.RD_POS + 1].ADDR;
	wire [15:0] FIFO_NEXT_DATA = FIFO.ITEMS[FIFO.RD_POS + 1].DATA;
	wire        FIFO_PRE_EMPTY = FIFO.AMOUNT == 3'd1;
	
	
	always @(posedge CLK or negedge RST_N) begin
		bit        FIFO_AMOUNT_INC;
		bit        FIFO_AMOUNT_DEC;
		bit [15:0] NEXT_DMA_SRC;
		bit [15:0] NEXT_DMA_LEN;
		bit  [1:0] DMA_VBUS_WC;
		
		if (!RST_N) begin
			MR1 <= '0;
			MR2 <= '0;
			NTA <= '0;
			NTW <= '0;
			NTB <= '0;
			SAT <= '0;
			BGC <= '0;
			HIR <= '0;
			MR3 <= '0;
			MR4 <= '0;
			NSDT <= '0;
			AI <= '0;
			SS <= '0;
			WHP <= '0;
			WVP <= '0;
			DLC <= '0;
			DSA <= '0;
			DBG <= '0;
			
			ADDR <= '0;
			CODE <= '0;
			PENDING <= 0;
			FIFO <= FIFO_NULL;
			
			DTC <= DTC_IDLE;
			DT_RD_PEND <= 0;
			DT_RD_EXEC <= 0;
			DT_RD_CODE <= '0;
			DT_RD_DATA <= '0;
			DMAC <= DMA_IDLE;
			DMA_FILL <= 0;
			DMA_FILL_CODE <= '0;
			DMA_FILL_START <= 0;
			DMA_FILL_WE <= 0;
			DMA_COPY <= 0;
			DMA_COPY_WE <= 0;
			DMA_VBUS <= 0;
			
			FF_VBUS_SEL <= 0;
			FF_DTACK_N <= 1;
			FF_BGACK_N <= 1;
			FF_BR_N <= 1;
			
			SOVR_FLAG_CLR <= 0;
			SCOL_FLAG_CLR <= 0;
		end else begin
			SOVR_FLAG_CLR <= 0;
			SCOL_FLAG_CLR <= 0;
			
			FIFO_AMOUNT_INC = 0;
			FIFO_AMOUNT_DEC = 0;
			if (!SEL && AS_N) begin
				FF_DTACK_N <= 1;
				if (!BG_N && !FF_BR_N && FF_BGACK_N) begin
					FF_BGACK_N <= 0;
					FF_BR_N <= 1;
				end
			end else if (SEL && FF_DTACK_N) begin
				if (!RNW) begin 										// Write
					if (A[4:2] == 3'b000) begin					// Data Port C00000-C00002
						PENDING <= 0;
	
						if (!FIFO_FULL) begin
							FIFO.ITEMS[FIFO.WR_POS].ADDR <= ADDR;
							FIFO.ITEMS[FIFO.WR_POS].DATA <= DI;
							FIFO.ITEMS[FIFO.WR_POS].CODE <= CODE[3:0];
							FIFO.WR_POS <= FIFO.WR_POS + 2'd1;
							FIFO_AMOUNT_INC = 1;
							ADDR <= ADDR + AI.INC;
							FF_DTACK_N <= 0;
						end
						
						if (DMA_FILL) begin
							DMA_FILL_START <= 1;
							DMA_FILL_CODE <= CODE[3:0];
						end
	
					end else if (A[4:2] == 3'b001) begin				// Control Port C00004-C00006
						if (!FF_BR_N) begin
							
						end else if (PENDING) begin
							if (CODE[4:2] != DI[6:4] || !DMA_FILL) begin
								ADDR[16:14] <= DI[2:0];
							end
							CODE[4:2] <= DI[6:4];
							if (MR2.DMA) begin
								CODE[5] <= DI[7];
							end
							
							if (MR2.DMA && DI[7]) begin
								if (!DSA[23]) begin
//									if (VCLK_ENp) begin
										if (!DMA_VBUS) begin
											DMA_VBUS <= 1;
										end else if (DMA_VBUS && VCLK_ENp) begin
											FF_BR_N <= 0;
											PENDING <= 0;
										end
//									end
								end else begin
									if (!DSA[22]) DMA_FILL <= 1;
									else          DMA_COPY <= 1;
									FF_DTACK_N <= 0;
									PENDING <= 0;
								end
							end else if (CODE[1:0] == 2'b00 && DI[7:6] == 2'b00) begin
								DT_RD_PEND <= 1;
								DT_RD_CODE <= {DI[5:4],2'b00};
								FF_DTACK_N <= 0;
								PENDING <= 0;
							end else begin
								FF_DTACK_N <= 0;
								PENDING <= 0;
							end
						end else begin
							CODE[1:0] <= DI[15:14];
							if (DI[15:14] == 2'b10) begin		// Register Set
								if (MR2.M5 || DI[12:8] <= 10) begin
									// mask registers above 10 in Mode4
									case (DI[12:8]) 
										5'd0: MR1 <= DI[7:0] & MR1_MASK;
										5'd1: MR2 <= DI[7:0] & MR2_MASK;
										5'd2: NTA <= DI[7:0] & NTA_MASK;
										5'd3: NTW <= DI[7:0] & NTW_MASK;
										5'd4: NTB <= DI[7:0] & NTB_MASK;
										5'd5: SAT <= DI[7:0] & SAT_MASK;
										5'd7: BGC <= DI[7:0] & BGC_MASK;
										5'd10: HIR <= DI[7:0] & HIR_MASK;
										5'd11: MR3 <= DI[7:0] & MR3_MASK;
										5'd12: MR4 <= DI[7:0] & MR4_MASK;
										5'd13: NSDT <= DI[7:0] & NSDT_MASK;
										5'd15: AI <= DI[7:0] & AI_MASK;
										5'd16: SS <= DI[7:0] & SS_MASK;
										5'd17: WHP <= DI[7:0] & WHP_MASK;
										5'd18: WVP <= DI[7:0] & WVP_MASK;
										5'd19: if (!DMA_FILL) DLC[7:0] <= DI[7:0];
										5'd20: if (!DMA_FILL) DLC[15:8] <= DI[7:0];
										5'd21: DSA[7:0] <= DI[7:0];
										5'd22: DSA[15:8] <= DI[7:0];
										5'd23: DSA[23:16] <= DI[7:0];
									endcase
								end
							end else begin								// Address Set
								PENDING <= 1;
								ADDR[13:0] <= DI[13:0];
								CODE[5:4] <= 2'b00; // attempt to fix lotus i
							end
							FF_DTACK_N <= 0;
						end
					end else if (A[4:2] == 3'b111) begin
						DBG <= DI;
						FF_DTACK_N <= 0;
					end else if (A[4:3] == 2'b10) begin		// PSG
						FF_DTACK_N <= 0;
					end else	begin									// Unused (Lock-up)
						FF_DTACK_N <= 0;
					end
				end else begin										// Read
					if (A[4:2] == 3'b000) begin				// Data Port C00000-C00002 
						PENDING <= 0;
						
						if (CODE == 6'b001000 || // CRAM Read
							 CODE == 6'b000100 || // VSRAM Read
							 CODE == 6'b000000 || // VRAM Read
							 CODE == 6'b001100)   // VRAM Read 8 bit
						begin
							if (!DT_RD_EXEC && !DT_RD_PEND) begin
								DT_RD_PEND <= 1;
								DT_RD_CODE <= CODE[3:0];
								FF_DTACK_N <= 0;
							end
						end else begin
							FF_DTACK_N <= 0;
						end
					end else if (A[4:2] == 3'b001) begin	// Control Port C00004-C00006 (Read Status Register)
						PENDING <= 0;
						SOVR_FLAG_CLR <= 1;
						SCOL_FLAG_CLR <= 1;
						FF_DTACK_N <= 0;
					end else if (A[4:3] == 2'b01) begin		// HV Counter C00008-C0000A
						FF_DTACK_N <= 0;
					end else if (A[4]) begin					// unused, PSG, DBG
						FF_DTACK_N <= 0;
					end
				end
			end
			
			case (DTC)
				DTC_IDLE: begin	
					if (!FIFO_EMPTY && SLOT_CE) begin
						DTC <= DTC_FIFO_PRE_RD;
					end else if (DT_RD_PEND && SLOT_CE) begin
						DT_RD_PEND <= 0;
						DT_RD_EXEC <= 1;
						DTC <= DTC_PRE_RD;
					end
				end
				
				DTC_FIFO_PRE_RD: begin	
					if (SLOT_CE) begin
						IO_ADDR <= FIFO_ADDR;
						IO_DATA <= FIFO_DATA;
						IO_BYTE <= FIFO_ADDR[0];
						IO_WE <= 1;
						DTC <= DTC_FIFO_RD;
					end
				end
				
				DTC_FIFO_RD: begin	
					if (SLOT == ST_EXT && SLOT_CE) begin	
						case (FIFO_CODE)
							4'b0001: begin // VRAM Write
								if (IO_BYTE != IO_ADDR[0] || MR2.M128K) begin
									FIFO_AMOUNT_DEC = 1;
								end else begin
									IO_ADDR[0] <= ~IO_ADDR[0];
									IO_DATA <= {IO_DATA[7:0],IO_DATA[15:8]};
								end
							end
							4'b0011: begin // CRAM Write
								FIFO_AMOUNT_DEC = 1;
								IO_DATA <= FIFO_NEXT_DATA;
							end
							4'b0101: begin // VSRAM Write
								FIFO_AMOUNT_DEC = 1;
								IO_DATA <= FIFO_NEXT_DATA;
							end
							default: begin //invalid target
								FIFO_AMOUNT_DEC = 1;
							end
						endcase 
						
						if (FIFO_AMOUNT_DEC) begin
							FIFO.RD_POS <= FIFO.RD_POS + 2'd1;
							if (IO_WE && !FIFO_PRE_EMPTY) begin
								IO_ADDR <= FIFO_NEXT_ADDR;
								IO_DATA <= FIFO_NEXT_DATA;
								IO_BYTE <= FIFO_NEXT_ADDR[0];
								IO_WE <= 1;
								DTC <= DTC_FIFO_RD;
							end else begin
								IO_WE <= 0;
								DTC <= DTC_IDLE;
							end
						end
						if (DMA_FILL_START && !FIFO_PRE_EMPTY) begin
							DTC <= DTC_FIFO_PAUSE;
						end
					end
				end
				
				DTC_FIFO_PAUSE: begin	
					if (SLOT_CE) begin
						DTC <= DTC_FIFO_RD;
					end
				end
				
				DTC_PRE_RD: begin	
					if (SLOT_CE) begin
						IO_ADDR <= ADDR;
						IO_BYTE <= ADDR[0];
						DT_RD_DATA <= FIFO_DATA;
						ADDR <= ADDR + AI.INC;
						case (DT_RD_CODE)
							4'b1000: // CRAM Read
								DTC <= DTC_CRAM_RD;
							4'b0100: // VSRAM Read
								DTC <= DTC_VSRAM_RD;
							4'b0000: // VRAM Read
								DTC <= DTC_VRAM_RD;
							default: // VRAM Read 8 bit
								DTC <= DTC_VRAM8_RD;
						endcase
					end
				end
				
				DTC_VRAM_RD: begin	
					if (SLOT == ST_EXT && SLOT_CE) begin
						IO_ADDR[0] <= ~IO_ADDR[0];
						if (!IO_ADDR[0])
							DT_RD_DATA[7:0] <= VRAM_Q;
						else
							DT_RD_DATA[15:8] <= VRAM_Q;
						if (IO_BYTE != IO_ADDR[0]) begin
							DT_RD_EXEC <= 0;
							DTC <= DTC_IDLE;
						end
					end
				end
				
				DTC_VRAM8_RD: begin	
					if (SLOT == ST_EXT && SLOT_CE) begin
						IO_ADDR[0] <= ~IO_ADDR[0];
						DT_RD_DATA[7:0] <= VRAM_Q;
						DT_RD_EXEC <= 0;
						DTC <= DTC_IDLE;
					end
				end
				
				DTC_CRAM_RD: begin	
					if (SLOT == ST_EXT && SLOT_CE) begin
						DT_RD_DATA[11:9] <= CRAM_Q_B[8:6];
						DT_RD_DATA[7:5] <= CRAM_Q_B[5:3];
						DT_RD_DATA[3:1] <= CRAM_Q_B[2:0];
						DT_RD_EXEC <= 0;
						DTC <= DTC_IDLE;
					end
				end
				
				DTC_VSRAM_RD: begin	
					if (SLOT == ST_EXT && SLOT_CE) begin
						if (IO_ADDR[6:1] < 40) begin
							DT_RD_DATA[10:0] <= VSRAM_Q_B[10:0];
						end else begin
							if (IO_ADDR[1])
								DT_RD_DATA[10:0] <= VSRAM_Q_A[10:0];
							else
								DT_RD_DATA[10:0] <= VSRAM_Q_A[21:11];
						end
						DT_RD_EXEC <= 0;
						DTC <= DTC_IDLE;
					end
				end
			endcase
			
			case (DMAC)
				DMA_IDLE: begin
					if (DMA_VBUS) begin
						if (!BG_N && !FF_BR_N && FF_DTACK_N) begin
							FF_DTACK_N <= 0;
//							DMA_VBUS_WC <= 2'b00;
							DMAC <= DMA_VBUS_WAIT;
						end
					end else if (DMA_FILL_START && FIFO_EMPTY) begin
						IO_ADDR <= ADDR;
						DMA_FILL_WE <= 1;
						DMAC <= DMA_FILL_WR;
					end else if (DMA_COPY && FIFO_EMPTY && SLOT_CE) begin
						DMA_COPY_WE <= 0;
						IO_ADDR <= {1'b0,DSA[15:0]};
						DMAC <= DMA_COPY_RD;
					end
				end
				
				DMA_VBUS_WAIT: begin
					if (!FF_BGACK_N && SLOT_CE) begin
						DMAC <= DMA_VBUS_WAIT2;
					end
				end
				
				DMA_VBUS_WAIT2: begin
					if (SLOT_CE) begin
						FF_VBUS_SEL <= 1;
						DMAC <= DMA_VBUS_RD;
					end
				end
				
				DMA_VBUS_RD: begin
					if (!VBUS_DTACK_N && !FIFO_FULL) begin
						FF_VBUS_DATA <= VBUS_DATA;
						FF_VBUS_SEL <= 0;
						if (SLOT == ST_REFRESH)
							DMAC <= DMA_VBUS_REFRESH;
						else
							DMAC <= DMA_VBUS_WR;
					end
				end
				
				DMA_VBUS_REFRESH: begin
					if (SLOT_CE) begin
						if (CODE[3:0] == 4'b0001)
							DMAC <= DMA_VBUS_WR;
						else
							DMAC <= DMA_VBUS_SKIP;
					end
				end
				
				DMA_VBUS_SKIP: begin
					if (SLOT_CE) begin
						DMAC <= DMA_VBUS_WR;
					end
				end
				
				DMA_VBUS_WR: begin
					if (SLOT_CE) begin
						FIFO.ITEMS[FIFO.WR_POS].ADDR <= ADDR;
						FIFO.ITEMS[FIFO.WR_POS].DATA <= FF_VBUS_DATA;
						FIFO.ITEMS[FIFO.WR_POS].CODE <= CODE[3:0];
						FIFO.WR_POS <= FIFO.WR_POS + 2'd1;
						FIFO_AMOUNT_INC = 1;
						
						ADDR <= ADDR + AI.INC;
						NEXT_DMA_SRC = DSA[15:0] + 16'd1;
						DSA[15:0] <= NEXT_DMA_SRC;
						NEXT_DMA_LEN = DLC - 16'd1;
						DLC <= NEXT_DMA_LEN;
						if (NEXT_DMA_LEN == 16'h0000) begin
							DMAC <= DMA_VBUS_END;
						end else begin
							FF_VBUS_SEL <= 1;
							DMAC <= DMA_VBUS_RD;
						end
					end
				end
				
				DMA_VBUS_END: begin
					DMA_VBUS <= 0;
					FF_BGACK_N <= 1;
					DMAC <= DMA_IDLE;
				end
				
				//fill
				DMA_FILL_WR2: begin
					IO_ADDR <= ADDR;
					DMAC <= DMA_FILL_WR;
				end
				
				DMA_FILL_WR: begin
					if (SLOT == ST_EXT && SLOT_CE) begin
						if (FIFO_EMPTY || DTC == DTC_FIFO_PAUSE) begin
							ADDR <= ADDR + AI.INC;
							IO_ADDR <= IO_ADDR + AI.INC;
							NEXT_DMA_SRC = DSA[15:0] + AI.INC;
							DSA[15:0] <= NEXT_DMA_SRC;
							NEXT_DMA_LEN = DLC - 16'd1;
							DLC <= NEXT_DMA_LEN;
							if (NEXT_DMA_LEN == 16'h0000) begin
								DMA_FILL <= 0;
								DMA_FILL_START <= 0;
								DMA_FILL_WE <= 0;
								DMAC <= DMA_IDLE;
							end else begin
								DMAC <= DMA_FILL_WR2;
							end
						end
					end
				end
				
				//copy
				DMA_COPY_RD: begin
					if (FIFO_EMPTY && SLOT == ST_EXT && SLOT_CE) begin
						IO_ADDR <= ADDR;
						IO_DATA <= {VRAM_Q,VRAM_Q};
						DMA_COPY_WE <= 1;
						DMAC <= DMA_COPY_WR;
					end
				end
				
				DMA_COPY_WR: begin
					if (FIFO_EMPTY && SLOT == ST_EXT && SLOT_CE) begin
						ADDR <= ADDR + AI.INC;
						NEXT_DMA_SRC = DSA[15:0] + 16'd1;
						DSA[15:0] <= NEXT_DMA_SRC;
						NEXT_DMA_LEN = DLC - 16'd1;
						DLC <= NEXT_DMA_LEN;
						if (NEXT_DMA_LEN == 16'h0000) begin
							DMA_COPY <= 0;
							DMAC <= DMA_IDLE;
						end else begin
							DMAC <= DMA_COPY_RD;
						end
						
						IO_ADDR <= {1'b0,NEXT_DMA_SRC};
						DMA_COPY_WE <= 0;
					end
				end
			endcase
			
			if (FIFO_AMOUNT_INC && !FIFO_AMOUNT_DEC)
				FIFO.AMOUNT <= FIFO.AMOUNT + 3'd1;
			else if (FIFO_AMOUNT_DEC && !FIFO_AMOUNT_INC)
				FIFO.AMOUNT <= FIFO.AMOUNT - 3'd1;
		end
	end
	
	bit [15:0] OPEN_BUS;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			OPEN_BUS <= '1;
		end else begin
			if (!AS_N) begin
				if (!RNW) 	
					OPEN_BUS <= DI;
				else
					OPEN_BUS <= DO;
			end
		end
	end
	
	wire IN_DMA = DMA_FILL | DMA_COPY | DMA_VBUS;
	always_comb begin
		if (A[4:2] == 3'b000)					// Data Port C00000-C00002 
			DO = DT_RD_DATA;
		else if (A[4:2] == 3'b001)				// Control Port C00004-C00006 (Read Status Register)
			DO = {OPEN_BUS[15:10],FIFO_EMPTY,FIFO_FULL,VINT_FLAG,SOVR_FLAG,SCOL_FLAG,(FIELD & MR4.LSM[0]),(IN_VBL | ~MR2.DISP),IN_HBL,IN_DMA,PAL};
		else if (A[4:3] == 2'b01)				// HV Counter C00008-C0000A
			DO = HV;
		else											// unused, PSG, DBG
			DO = 16'hFFFF;
	end
	
	assign DTACK_N = FF_DTACK_N;
	assign BGACK_N = FF_BGACK_N;
	assign BR_N = FF_BR_N;
	
	assign VBUS_A = DSA[22:0];
	assign VBUS_SEL = FF_VBUS_SEL;
	
	assign REFRESH = SLOT == ST_REFRESH && DMA_VBUS;
	
	//CRAM
	reg   [6:1] CRAM_ADDR_A;
	wire  [8:0] CRAM_Q_A;
	wire  [6:1] CRAM_ADDR_B = IO_ADDR[6:1];
	wire  [8:0] CRAM_D = {IO_DATA[11:9],IO_DATA[7:5],IO_DATA[3:1]};
	wire        CRAM_WE = ((IO_WE && FIFO_CODE == 4'b0011) || (DMA_FILL_WE && DMA_FILL_CODE == 4'b0011)) && SLOT == ST_EXT && SLOT_CE;
	wire  [8:0] CRAM_Q_B;
	vdp_cram CRAM
	(
		.clock(CLK),
		.data_b(CRAM_D),
		.address_a(CRAM_ADDR_A),
		.address_b(CRAM_ADDR_B),
		.wren_b(CRAM_WE),
		.q_a(CRAM_Q_A),
		.q_b(CRAM_Q_B)
	);
	
	//VSRAM
	wire  [5:1] VSRAM_ADDR_A = BG_VSRAM_ADDR;
	wire [21:0] VSRAM_Q_A;
	wire  [6:1] VSRAM_ADDR_B = IO_ADDR[6:1];
	wire [10:0] VSRAM_D = IO_DATA[10:0];
	wire        VSRAM_WE = ((IO_WE && FIFO_CODE == 4'b0101) || (DMA_FILL_WE && DMA_FILL_CODE == 4'b0101)) && SLOT == ST_EXT && SLOT_CE;
	wire [10:0] VSRAM_Q_B;
	vdp_vsram VSRAM
	(
		.clock(CLK),
		.data_b(VSRAM_D),
		.address_a(VSRAM_ADDR_A),
		.address_b(VSRAM_ADDR_B),
		.wren_b(VSRAM_WE),
		.q_a(VSRAM_Q_A),
		.q_b(VSRAM_Q_B)
	);
	
	//VRAM
	assign VRAM_A = SLOT == ST_SPRMAP || SLOT == ST_SPRCHAR                                                                  ? SPR_VRAM_ADDR : 
				       SLOT == ST_HSCROLL || SLOT == ST_BGAMAP || SLOT == ST_BGACHAR || SLOT == ST_BGBMAP || SLOT == ST_BGBCHAR ? BG_VRAM_ADDR :
				       !MR2.M128K                                                                                               ? IO_ADDR[15:0] : 
				                                                                                                                  {IO_ADDR[16:11],IO_ADDR[9:2],IO_ADDR[10],IO_ADDR[1]};
	assign VRAM_D = IO_DATA[7:0];
	assign VRAM_WE = ((IO_WE && FIFO_CODE == 4'b0001) || (DMA_FILL_WE && DMA_FILL_CODE == 4'b0001) || DMA_COPY_WE) && SLOT == ST_EXT && SLOT_CE;
	
	//H/V timing
	wire H40 = MR4.RS1;
	wire V30 = MR2.M2;
	
	bit SCLK_CE;
	always @(posedge CLK or negedge RST_N) begin
		bit [2:0] SCLK_CYCLES;
		bit [2:0] SCLK_DIV;

		if (!RST_N) begin
			SCLK_DIV <= '0;
			SCLK_CE <= 0;
		end else begin
			SCLK_CYCLES = !MR4.RS0 ? 3'd5 : 3'd4;
			
			SCLK_DIV <= SCLK_DIV + 3'd1;
			if (SCLK_DIV == SCLK_CYCLES - 1)
				SCLK_DIV <= '0;

			SCLK_CE <= 0;
			if (SCLK_DIV == SCLK_CYCLES - 1 - 1 && ENABLE)
				SCLK_CE <= 1;
		end
	end
	
	bit EDCLK_CE;
	always @(posedge CLK or negedge RST_N) begin
		bit [2:0] EDCLK_CYCLES;
		bit [2:0] EDCLK_DIV;
		bit       EDCLK_HALF;
		
		if (!RST_N) begin
			EDCLK_DIV <= '0;
			EDCLK_HALF <= 0;
			EDCLK_CE <= 0;
		end else begin
			if (!MR4.RS0)
				EDCLK_CYCLES = 3'd4;
			else if (({H_CNT,EDCLK_HALF} >= 10'h39A && {H_CNT,EDCLK_HALF} <= 10'h3A8) || 	//39A-3A8
					   ({H_CNT,EDCLK_HALF} >= 10'h3AB && {H_CNT,EDCLK_HALF} <= 10'h3B9) || 	//3AB-3B9
					   ({H_CNT,EDCLK_HALF} >= 10'h3BC && {H_CNT,EDCLK_HALF} <= 10'h3CA) ||	//3BC-3CA
					   ({H_CNT,EDCLK_HALF} >= 10'h3CD && {H_CNT,EDCLK_HALF} <= 10'h3DB)) 	//3CD-3DB
				EDCLK_CYCLES = 3'd5;
			else
				EDCLK_CYCLES = 3'd4;
			
			EDCLK_DIV <= EDCLK_DIV + 3'd1;
			if (EDCLK_DIV == EDCLK_CYCLES - 1) begin
				EDCLK_DIV <= '0;
				EDCLK_HALF <= ~EDCLK_HALF;
			end

			EDCLK_CE <= 0;
			if (EDCLK_DIV == EDCLK_CYCLES - 1 - 1 && ENABLE)
				EDCLK_CE <= 1;
		end
	end
	
	wire SC_CE = (SCLK_CE & ~H40) | (EDCLK_CE & H40);
	
	bit DCLK_HALF;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			DCLK_HALF <= 0;
		end else begin
			if (SC_CE) DCLK_HALF <= ~DCLK_HALF;
		end
	end
	
	wire DCLK_CE = SC_CE & DCLK_HALF;
	
	
	always @(posedge CLK or negedge RST_N) begin
		bit        FIELD_LATCH;
		
		if (!RST_N) begin
			H_CNT <= '0;
			V_CNT <= '0;
			FIELD <= 0;
			IN_HBL <= 0;
			IN_VBL <= 0;
			FF_HS <= 0;
			FF_VS <= 0;
			FIELD_LATCH <= 0;
		end else begin
			if (ENABLE && DCLK_CE) begin
				H_CNT <= H_CNT + 9'd1;
				if (H_CNT == 9'h127 && !H40)
					H_CNT <= 9'h1D2;
				else if (H_CNT == 9'h16C && H40)
					H_CNT <= 9'h1C9;
				
				if ((H_CNT == 9'h125 && !H40) || (H_CNT == 9'h165 && H40))
					IN_HBL <= 1;
				else if ((H_CNT == 9'h009 && !H40) || (H_CNT == 9'h00B && H40))
					IN_HBL <= 0;
				
				if ((H_CNT == 9'h1D8 && !H40) || (H_CNT == 9'h1CD && H40))
					FF_HS <= 1;
				else if ((H_CNT == 9'h1F2 && !H40) || (H_CNT == 9'h1EC && H40))
					FF_HS <= 0;
				
				if ((H_CNT == 9'h109 && !H40) || (H_CNT == 9'h149 && H40)) begin
					V_CNT <= V_CNT + 9'd1;			
					if (!PAL && !V30) begin
						if (V_CNT == 9'h0EA)
							V_CNT <= 9'h1E5;
					end else begin
						if (V_CNT == 9'h102 && !V30)
							V_CNT <= 9'h1CA;
						else if (V_CNT == 9'h10A && V30)
							V_CNT <= 9'h1D2;
					end
					
					if ((V_CNT == 9'h0DF && !V30) || (V_CNT == 9'h0EF && V30))
						IN_VBL <= 1;
					else if (V_CNT == 9'h1FE)
						IN_VBL <= 0;
						
					// FIELD changes at VINT, but the HV_COUNTER reflects the current field from line 0-0
					if (V_CNT == 9'h1FF)
						FIELD_LATCH <= FIELD;
				end
				
				if ((H_CNT == 9'h113 && !H40) || (H_CNT == 9'h153 && H40)) begin
					if ((V_CNT == 9'h1E5 && !PAL) || (V_CNT == 9'h1CA && PAL && !V30) || (V_CNT == 9'h1D2 && PAL && V30)) begin
						FF_VS <= 1;
						FIELD_OUT <= &MR4.LSM & ~FIELD_LATCH;
					end else if ((V_CNT == 9'h1E8 && !PAL) || (V_CNT == 9'h1CD && PAL && !V30) || (V_CNT == 9'h1D5 && PAL && V30)) begin
						FF_VS <= 0;
					end
				end
				
				if (H_CNT == 9'h000 && ((V_CNT == 9'h0E0 && !V30) || (V_CNT == 9'h0F0 && V30)))
					FIELD <= ~FIELD;
			end
		end
	end
	
	// VSync extension by half a line for interlace
	always @(posedge CLK or negedge RST_N) begin
	  // 1710 = 1/2 * 3420 clock per line
	  bit [10:0] VS_START_DELAY;
	  bit [10:0] VS_END_DELAY;
	  bit        VS_DELAY_ACTIVE;

		if (!RST_N) begin

		end else begin
		 if (FF_VS) begin
			// LSM[0] = 1 and FIELD = 0 right before vsync start -> start the delay
			if (((H_CNT == 9'h1D2 && !H40) || (H_CNT == 9'h1D1 && H40)) && 
				 ((V_CNT == 9'h1E5 && !PAL) || (V_CNT == 9'h1CA && PAL && !V30) || (V_CNT == 9'h1D2 && PAL && V30)) && 
				 MR4.LSM[0] && !FIELD) begin
			  VS_START_DELAY <= 1709;
			  VS_DELAY_ACTIVE <= 1;
			end
	
			// FF_VS already inactive, but end delay still != 0
			if (VS_END_DELAY != 0)
			  VS_END_DELAY <= VS_END_DELAY - 11'd1;
			else
			  VS_N <= 0;
			
		 end else begin
			// FF_VS = 0
			if (VS_DELAY_ACTIVE) begin
			  VS_END_DELAY <= 1709;
			  VS_DELAY_ACTIVE <= 0;
			end
	
			// FF_VS active, but start delay still != 0
			if (VS_START_DELAY != 0)
			  VS_START_DELAY <= VS_START_DELAY - 11'd1;
			else
			  VS_N <= 1;
		 end
		 HS_N <= ~FF_HS;
	  end 
	end
	
	bit HBLANK;
	bit VBLANK;
	always @(posedge CLK or negedge RST_N) begin
		bit V30_PREV;
		bit V30_LATCH;
	
		if (!RST_N) begin
			V30_LATCH <= 0;
			HBLANK <= 0;
			VBLANK <= 0;
		end else begin
			if (ENABLE && DCLK_CE) begin
				V30_PREV <= V30_PREV & V30;
				if (((H_CNT == 9'h109 && !H40) || (H_CNT == 9'h149 && H40)) && V_CNT == 9'h1FF) begin
					V30_LATCH <= V30_PREV;
					V30_PREV <= 1;
				end
	
				if (!BORDER_EN) begin
					if ((H_CNT == 9'h119 && !H40) || (H_CNT == 9'h159 && H40))
						HBLANK <= 1;
					else if ((H_CNT == 9'h019 && !H40) || (H_CNT == 9'h019 && H40))
						HBLANK <= 0;
					
					if ((H_CNT == 9'h109 && !H40) || (H_CNT == 9'h149 && H40)) begin
						if ((V_CNT == 9'h0DF && !V30_LATCH) || (V_CNT == 9'h0EF && V30_LATCH))
							VBLANK <= 1;
						else if (V_CNT == 9'h1FF)
							VBLANK <= 0;
					end
				end else begin
					if ((H_CNT == 9'h125 && !H40) || (H_CNT == 9'h165 && H40))
						HBLANK <= 1;
					else if ((H_CNT == 9'h009 && !H40) || (H_CNT == 9'h00B && H40))
						HBLANK <= 0;
					
					if ((H_CNT == 9'h109 && !H40) || (H_CNT == 9'h149 && H40)) begin
						if ((V_CNT == 9'h0E7 && !PAL) || (V_CNT == 9'h0FF && PAL && !V30_LATCH) || (V_CNT == 9'h107 && PAL && V30_LATCH))
							VBLANK <= 1;
						else if ((V_CNT == 9'h1F4 && !PAL) || (V_CNT == 9'h1D9 && PAL && !V30_LATCH) || (V_CNT == 9'h1E1 && PAL && V30_LATCH))
							VBLANK <= 0;
					end
				end
			end
		end
	end
	
	assign HBL = HBLANK;
	assign VBL = VBLANK;
	assign RESOLUTION = {V30,H40};
	assign INTERLACE = &MR4.LSM;
	
	//SLOTs
	wire SLOT_CE = DCLK_CE & H_CNT[0];
	
	always_comb begin
		if (IN_VBL || !DISP)
			if (H_CNT[5:1] == 5'b11001)
				SLOT_PIPE[0] = ST_REFRESH;
			else
				SLOT_PIPE[0] = ST_EXT;
		else if (H_CNT[8:1] == 8'b11110011)
			SLOT_PIPE[0] <= ST_HSCROLL;
		else if (H_CNT[8:4] == 5'b11111)
			case (H_CNT[3:1])
				3'b000: SLOT_PIPE[0] = ST_BGAMAP;
				3'b001: SLOT_PIPE[0] = ST_SPRCHAR;
				3'b010: SLOT_PIPE[0] = ST_BGACHAR;
				3'b011: SLOT_PIPE[0] = ST_BGACHAR;
				3'b100: SLOT_PIPE[0] = ST_BGBMAP;
				3'b101: SLOT_PIPE[0] = ST_SPRCHAR;
				3'b110: SLOT_PIPE[0] = ST_BGBCHAR;
				3'b111: SLOT_PIPE[0] = ST_BGBCHAR;
			endcase
		else if ((!H_CNT[8] && !H40) || (H_CNT[8:6] < 3'b101 && H40))
			case (H_CNT[3:1])
				3'b000: SLOT_PIPE[0] = ST_BGAMAP;
				3'b001: SLOT_PIPE[0] = H_CNT[5:4] == 2'b11 ? ST_REFRESH : ST_EXT;
				3'b010: SLOT_PIPE[0] = ST_BGACHAR;
				3'b011: SLOT_PIPE[0] = ST_BGACHAR;
				3'b100: SLOT_PIPE[0] = ST_BGBMAP;
				3'b101: SLOT_PIPE[0] = ST_SPRMAP;
				3'b110: SLOT_PIPE[0] = ST_BGBCHAR;
				3'b111: SLOT_PIPE[0] = ST_BGBCHAR;
			endcase
		else if ((H_CNT[8:1] == 8'b10000000 && !H40) || (H_CNT[8:1] == 8'b10000001 && !H40) || 
				   (H_CNT[8:1] == 8'b10010000 && !H40) || (H_CNT[8:1] == 8'b11110010 && !H40) ||
				   (H_CNT[8:1] == 8'b10100000 &&  H40) || (H_CNT[8:1] == 8'b10100001 &&  H40) || 
				   (H_CNT[8:1] == 8'b11100111 &&  H40))
			SLOT_PIPE[0] = ST_EXT;
		else
			SLOT_PIPE[0] = ST_SPRCHAR;
	end

	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			SLOT_PIPE[1] <= ST_EXT;
			SLOT_PIPE[2] <= ST_EXT;
		end else begin
			if (SLOT_CE) begin
				SLOT_PIPE[1] <= SLOT_PIPE[0];
				SLOT_PIPE[2] <= SLOT_PIPE[1];
			end
		end
	end
	
	assign SLOT = SLOT_PIPE[2];
	
	//Rendering
	bit  [1:0] BYTE_CNT;
	bit  [7:0] VRAM_SDATA_TEMP0;
	bit  [7:0] VRAM_SDATA_TEMP1;
	bit  [7:0] VRAM_SDATA_TEMP2;
	always @(posedge CLK or negedge RST_N) begin
		bit DIV2;
		
		if (!RST_N) begin
			DIV2 <= 0;
			BYTE_CNT <= '0;
		end else begin
			if (ENABLE) begin
				DIV2 <= ~DIV2;
				
				if (DIV2) begin
					case (BYTE_CNT)
						2'd0:	VRAM_SDATA_TEMP0 <= VRAM_Q;
						2'd1: VRAM_SDATA_TEMP1 <= VRAM_Q;
						2'd2: VRAM_SDATA_TEMP2 <= VRAM_Q;
						default:;
					endcase
					if (BYTE_CNT != 2'd3) BYTE_CNT <= BYTE_CNT + 2'd1;
				end
				
				if (DCLK_CE) begin
					BYTE_CNT <= 2'd0;
					DIV2 <= 0;
				end
			end
		end
	end
	
	wire [31:0] VRAM_SDATA = {VRAM_Q,VRAM_SDATA_TEMP2,VRAM_SDATA_TEMP1,VRAM_SDATA_TEMP0};
	
	wire [8:0] BG_X = H_CNT - 9'd4;
	wire [7:0] BG_Y = V_CNT[7:0];
	
	//Vertical scroll
	assign BG_VSRAM_ADDR = !MR3.VSCR ? '0 : H_CNT[8:4];
	
	always @(posedge CLK or negedge RST_N) begin
		bit [10:0] VSCRLA_LAST;
		bit [10:0] VSCRLB_LAST;
		
		if (!RST_N) begin
			VSCRLA <= '0;
			VSCRLB <= '0;
			VSCRLA_LAST <= '0;
			VSCRLB_LAST <= '0;
		end else begin
			if (ENABLE) begin
				if (SLOT_CE) begin
					if (!MR3.VSCR) begin
						if ((H_CNT == 9'h109 && !H40) || (H_CNT == 9'h149 && H40)) begin
							VSCRLA <= VSRAM_Q_A[10:0];
							VSCRLA_LAST <= VSRAM_Q_A[10:0];
							VSCRLB <= VSRAM_Q_A[21:11];
							VSCRLB_LAST <= VSRAM_Q_A[21:11];
						end
					end else begin
						if (H_CNT == 9'h1F3) begin
							if (!H40) begin
								VSCRLA <= '0;
								VSCRLB <= '0;
							end else if (VSCROLL_BUG) begin
								// partial column gets the last read values AND'ed in H40 ("left column scroll bug")
								VSCRLA <= VSCRLA_LAST & VSCRLB_LAST;
								VSCRLB <= VSCRLA_LAST & VSCRLB_LAST;
							end else begin
								// using VSRAM sometimes looks better (Gynoug)
								VSCRLA <= VSRAM_Q_A[10:0];
								VSCRLB <= VSRAM_Q_A[21:11];
							end
						end else if (H_CNT[3:0] == 4'h3 && H_CNT[8:6] <= 3'h4) begin
							VSCRLA <= VSRAM_Q_A[10:0];
							VSCRLA_LAST <= VSRAM_Q_A[10:0];
							VSCRLB <= VSRAM_Q_A[21:11];
							VSCRLB_LAST <= VSRAM_Q_A[21:11];
						end
					end
				end
			end
		end
	end
	
	//Backgrounds
	bit  [9:0] HSCRLA;
	bit  [9:0] HSCRLB;
	BGPatterName_t PNI[2];
	bit  [5:1] WHP_LATCH;
	bit        WHP_RIGT_LATCH;
	bit  [4:0] WVP_LATCH;
	bit        WVP_DOWN_LATCH;
	bit        WIN_HIT;
	bit        VG;
	always_comb begin
		bit  [9:0] OFFSET_X;
		bit [10:0] OFFSET_Y;
		bit  [5:0] CELL_X;
		bit  [6:0] CELL_Y;
		bit  [3:0] PIX_Y;
		bit  [1:0] PIX_X;
		bit [15:0] MAP_BASE;
		bit  [9:0] HSCRL;
		bit [10:0] VSCRL;
		bit  [7:0] HSCRL_MASK;
		bit        WIN_H, WIN_V;
		bit [15:0] PN;

		//scrolls
		if (SLOT == ST_BGAMAP || SLOT == ST_BGACHAR) begin
			HSCRL = HSCRLA;
			VSCRL = VSCRLA;
		end else begin
			HSCRL = HSCRLB;
			VSCRL = VSCRLB;
		end
		
		//window
		if (BG_X[8:4] == 5'b11111)
			WIN_H = 0;
		else if (BG_X[8:4] < WHP_LATCH)
			WIN_H = ~WHP_RIGT_LATCH;
		else
			WIN_H = WHP_RIGT_LATCH;
		
		if (BG_Y[7:3] < WVP_LATCH)
			WIN_V = ~WVP_DOWN_LATCH;
		else
			WIN_V = WVP_DOWN_LATCH;
		
		if (SLOT == ST_BGAMAP || SLOT == ST_BGACHAR)
			WIN_HIT = WIN_H | WIN_V;
		else
			WIN_HIT = 0;
		
		//planes
		if (WIN_HIT) begin
			OFFSET_X = {1'b0,BG_X};
			OFFSET_Y = {2'b00,BG_Y,1'b0};
		end else begin
			OFFSET_X = {&BG_X[8:7],BG_X} - {HSCRL[9:4],4'b0000};
			if (MR4.LSM != 2'b11)
				OFFSET_Y = {2'b00,BG_Y,1'b0} + {VSCRL[9:0],1'b0};
			else
				OFFSET_Y = {2'b00,BG_Y,FIELD} + VSCRL;
		end
		
		VG = 0;
		if (OFFSET_Y[3:1] == 3'h7 && OFFSET_Y[0] == &MR4.LSM)
			VG = 1;
				
		case (SLOT)
			ST_HSCROLL: begin
				HSCRL_MASK = {MR3.HSCR[1],MR3.HSCR[1],MR3.HSCR[1],MR3.HSCR[1],MR3.HSCR[1],MR3.HSCR[0],MR3.HSCR[0],MR3.HSCR[0]};
				BG_VRAM_ADDR = {NSDT.HS,(BG_Y & HSCRL_MASK),BYTE_CNT};
			end
			
			ST_BGAMAP, 
			ST_BGBMAP: begin		
				if (SS.HSZ == 2'b10)
					// illegal mode, 32x1
					CELL_Y = 7'b0000000;
				else if (SS.HSZ == 2'b11)
					// VSIZE is limited to 32 if HSIZE is 128
					CELL_Y = {2'b00,OFFSET_Y[8:4]};
				else if (SS.VSZ == 2'b11 && SS.HSZ == 2'b01)
					// VSIZE is limited to 64 if HSIZE is 64
					CELL_Y = {1'b0,OFFSET_Y[9:4]};
				else
					case (SS.VSZ)
						2'b00,
						2'b10: CELL_Y = {2'b00,OFFSET_Y[8:4]};	// 32 cells
						2'b01: CELL_Y = {1'b0,OFFSET_Y[9:4]};	// 64 cells
						2'b11: CELL_Y = OFFSET_Y[10:4];			// 128 cells
					endcase
				
				CELL_X = OFFSET_X[9:4];
				if (WIN_HIT) begin
					if (!H40)
						BG_VRAM_ADDR = {NTW.WD[15:11],11'b00000000000} + {3'b000, CELL_Y, CELL_X[3:0], BYTE_CNT}; // Window 32 cells
					else
						BG_VRAM_ADDR = {NTW.WD[15:12],12'b000000000000} + {2'b00, CELL_Y, CELL_X[4:0], BYTE_CNT}; // Window 64 cells
				end else begin
					MAP_BASE = {SLOT == ST_BGAMAP ? NTA.SA : NTB.SB,13'b0000000000000};
					case (SS.HSZ)
						2'b00,
						2'b10: BG_VRAM_ADDR = MAP_BASE + {3'b000, CELL_Y, CELL_X[3:0], BYTE_CNT}; // 32 cells
						2'b01: BG_VRAM_ADDR = MAP_BASE + {2'b00 , CELL_Y, CELL_X[4:0], BYTE_CNT}; // 64 cells
						2'b11: BG_VRAM_ADDR = MAP_BASE + {1'b0  , CELL_Y, CELL_X[5:0], BYTE_CNT}; // 128 cells
					endcase
				end
			end
			
			ST_BGACHAR,
			ST_BGBCHAR: begin
				if (!PNI[0].VF)
					PIX_Y =  OFFSET_Y[3:0];
				else
					PIX_Y = ~OFFSET_Y[3:0];
				
				if (MR4.LSM != 2'b11)
					BG_VRAM_ADDR = {PNI[0].PT[10:0], PIX_Y[3:1], BYTE_CNT};
				else
					BG_VRAM_ADDR = {PNI[0].PT[ 9:0], PIX_Y[3:0], BYTE_CNT};
			end
			
			default:
				BG_VRAM_ADDR = '0;
		endcase
	end
	
	BGTileBuf_t BGA_TILE_BUF;
	BGTileBuf_t BGB_TILE_BUF;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			HSCRLA <= '0;
			HSCRLB <= '0;
			PNI <= '{2{BGPN_NULL}};
			BGA_TILE_BUF <= '{2{'0}};
			BGB_TILE_BUF <= '{2{'0}};
		end else begin
			if (ENABLE) begin
				if (SLOT_CE) begin
					case (SLOT)
						ST_HSCROLL: begin
							HSCRLA <= VRAM_SDATA[9:0];
							HSCRLB <= VRAM_SDATA[25:16];
							WHP_LATCH <= WHP.WHP;
							WVP_LATCH <= WVP.WVP;
							WHP_RIGT_LATCH <= WHP.RIGT;
							WVP_DOWN_LATCH <= WVP.DOWN;
						end
						
						ST_BGAMAP,
						ST_BGBMAP: begin
							PNI[0] <= VRAM_SDATA[15:0];
							PNI[1] <= VRAM_SDATA[31:16];
						end
						
						ST_BGACHAR: begin
							if (!PNI[0].HF)
								BGA_TILE_BUF[0].DATA <= {VRAM_SDATA[15:0],VRAM_SDATA[31:16]};
							else
								BGA_TILE_BUF[0].DATA <= {VRAM_SDATA[19:16],VRAM_SDATA[23:20],VRAM_SDATA[27:24],VRAM_SDATA[31:28],
																 VRAM_SDATA[ 3: 0],VRAM_SDATA[ 7: 4],VRAM_SDATA[11: 8],VRAM_SDATA[15:12]};
								
							BGA_TILE_BUF[0].PAL <= PNI[0].CP;
							BGA_TILE_BUF[0].PRIO <= PNI[0].PRI;
							BGA_TILE_BUF[0].WIN <= WIN_HIT;
							BGA_TILE_BUF[0].VGRID <= VG;
							BGA_TILE_BUF[1] <= BGA_TILE_BUF[0];
							PNI[0] <= PNI[1];
						end
							
						ST_BGBCHAR: begin
							if (!PNI[0].HF)
								BGB_TILE_BUF[0].DATA <= {VRAM_SDATA[15:0],VRAM_SDATA[31:16]};
							else
								BGB_TILE_BUF[0].DATA <= {VRAM_SDATA[19:16],VRAM_SDATA[23:20],VRAM_SDATA[27:24],VRAM_SDATA[31:28],
																 VRAM_SDATA[ 3: 0],VRAM_SDATA[ 7: 4],VRAM_SDATA[11: 8],VRAM_SDATA[15:12]};
								
							BGB_TILE_BUF[0].PAL <= PNI[0].CP;
							BGB_TILE_BUF[0].PRIO <= PNI[0].PRI;
							BGB_TILE_BUF[0].WIN <= 0;
							BGB_TILE_BUF[0].VGRID <= VG;
							BGB_TILE_BUF[1] <= BGB_TILE_BUF[0];
							PNI[0] <= PNI[1];
						end

						default:;
					endcase
				end
			end
		end
	end
	
	//Sprites
	wire  [5:0] OBJ_MAX_CNT = !OBJ_MAX ? (!H40 ? 6'd16 : 6'd20) : (!H40 ? 6'd32 : 6'd40);
	wire        OBJ_CE = SLOT_CE || (DCLK_CE && OBJ_MAX);
	
	bit   [6:0] OBJ_N;
	bit   [5:0] OBJC_Y_OFS;
	
	wire  [6:0] OBJC_ADDR_RD = SLOT == ST_SPRCHAR ? (OBJ_N & {H40,6'b111111}) : OBJVI_Q;
	wire  [6:0] OBJC_ADDR_WR = IO_ADDR[9:3] & {H40,6'b111111};
	wire [31:0] OBJC_D = !MR2.M128K ? {4{IO_DATA[7:0]}} : {2{IO_DATA[15:0]}};
	wire        OBJC_WE = (IO_ADDR[16:10] == SAT.AT[16:10]) && ((IO_ADDR[9] & ~H40) == (SAT.AT[9] & ~H40)) && ((IO_WE && FIFO_CODE == 4'b0001) || (DMA_FILL_WE && DMA_FILL_CODE == 4'b0001) || DMA_COPY_WE) && SLOT == ST_EXT && SLOT_CE;
	wire  [3:0] OBJC_BE = {~IO_ADDR[2] &  IO_ADDR[1] & ( IO_ADDR[0] | MR2.M128K),
	                       ~IO_ADDR[2] &  IO_ADDR[1] & (~IO_ADDR[0] | MR2.M128K),
	                       ~IO_ADDR[2] & ~IO_ADDR[1] & ( IO_ADDR[0] | MR2.M128K),
	                       ~IO_ADDR[2] & ~IO_ADDR[1] & (~IO_ADDR[0] | MR2.M128K)};
	wire [31:0] OBJC_Q;
	obj_cache OBJ_CACHE
	(
		.clock(CLK),
		.wraddress(OBJC_ADDR_WR),
		.data(OBJC_D),
		.wren(OBJC_WE),
		.byteena_a(OBJC_BE),
		.rdaddress(OBJC_ADDR_RD),
		.q(OBJC_Q)
	);
	
	bit   [5:0] OBJVI_ADDR_RD;
	bit   [5:0] OBJVI_ADDR_WR;
	wire  [6:0] OBJVI_D = OBJ_N;
	wire        OBJVI_WE = OBJ_FIND && (OBJVI_ADDR_WR < OBJ_MAX_CNT) && SLOT == ST_SPRCHAR && DCLK_CE;
	wire  [6:0] OBJVI_Q;
	vdp_obj_visinfo OBJ_VISINFO
	(
		.clock(CLK),
		.address_a(OBJVI_ADDR_RD),
		.q_a(OBJVI_Q),
		.address_b(OBJVI_ADDR_WR),
		.data_b(OBJVI_D),
		.wren_b(OBJVI_WE)
	);

	bit   [5:0] OBJSI_ADDR_RD;
	bit   [5:0] OBJSI_ADDR_WR;
	wire [34:0] OBJSI_D = {VRAM_SDATA[24:0], OBJC_Q[27:24], OBJC_Y_OFS};
	wire        OBJSI_WE = (OBJVI_ADDR_RD < OBJVI_ADDR_WR) && SLOT == ST_SPRMAP && OBJ_CE;
	wire [34:0] OBJSI_Q;
	vdp_obj_spinfo OBJ_SPINFO
	(
		.clock(CLK),
		.address_a(OBJSI_ADDR_RD),
		.q_a(OBJSI_Q),
		.address_b(OBJSI_ADDR_WR),
		.data_b(OBJSI_D),
		.wren_b(OBJSI_WE)
	);

	ObjRenderInfo_t OBJRI[14];
	
	bit   [8:0] SPR_Y;
	ObjCacheInfo_t OBJ_CI;
	ObjSpriteInfo_t OBJ_SI;
	bit         OBJ_FIND;
	bit   [1:0] OBJ_TILE_N;
	bit         OBJ_FIND_DONE;
	bit   [8:0] OBJ_HPOS;
	always_comb begin
		bit  [9:0] TEMP;
		bit  [5:0] OBJC_TILE_Y;
		bit  [1:0] OBJ_TILE_X;
		bit  [1:0] OBJ_TILE_Y;
		bit  [3:0] OBJ_TILE_X_24;
		bit  [3:0] OBJ_OFS_Y;
		bit  [7:0] OBJ_TILE_OFS;
		bit        OBJ_MASKED;
		bit        OBJ_VALID_X;

		//part 1,2
		OBJ_CI = OBJC_Q;
		
		if (MR4.LSM == 2'b11)
			TEMP = 10'b0100000000 + {1'b0,SPR_Y[7:0],FIELD} - OBJ_CI.VP[9:0];
		else
			TEMP = 10'b0100000000 + {1'b0,SPR_Y[7:0],1'b0}  - {OBJ_CI.VP[8:0],1'b0};
		
		//save only the last 5(6 in doubleres) bits of the offset for part 3
		//Titan 2 textured cube (ab)uses this
		OBJC_Y_OFS = TEMP[5:0];
		
		//part 3
		OBJ_SI = OBJSI_Q;
		
		OBJ_FIND = 0;
		case (SLOT)
			ST_SPRMAP: begin		
				//part 2
				if (!H40)
					SPR_VRAM_ADDR = {SAT.AT[15: 9], OBJVI_Q[5:0], 1'b1, BYTE_CNT};
				else
					SPR_VRAM_ADDR = {SAT.AT[15:10], OBJVI_Q[6:0], 1'b1, BYTE_CNT};
			end
			
			ST_SPRCHAR: begin
				//part 1
				OBJC_TILE_Y = TEMP[9:4];
				if ((OBJ_CI.VS == 2'b00 && OBJC_TILE_Y[5:0] == 6'b000000                           ) || // 8 pix
					 (OBJ_CI.VS == 2'b01 && OBJC_TILE_Y[5:1] == 5'b00000                            ) || // 16 pix
					 (OBJ_CI.VS == 2'b10 && OBJC_TILE_Y[5:2] == 4'b0000 && OBJC_TILE_Y[1:0] != 2'b11) ||	// 24 pix
					 (OBJ_CI.VS == 2'b11 && OBJC_TILE_Y[5:2] == 4'b0000                             ))  	// 32 pix
					OBJ_FIND = ~OBJ_FIND_DONE;

				//part 3
				if (!OBJ_SI.HF)
					OBJ_TILE_X =             OBJ_TILE_N;
				else
					OBJ_TILE_X = OBJ_SI.HS - OBJ_TILE_N;
				
				if (!OBJ_SI.VF) begin
					OBJ_TILE_Y =             OBJ_SI.YOFS[5:4];
					OBJ_OFS_Y =  OBJ_SI.YOFS[3:0];
				end else begin
					OBJ_TILE_Y = OBJ_SI.VS - OBJ_SI.YOFS[5:4];
					OBJ_OFS_Y = ~OBJ_SI.YOFS[3:0];
				end
				OBJ_TILE_X_24 = {(OBJ_TILE_X[1] & OBJ_TILE_X[0]), (OBJ_TILE_X[1] & ~OBJ_TILE_X[0]), (OBJ_TILE_X[1] ^ OBJ_TILE_X[0]), OBJ_TILE_X[0]};
				case (OBJ_SI.VS)
					2'b00: OBJ_TILE_OFS = {2'b00, OBJ_TILE_X,   4'b0000} + {4'b0000               , OBJ_OFS_Y};	// 8 pixels
					2'b01: OBJ_TILE_OFS = {1'b0 , OBJ_TILE_X,  5'b00000} + {3'b000 , OBJ_TILE_Y[0], OBJ_OFS_Y};	// 16 pixels
					2'b10: OBJ_TILE_OFS = {    OBJ_TILE_X_24,   4'b0000} + {2'b00  , OBJ_TILE_Y   , OBJ_OFS_Y};	// 24 pixels
					2'b11: OBJ_TILE_OFS = {       OBJ_TILE_X, 6'b000000} + {2'b00  , OBJ_TILE_Y   , OBJ_OFS_Y};	// 32 pixels
				endcase
				
				if (MR4.LSM == 2'b11)
					SPR_VRAM_ADDR = {OBJ_SI.SN[ 9:0],6'b000000} + {6'b000000 , OBJ_TILE_OFS[7:0], BYTE_CNT};
				else
					SPR_VRAM_ADDR = {OBJ_SI.SN[10:0],5'b00000}  + {7'b0000000, OBJ_TILE_OFS[7:1], BYTE_CNT};
			end
				
			default:
				SPR_VRAM_ADDR = '0;
		endcase
		
		OBJ_HPOS = OBJ_SI.HP + {4'b0000,OBJ_TILE_N,3'b000} - 9'b010000000;
	end
	
	always @(posedge CLK or negedge RST_N) begin
		bit        OBJ_MASKED;
		bit        OBJ_VALID_X;

		if (!RST_N) begin
			SPR_Y <= '0;
			OBJ_N <= '0;
			OBJ_TILE_N <= '0;
			OBJ_VALID_X <= '0;
			OBJ_MASKED <= 0;
			OBJ_FIND_DONE <= 0;
			OBJVI_ADDR_WR <= '0;
			OBJVI_ADDR_RD <= '0;
			OBJSI_ADDR_WR <= '0;
			OBJSI_ADDR_RD <= '0;
		end else begin	
			if (ENABLE) begin
				if (SLOT == ST_SPRCHAR && DCLK_CE) begin
					OBJ_N <= OBJ_CI.LINK;
					if (!OBJ_CI.LINK || ((OBJ_CI.LINK[6] && !H40) || (&OBJ_CI.LINK[6:5] && H40)))
						OBJ_FIND_DONE <= 1;
					
					if (OBJ_FIND && OBJVI_ADDR_WR < OBJ_MAX_CNT)
						OBJVI_ADDR_WR <= OBJVI_ADDR_WR + 6'd1;
				end
				
				if (OBJ_CE) begin
					case (SLOT)
						ST_SPRMAP: begin
							OBJVI_ADDR_RD <= OBJVI_ADDR_RD + 6'd1;
							if (OBJVI_ADDR_RD == OBJ_MAX_CNT - 1)
								OBJVI_ADDR_RD <= '0;
							
							if (OBJVI_ADDR_RD < OBJVI_ADDR_WR)
								OBJSI_ADDR_WR <= OBJSI_ADDR_WR + 6'd1;
						end
						
						ST_SPRCHAR: begin
							if (OBJSI_ADDR_RD < OBJSI_ADDR_WR) begin
								OBJ_TILE_N <= OBJ_TILE_N + 2'd1;
								if (OBJ_TILE_N == OBJ_SI.HS) begin
									OBJ_TILE_N <= '0;
									OBJSI_ADDR_RD <= OBJSI_ADDR_RD + 6'd1;
								end
								OBJRI[0].XPOS <= OBJ_HPOS;
								if (!OBJ_SI.HF)
									OBJRI[0].DATA <= VRAM_SDATA;
								else
									OBJRI[0].DATA <= {VRAM_SDATA[ 3: 0],VRAM_SDATA[ 7: 4],VRAM_SDATA[11: 8],VRAM_SDATA[15:12],
														   VRAM_SDATA[19:16],VRAM_SDATA[23:20],VRAM_SDATA[27:24],VRAM_SDATA[31:28]};
								OBJRI[0].PAL <= OBJ_SI.CP;
								OBJRI[0].PRIO <= OBJ_SI.PRI;
								OBJRI[0].EN <= ~OBJ_MASKED;
								OBJRI[0].BORD <= 3'b000;
								if (OBJ_TILE_N == 0)
									OBJRI[0].BORD[0] <= SPR_GRID_EN;	//left border
								
								if (OBJ_TILE_N == OBJ_SI.HS)
									OBJRI[0].BORD[1] <= SPR_GRID_EN;	//rigth border
								
								if (OBJ_SI.YOFS == 0 || (OBJ_SI.VS == OBJ_SI.YOFS[5:4] && OBJ_SI.YOFS[3:1] == 3'b111))	//top/bottom border
									OBJRI[0].BORD[2] <= SPR_GRID_EN;
								
							end else begin
								OBJRI[0].EN <= 0;
							end
							
							if (OBJ_SI.HP != 0)
								OBJ_VALID_X <= 1;
							else if (OBJ_VALID_X)
								OBJ_MASKED <= 1;
						end
						
						default:;
					endcase
					
					if ((H_CNT == 9'h103 && !H40) || (H_CNT == 9'h143 && H40)) begin
						SPR_Y <= V_CNT + 9'd2;
						OBJ_N <= 0;
						OBJ_TILE_N <= '0;
						OBJ_FIND_DONE <= 0;
						OBJVI_ADDR_WR <= '0;
						OBJSI_ADDR_RD <= '0;
					end
					
					if (H_CNT == 9'h003) begin
						if (OBJVI_ADDR_WR < OBJ_MAX_CNT)
							OBJVI_ADDR_RD <= OBJVI_ADDR_WR;
						else
							OBJVI_ADDR_RD <= '0;
						
						OBJSI_ADDR_WR <= '0;
						OBJ_VALID_X <= 0;
						if (OBJSI_ADDR_RD < OBJSI_ADDR_WR)
							OBJ_VALID_X <= 1;
						
						OBJ_MASKED <= 0;
						OBJRI[0].EN <= 0;
					end
					
					OBJRI[1] <= OBJRI[0];
					OBJRI[2] <= OBJRI[1];
					OBJRI[3] <= OBJRI[2];
					OBJRI[4] <= OBJRI[3];
					OBJRI[5] <= OBJRI[4];
					OBJRI[6] <= OBJRI[5];
					OBJRI[6] <= OBJRI[5];
					OBJRI[7] <= OBJRI[6];
					OBJRI[8] <= OBJRI[7];
					OBJRI[9] <= OBJRI[8];
					OBJRI[10] <= OBJRI[9];
					OBJRI[11] <= OBJRI[10];
					OBJRI[12] <= OBJRI[11];
					OBJRI[13] <= OBJRI[12];
				end
			end
		end
	end
	
	ObjRenderInfo_t OBJRI_LAST, OBJRI_PREV;
	assign OBJRI_LAST = !OBJ_MAX ? OBJRI[6] : OBJRI[13];
	assign OBJRI_PREV = !OBJ_MAX ? OBJRI[5] : OBJRI[12];
	
	bit  [3:0] OBJ_PIX;
	bit  [8:0] OBJL_ADDR;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			OBJ_PIX <= '0;
			OBJL_ADDR <= '0;
		end else begin
			if (ENABLE) begin
				if (OBJRI_LAST.EN && !OBJ_PIX[3]) begin
					OBJL_ADDR <= OBJL_ADDR + 9'd1;
					OBJ_PIX <= OBJ_PIX + 4'd1;
				end
				
				if (OBJRI_PREV.EN && OBJ_CE) begin
					OBJL_ADDR <= OBJRI_PREV.XPOS;
					OBJ_PIX <= '0;
				end
			end
		end
	end

	reg [7:0] OBJL_D;
	always_comb begin
		case (OBJ_PIX[2:0])
			3'b100: OBJL_D = {OBJRI_LAST.BORD[2]                     , OBJRI_LAST.PRIO, OBJRI_LAST.PAL, OBJRI_LAST.DATA[31:28]};
			3'b101: OBJL_D = {OBJRI_LAST.BORD[2]                     , OBJRI_LAST.PRIO, OBJRI_LAST.PAL, OBJRI_LAST.DATA[27:24]};
			3'b110: OBJL_D = {OBJRI_LAST.BORD[2]                     , OBJRI_LAST.PRIO, OBJRI_LAST.PAL, OBJRI_LAST.DATA[23:20]};
			3'b111: OBJL_D = {OBJRI_LAST.BORD[2] | OBJRI_LAST.BORD[1], OBJRI_LAST.PRIO, OBJRI_LAST.PAL, OBJRI_LAST.DATA[19:16]};
			3'b000: OBJL_D = {OBJRI_LAST.BORD[2] | OBJRI_LAST.BORD[0], OBJRI_LAST.PRIO, OBJRI_LAST.PAL, OBJRI_LAST.DATA[15:12]};
			3'b001: OBJL_D = {OBJRI_LAST.BORD[2]                     , OBJRI_LAST.PRIO, OBJRI_LAST.PAL, OBJRI_LAST.DATA[11: 8]};
			3'b010: OBJL_D = {OBJRI_LAST.BORD[2]                     , OBJRI_LAST.PRIO, OBJRI_LAST.PAL, OBJRI_LAST.DATA[ 7: 4]};
			3'b011: OBJL_D = {OBJRI_LAST.BORD[2]                     , OBJRI_LAST.PRIO, OBJRI_LAST.PAL, OBJRI_LAST.DATA[ 3: 0]};
		endcase
	end
	wire       OBJL_WE = OBJRI_LAST.EN && !OBJ_PIX[3] && OBJL_Q[3:0] == 4'b0000;
	wire [7:0] OBJL_Q;

	vdp_obj_line OBJ_LINE
	(
		.clock(CLK),
		.rdaddress(!DISP_EN_PIPE[2] ? OBJL_ADDR : DISP_X),
		.wraddress(!DISP_EN_PIPE[2] ? OBJL_ADDR : DISP_X),
		.data(!DISP_EN_PIPE[2] ? OBJL_D : '0),
		.wren(!DISP_EN_PIPE[2] ? OBJL_WE : DCLK_CE),
		.q(OBJL_Q)
	);

	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			SCOL_FLAG <= 0;
			SOVR_FLAG <= 0;
		end else begin
			if (ENABLE) begin
				if (OBJRI_LAST.EN && !OBJ_PIX[3] && OBJL_Q[3:0] != 4'b0000 && OBJL_D[3:0] != 4'b0000)
					SCOL_FLAG <= 1;
				else if (SCOL_FLAG_CLR)
					SCOL_FLAG <= 0;
				
				if (H_CNT == 9'h003 && !IN_VBL && OBJSI_ADDR_RD < OBJSI_ADDR_WR && OBJ_CE)
					SOVR_FLAG <= 1;
				else if (SOVR_FLAG_CLR)
					SOVR_FLAG <= 0;
			end
		end
	end

	bit  [7:0] DISP_SR;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			DISP_EN_PIPE <= '{3{0}};
			DISP_SR <= '0;
		end else begin
			if (ENABLE && DCLK_CE) begin
				if ((H_CNT == 9'h013 && !H40) || (H_CNT == 9'h013 && H40))
					DISP_EN_PIPE[0] <= ~IN_VBL;
				else if ((H_CNT == 9'h113 && !H40) || (H_CNT == 9'h153 && H40))
					DISP_EN_PIPE[0] <= 0;
				
				DISP_EN_PIPE[1] <= DISP_EN_PIPE[0];
				DISP_EN_PIPE[2] <= DISP_EN_PIPE[1];
			end
			
			if (ENABLE && SC_CE) begin
				DISP_SR <= {DISP_SR[6:0],MR2.DISP};
			end
		end
	end
	assign DISP = DISP_SR[7];
	
	always @(posedge CLK or negedge RST_N) begin
		BGTile_t   BGA_TILE[4];
		BGTile_t   BGB_TILE[4];
		bit        BGA_WIN_LAST;
		bit  [4:0] XA, XB;
		bit  [2:0] PIXA, PIXB;
		bit  [1:0] CELLA, CELLB, CELLW;
		bit  [3:0] BGA_COL, BGB_COL, SPR_COL;
		bit  [1:0] BGA_PAL, BGB_PAL, SPR_PAL;
		bit        BGA_PRIO, BGB_PRIO, SPR_PRIO;
		bit        SPR_COL_30, SPR_COL_31;
		bit  [5:0] PAL_COL, PAL_COL_DBG;
		bit        SPR_BORD;
		PixMode_t  PIX_MODE_PIPE[3];
		PixMode_t  PIX_MODE_TEMP;
		bit  [8:0] PIX_COL_PIPE[2];
		bit        BACK_COL_PIPE[3];
		bit        DISP_GRID;
	
		if (!RST_N) begin
			DISP_X <= '0;
			BGA_TILE <= '{4{'0}};
			BGB_TILE <= '{4{'0}};
			BGA_WIN_LAST <= 0;
			PIX_COL_PIPE <= '{2{'0}};
			PIX_MODE_PIPE <= '{3{PIX_NORMAL}};
			DISP_GRID <= 0;
			B <= '0;
			G <= '0;
			R <= '0;
			CE_PIX <= 0;
		end else begin
			CE_PIX <= 0;
			if (ENABLE && DCLK_CE) begin
				if (H_CNT[3:0] == 4'h5) begin
					BGA_TILE[0] <= BGA_TILE_BUF[1];
					BGA_TILE[1] <= BGA_TILE_BUF[0];
					if (!BGA_WIN_LAST) begin
						BGA_TILE[2] <= BGA_TILE[0];
						BGA_TILE[3] <= BGA_TILE[1];
					end else begin
						BGA_TILE[2] <= BGA_TILE_BUF[1];
						BGA_TILE[3] <= BGA_TILE_BUF[0];
					end
					BGA_WIN_LAST <= BGA_TILE_BUF[1].WIN;
					
					BGB_TILE[0] <= BGB_TILE_BUF[1];
					BGB_TILE[1] <= BGB_TILE_BUF[0];
					BGB_TILE[2] <= BGB_TILE[0];
					BGB_TILE[3] <= BGB_TILE[1];
				end

				//Pipeline 0
				if (DISP_EN_PIPE[2]) begin
					CELLW = {1'b0,DISP_X[3]};
					if (BGA_TILE[CELLW].WIN)
						XA = {1'b0,DISP_X[3:0]};
					else
						XA = {1'b0,DISP_X[3:0]} - {1'b0,HSCRLA[3:0]};
					
					CELLA = XA[4:3];
					PIXA = ~XA[2:0];
					BGA_COL = {BGA_TILE[CELLA].DATA[{PIXA,2'b11}], BGA_TILE[CELLA].DATA[{PIXA,2'b10}], BGA_TILE[CELLA].DATA[{PIXA,2'b01}], BGA_TILE[CELLA].DATA[{PIXA,2'b00}]};
					BGA_PAL = BGA_TILE[CELLA].PAL;
					BGA_PRIO = BGA_TILE[CELLA].PRIO;
					
					XB = {1'b0,DISP_X[3:0]} - {1'b0,HSCRLB[3:0]};
					CELLB = XB[4:3];
					PIXB = ~XB[2:0];
					BGB_COL = {BGB_TILE[CELLB].DATA[{PIXB,2'b11}], BGB_TILE[CELLB].DATA[{PIXB,2'b10}], BGB_TILE[CELLB].DATA[{PIXB,2'b01}], BGB_TILE[CELLB].DATA[{PIXB,2'b00}]};
					BGB_PAL = BGB_TILE[CELLB].PAL;
					BGB_PRIO = BGB_TILE[CELLB].PRIO;
					
					SPR_COL = OBJL_Q[3:0];
					SPR_PAL = OBJL_Q[5:4];
					SPR_PRIO = OBJL_Q[6];
					SPR_BORD = OBJL_Q[7];
					SPR_COL_31 = (OBJL_Q[5:0] == 6'h3F);
					SPR_COL_30 = (OBJL_Q[5:0] == 6'h3E);
						
					BACK_COL_PIPE[0] <= 0;
					if      (SPR_COL != 4'b0000 &&  SPR_PRIO && (!MR4.STE || (!SPR_COL_30 && !SPR_COL_31)) && SPR_EN)
						PAL_COL = {SPR_PAL,SPR_COL};
					else if (BGA_COL != 4'b0000 &&  BGA_PRIO                                               && BGA_EN)
						PAL_COL = {BGA_PAL,BGA_COL};
					else if (BGB_COL != 4'b0000 &&  BGB_PRIO                                               && BGB_EN)
						PAL_COL = {BGB_PAL,BGB_COL};
					else if (SPR_COL != 4'b0000 && !SPR_PRIO && (!MR4.STE || (!SPR_COL_30 && !SPR_COL_31)) && SPR_EN)
						PAL_COL = {SPR_PAL,SPR_COL};
					else if (BGA_COL != 4'b0000 && !BGA_PRIO                                               && BGA_EN)
						PAL_COL = {BGA_PAL,BGA_COL};
					else if (BGB_COL != 4'b0000 && !BGB_PRIO                                               && BGB_EN)
						PAL_COL = {BGB_PAL,BGB_COL};
					else begin
						PAL_COL = {BGC.PAL,BGC.COL};
						BACK_COL_PIPE[0] <= 1;
					end
					
					if (MR4.STE && !BGA_PRIO && !BGB_PRIO)
						//if all layers are normal priority, then shadowed
						PIX_MODE_TEMP = PIX_SHADOW;
					else
						PIX_MODE_TEMP = PIX_NORMAL;
					
					PIX_MODE_PIPE[0] <= PIX_MODE_TEMP;
					if (!DISP) begin
						PIX_MODE_PIPE[0] <= PIX_NORMAL;
					end else if (MR4.STE && (SPR_PRIO || ((!BGA_PRIO || BGA_COL == 4'b0000) && (!BGB_PRIO || BGB_COL == 4'b0000)))) begin
						//sprite is visible
						if (SPR_COL_30)
							//if sprite is palette 3/color 14 increase intensity
							if (PIX_MODE_TEMP == PIX_SHADOW)
								PIX_MODE_PIPE[0] <= PIX_NORMAL;
							else
								PIX_MODE_PIPE[0] <= PIX_HIGHLIGHT;
						else if (SPR_COL_31)
							//if sprite is visible and palette 3/color 15, decrease intensity
							PIX_MODE_PIPE[0] <= PIX_SHADOW;
						else if ((SPR_PRIO && SPR_COL != 4'b0000) || SPR_COL == 4'b1110)
							//sprite color 14 or high prio always shows up normal
							PIX_MODE_PIPE[0] <= PIX_NORMAL;
					end
					
					case (DBG[8:7])
						2'b00: PAL_COL_DBG = {BGC.PAL,BGC.COL};
						2'b01: PAL_COL_DBG = {SPR_PAL,SPR_COL};
						2'b10: PAL_COL_DBG = {BGA_PAL,BGA_COL};
						2'b11: PAL_COL_DBG = {BGB_PAL,BGB_COL};
					endcase

					if (!DISP)
						CRAM_ADDR_A <= {BGC.PAL,BGC.COL};
					else if (DBG[6])
						CRAM_ADDR_A <= PAL_COL_DBG;
					else if (DBG[8:7] != 2'b00)
						CRAM_ADDR_A <= PAL_COL & PAL_COL_DBG;
					else
						CRAM_ADDR_A <= PAL_COL;
					
					DISP_GRID <= 0;
					if (((XA[2:0] == 7 || BGA_TILE[CELLA].VGRID) && BG_GRID_EN[0]) ||
						 ((XB[2:0] == 7 || BGB_TILE[CELLB].VGRID) && BG_GRID_EN[1]) || 
						 (SPR_BORD && SPR_GRID_EN)) begin
						DISP_GRID <= 1;
					end
					
					DISP_X <= DISP_X + 9'd1;
				end else begin
					CRAM_ADDR_A <= {BGC.PAL,BGC.COL};
					PIX_MODE_PIPE[0] <= PIX_NORMAL;
					DISP_X <= '0;
					DISP_GRID <= 0;
				end
				
				if (DISP_GRID) begin
					PIX_COL_PIPE[0] <= '1;
					PIX_MODE_PIPE[1] <= PIX_NORMAL;
					BACK_COL_PIPE[1] <= 0;
				end else begin
					PIX_COL_PIPE[0] <= CRAM_Q_A;
					PIX_MODE_PIPE[1] <= PIX_MODE_PIPE[0];
					BACK_COL_PIPE[1] <= BACK_COL_PIPE[0];
				end
				
				//Pipeline 1
				PIX_COL_PIPE[1] <= PIX_COL_PIPE[0];
				PIX_MODE_PIPE[2] <= PIX_MODE_PIPE[1];
				BACK_COL_PIPE[2] <= BACK_COL_PIPE[1];
				
				//Pipeline 2
				case (PIX_MODE_PIPE[2])
					PIX_SHADOW: begin
						// half brightness
						B <= {1'b0,PIX_COL_PIPE[1][8:6]};
						G <= {1'b0,PIX_COL_PIPE[1][5:3]};
						R <= {1'b0,PIX_COL_PIPE[1][2:0]};
					end
					
					PIX_NORMAL: begin
						// normal brightness
						B <= {PIX_COL_PIPE[1][8:6],1'b0};
						G <= {PIX_COL_PIPE[1][5:3],1'b0};
						R <= {PIX_COL_PIPE[1][2:0],1'b0};
					end
				
					PIX_HIGHLIGHT: begin
						// increased brightness
						B <= {1'b0,PIX_COL_PIPE[1][8:6]} + 4'h7;
						G <= {1'b0,PIX_COL_PIPE[1][5:3]} + 4'h7;
						R <= {1'b0,PIX_COL_PIPE[1][2:0]} + 4'h7;
					end
				endcase
				YS_N <= ~BACK_COL_PIPE[2];
				
				CE_PIX <= 1;
			end
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		bit HL_OLD;
		
		if (!RST_N) begin
			HV <= '0;
			HL_OLD <= 1;
		end else begin
			if (ENABLE) begin
				HL_OLD <= HL;
				if (!MR1.M3 || (!HL && HL_OLD)) begin	
					HV[7:0] <= H_CNT[8:1];
					case (MR4.LSM)
						2'b01:   HV[15:8] <= {V_CNT[7:1],V_CNT[8]};
						2'b11:   HV[15:8] <= {V_CNT[6:0],V_CNT[7]};
						default: HV[15:8] <=  V_CNT[7:0];
					endcase
					
//					EXINT_PENDING_SET <= 1;
				end
			end
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		bit        HINT_EN;
		bit  [7:0] HINT_COUNT;
		bit        INTACK_N_OLD;
		bit [11:0] Z80_INT_WAIT;
		
		if (!RST_N) begin
			VINT_FLAG <= 0;
			HINT_FLAG <= 0;
			HINT_COUNT <= '0;
			Z80_INT_FLAG <= 0;
			Z80_INT_WAIT <= '0;
			INTACK_N_OLD <= 0;
		end else begin
			if (ENABLE) begin
				INTACK_N_OLD <= INTACK_N;
				if (!INTACK_N && INTACK_N_OLD) begin
					if (VINT_FLAG && MR2.IE0)
						VINT_FLAG <= 0;
					else if (HINT_FLAG && MR1.IE1)
						HINT_FLAG <= 0;
//					else if (EXINT_FF)
//						EXINT_PENDING <= 0;
				end

				if (DCLK_CE) begin
					if (H_CNT == 9'h000 && ((V_CNT == 9'h0E0 && !V30) || (V_CNT == 9'h0F0 && V30))) begin
						VINT_FLAG <= 1;
						Z80_INT_FLAG <= 1;
						Z80_INT_WAIT <= 12'd2421;	//2422 MCLK
					end
					
					if ((H_CNT == 9'h109 && !H40) || (H_CNT == 9'h149 && H40)) begin
						if ((V_CNT == 9'h0DF && !V30) || (V_CNT == 9'h0EF && V30))
							HINT_EN <= 0;
						else if (V_CNT == 9'h1FE)
							HINT_EN <= 1;
					
						if (!HINT_EN) begin
							HINT_COUNT <= HIR.HIT;
						end else begin
							if (HINT_COUNT == 0) begin
								HINT_FLAG <= 1;
								HINT_COUNT <= HIR.HIT;
							end else begin
								HINT_COUNT <= HINT_COUNT - 8'd1;
							end
						end
					end
				end
				
				if (Z80_INT_WAIT == 0) begin
					if (Z80_INT_FLAG) Z80_INT_FLAG <= 0;
				end else begin
					Z80_INT_WAIT <= Z80_INT_WAIT - 12'd1;
				end
			end
		end
	end
	
	assign EDCLK = EDCLK_CE;
	assign VINT = VINT_FLAG & MR2.IE0;
	assign HINT = HINT_FLAG & MR1.IE1;
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			IPL_N <= 2'b11;
		end else begin
			if (ENABLE && VCLK_ENp) begin
				if (AS_N) begin
					if (VINT_FLAG && MR2.IE0)
						IPL_N <= 2'b00;
					else if (HINT_FLAG && MR1.IE1)
						IPL_N <= 2'b01;
//					else if (EXINT_FF)
//						IPL_N <= 2'b10;
					else
						IPL_N <= 2'b11;
				end
			end
		end
	end
	
	assign Z80_INT_N = ~Z80_INT_FLAG;
	
	
	//debug
	assign DBG_SLOT0_EXT     = SLOT_PIPE[0] == ST_EXT;
	assign DBG_SLOT1_EXT     = SLOT_PIPE[1] == ST_EXT;
	
	assign DBG_SLOT2_HSCROLL = SLOT_PIPE[2] == ST_HSCROLL;
	assign DBG_SLOT2_BGAMAP  = SLOT_PIPE[2] == ST_BGAMAP;
	assign DBG_SLOT2_BGACHAR = SLOT_PIPE[2] == ST_BGACHAR;
	assign DBG_SLOT2_BGBMAP  = SLOT_PIPE[2] == ST_BGBMAP;
	assign DBG_SLOT2_BGBCHAR = SLOT_PIPE[2] == ST_BGBCHAR;
	assign DBG_SLOT2_SPRMAP  = SLOT_PIPE[2] == ST_SPRMAP;
	assign DBG_SLOT2_SPRCHAR = SLOT_PIPE[2] == ST_SPRCHAR;
	assign DBG_SLOT2_EXT     = SLOT_PIPE[2] == ST_EXT;
	assign DBG_SLOT2_REFRESH = SLOT_PIPE[2] == ST_REFRESH;
	
	assign DBG_FIFO_ADDR = FIFO_ADDR;
	assign DBG_FIFO_DATA = FIFO_DATA;
	assign DBG_FIFO_CODE = FIFO_CODE;
	assign DBG_FIFO_EMPTY = FIFO_EMPTY;
	assign DBG_FIFO_FULL = FIFO_FULL;
	
endmodule
