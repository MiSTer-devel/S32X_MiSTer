module BA 
(
	input         CLK,
	input         RST_N,
	input         ENABLE,
	
	output [23:1] VA,
	input  [15:0] VDI,
	output [15:0] VDO,
	output        RNW,
	output        LDS_N,
	output        UDS_N,
	output        AS_N,
	input         DTACK_N,
	output        ASEL_N,
	output        VCLK_CE,
	output        CE0_N,
	output        LWR_N,
	output        UWR_N,
	output        CAS0_N,
	output        RAS2_N,
	output        CAS2_N,
	output        RAM_N,
	output        IO_N,
	output        ROM_N,
	output        FDC_N,
	input         CART_N,
	output        TIME_N,
	output        INTAK_N,
	output        VDP_N,
	
	output [15:0] ZA,
	input   [7:0] ZDI,
	output  [7:0] ZDO,
	output        ZWR_N,
	output        ZRD_N,
	output        ZRAM_N,
	output        YM_N,
	
	input         M68K_CLKENp,
	input         M68K_CLKENn,
	input  [23:1] M68K_A,
	output [15:0] M68K_DI,
	input  [15:0] M68K_DO,
	input         M68K_RNW,
	input         M68K_LDS_N,
	input         M68K_UDS_N,
	input         M68K_AS_N,
	output        M68K_DTACK_N,
	input   [1:0] M68K_FC,
	output        M68K_BR_N,
	input         M68K_BG_N,
	output        M68K_BGACK_N,
	
	input         Z80_CLKENp,
	input         Z80_CLKENn,
	input  [15:0] Z80_A,
	output  [7:0] Z80_DI,
	input   [7:0] Z80_DO,
	input         Z80_WR_N,
	input         Z80_RD_N,
	input         Z80_MREQ_N,
	input         Z80_M1_N,
	output reg    Z80_WAIT_N,
	//input         Z80_RFSH_N,
	output reg    Z80_BUSRQ_N,
	input         Z80_BUSAK_N,
	output reg    Z80_RESET_N,
	
	input  [23:1] VBUS_A,
	output [15:0] VBUS_D,
	input         VBUS_SEL,
	output        VBUS_DTACK_N,
	input         VBUS_BR_N,
	output        VBUS_BG_N,
	input         VBUS_BGACK_N,
	
	input         MEM_RDY,
	input         PAUSE_EN,
	
	output  [7:0] DBG_Z80_HOOK
);

	wire M68K_INTACK = &M68K_FC & ~M68K_AS_N;

	reg         M68K_MBUS_DTACK_N;
	reg         Z80_MBUS_DTACK_N;
	reg         VDP_MBUS_DTACK_N;
	
	reg  [15:0] M68K_MBUS_D;
	reg  [15:0] VDP_MBUS_D;
	
	reg         Z80_BR_N;
	reg         Z80_BGACK_N;
	reg         Z80_AS_N;
	
	reg  [23:1] MBUS_A;
	reg  [15:0] MBUS_DO;
	
	reg         MBUS_RNW;
	reg         MBUS_AS_N;
	reg         MBUS_UDS_N;
	reg         MBUS_LDS_N;
	wire [15:0] MBUS_DI;
	reg         MBUS_ASEL_N;
	
	reg  [15:0] OPEN_BUS;
	
	reg         CTRL_SEL;
	reg         IO_SEL;
	reg         RAM_SEL;
	reg         ZBUS_SEL;
	reg         FDC_SEL;
	reg         TIME_SEL;
	reg         VDP_SEL;
	
	reg   [3:0] mstate;
	reg   [1:0] msrc;
	
	localparam	MSRC_NONE = 0,
					MSRC_M68K = 1,
					MSRC_Z80  = 2,
					MSRC_VDP  = 3;
	
	localparam 	MBUS_IDLE         = 0,
					MBUS_SELECT       = 1,
					MBUS_RAM_WAIT     = 2,
					MBUS_RAM_READ     = 3,
					MBUS_RAM_WRITE    = 4,
					MBUS_ROM_READ     = 5,
					MBUS_VDP_READ     = 6,
					MBUS_IO_READ      = 7,
					MBUS_ROM_WAIT     = 8,
					MBUS_ZBUS_READ    = 9,
					MBUS_FDC_READ     = 10,
					MBUS_TIME_READ    = 11,
					MBUS_NOT_USED     = 12,
					MBUS_ROM_REFRESH  = 13,
					MBUS_RAM_REFRESH  = 14,
					MBUS_FINISH       = 15; 
	
	always @(posedge CLK) begin
		reg [7:0] rfs_rom_timer, rfs_ram_timer;
		reg rfs_ram_pend, rfs_rom_pend;
		reg [1:0] rfs_rom_delay, rfs_ram_delay;
		reg [1:0] zbus_delay;
		
		if (!RST_N) begin
			mstate <= MBUS_IDLE;
			M68K_MBUS_DTACK_N <= 1;
			Z80_MBUS_DTACK_N  <= 1;
			VDP_MBUS_DTACK_N  <= 1;
			MBUS_UDS_N <= 1;
			MBUS_LDS_N <= 1;
			MBUS_RNW <= 1;
			MBUS_AS_N <= 1;
			RAM_SEL <= 0;
			VDP_SEL <= 0;
			IO_SEL <= 0;
			CTRL_SEL <= 0;
			ZBUS_SEL <= 0;
			FDC_SEL <= 0;
			TIME_SEL <= 0;
			OPEN_BUS <= 'h4E71;
		end
		else if (ENABLE) begin
			if (M68K_CLKENp) begin
				rfs_rom_timer <= rfs_rom_timer + 8'd1;
				if (rfs_rom_timer == 8'd127) begin
					rfs_rom_timer <= 0;
					rfs_rom_pend <= 1;
				end
				else if (rfs_rom_timer == 8'd02) begin
					rfs_rom_pend <= 0;
				end
				
				rfs_ram_timer <= rfs_ram_timer + 8'd1;
				if (rfs_ram_timer == 8'd119) begin
					rfs_ram_pend <= 1;
				end
				else if (rfs_ram_timer == 8'd132) begin
					rfs_ram_timer <= 0;
					rfs_ram_pend <= 0;
					rfs_ram_delay <= 2'd3;
				end
				
				if (!VBUS_BGACK_N) begin
//					rfs_rom_timer <= 0;
					rfs_rom_pend <= 0;
//					rfs_ram_timer <= 0;
					rfs_ram_pend <= 0;
					rfs_ram_delay <= 2'd0;
				end
				
				if (rfs_rom_delay) rfs_rom_delay <= rfs_rom_delay - 2'd1;
				if (rfs_ram_delay) rfs_ram_delay <= rfs_ram_delay - 2'd1;
				if (zbus_delay) zbus_delay <= zbus_delay - 2'd1;
			end
	
			case(mstate)
			MBUS_IDLE:
				begin
				MBUS_AS_N <= 1; //Assume MBUS idle and update if activity exists
				if (!PAUSE_EN) begin
					msrc <= MSRC_NONE;
					if (!M68K_AS_N && (!M68K_LDS_N || !M68K_UDS_N) && M68K_MBUS_DTACK_N && !M68K_INTACK) begin
						msrc <= MSRC_M68K;
						MBUS_A <= M68K_A[23:1];
						MBUS_DO <= M68K_DO;
						MBUS_AS_N <= 0;
						MBUS_UDS_N <= M68K_UDS_N;
						MBUS_LDS_N <= M68K_LDS_N;
						MBUS_RNW <= M68K_RNW;
						MBUS_ASEL_N <= M68K_A[23];
						
						case (M68K_A[23:20])
							//CART: 000000-3FFFFF,400000-7FFFFF
							4'h0,4'h1,4'h2,4'h3,4'h4,4'h5,4'h6,4'h7: begin
								mstate <= MBUS_ROM_REFRESH;
								if (!rfs_rom_delay && rfs_rom_pend) rfs_rom_delay <= 2'd2;
								rfs_rom_pend <= 0;
								rfs_ram_pend <= 0;
							end
							
							//800000-9FFFFF (DTACK area)
							4'h8,4'h9: begin
								mstate <= MBUS_NOT_USED;
							end
							
							//A00000-BFFFFF
							4'hA,4'hB: begin
								//ZBUS: A00000-A07FFF/A08000-A0FFFF
								if (M68K_A[23:16] == 'hA0) begin
									if (!Z80_BUSRQ_N) begin
										ZBUS_SEL <= 1;
										zbus_delay <= 2'd2;
										mstate <= MBUS_ZBUS_READ;
									end else begin
										M68K_MBUS_DTACK_N <= 0;
										mstate <= MBUS_FINISH;
									end
								end
							
								//I/O: A10000-A1001F (+mirrors)
								else if (M68K_A[23:8] == 16'hA100) begin
									if (M68K_A[7:5] == 3'b000) begin
										IO_SEL <= 1;
										mstate <= MBUS_IO_READ;
									end else begin
										M68K_MBUS_DTACK_N <= 0;
										mstate <= MBUS_FINISH;
									end
								end
				
								//Memory mode: A11000
								else if (M68K_A[23:8] == 16'hA110) begin
									M68K_MBUS_DTACK_N <= 0;
									mstate <= MBUS_FINISH;
								end
				
								//CTRL: A11100, A11200
								else if (M68K_A[23:8] == 16'hA111 || M68K_A[23:8] == 16'hA112) begin
									CTRL_SEL <= 1;
									M68K_MBUS_DTACK_N <= 0;
									mstate <= MBUS_FINISH;
								end
				
								//Unknown: A11300
								else if (M68K_A[23:8] == 16'hA113) begin
									M68K_MBUS_DTACK_N <= 0;
									mstate <= MBUS_FINISH;
								end
				
								//FDC: A120XX
								else if (M68K_A[23:8] == 16'hA120) begin
									FDC_SEL <= 1;
									mstate <= MBUS_FDC_READ;
								end
				
								//TIME: A130XX
								else if (M68K_A[23:8] == 16'hA130) begin
									TIME_SEL <= 1;
									mstate <= MBUS_TIME_READ;
								end
							
								//TMSS: A140XX
								else if (M68K_A[23:8] == 16'hA140) begin
									M68K_MBUS_DTACK_N <= 0;
									mstate <= MBUS_FINISH;
								end
								
								else begin
									mstate <= MBUS_NOT_USED;
								end
							end
							
							//C00000-DFFFFF
							4'hC,4'hD: begin
								//VDP: C00000-C0001F (+mirrors)
								if (M68K_A[23:21] == 3'b110 && !M68K_A[18:16] && !M68K_A[7:5]) begin
									VDP_SEL <= 1;
//									if (!M68K_A[4] && !M68K_RNW) begin rfs_rom_pend <= 0; rfs_rom_timer <= '0; rfs_rom_delay <= 2'd0; end
//									if (!M68K_A[4] && !M68K_RNW) begin rfs_ram_pend <= 0; rfs_ram_timer <= '0; rfs_ram_delay <= 2'd0; end
									mstate <= MBUS_VDP_READ;
								end
								
								else begin
									mstate <= MBUS_NOT_USED;
								end
							end
							
							//RAM: E00000-FFFFFF
							4'hE,4'hF: begin
								RAM_SEL <= 1;
								mstate <= MBUS_RAM_REFRESH;
								if (!rfs_ram_delay && rfs_ram_pend) rfs_ram_delay <= 2'd3;
								rfs_ram_pend <= 0;
							end
							
							default:;
						endcase
					end
					else if (VBUS_SEL && VDP_MBUS_DTACK_N) begin
						msrc <= MSRC_VDP;
						MBUS_A <= VBUS_A;
						//MBUS_DO <= 0;
						MBUS_AS_N <= 0;
						MBUS_UDS_N <= 0;
						MBUS_LDS_N <= 0;
						MBUS_RNW <= 1;
						MBUS_ASEL_N <= VBUS_A[23];
						
						case (VBUS_A[23:20])
							//CART: 000000-3FFFFF,400000-7FFFFF
							4'h0,4'h1,4'h2,4'h3,4'h4,4'h5,4'h6,4'h7: begin
								mstate <= MBUS_ROM_REFRESH;
								if (!rfs_rom_delay && rfs_rom_pend) rfs_rom_delay <= 2'd2;
								rfs_rom_pend <= 0;
							end
							
							//800000-9FFFFF (DTACK area)
							4'h8,4'h9: begin
								mstate <= MBUS_NOT_USED;
							end
							
							//A00000-DFFFFF
							4'hA,4'hB,4'hC,4'hD: begin
								VDP_MBUS_DTACK_N <= 0;
								mstate <= MBUS_FINISH;
							end
							
							//RAM: E00000-FFFFFF
							4'hE,4'hF: begin
								RAM_SEL <= 1;
								mstate <= MBUS_RAM_READ;
							end
							
							default:;
						endcase
					end
					else if (Z80_IO && !Z80_ZBUS_AREA && Z80_MBUS_DTACK_N && !Z80_AS_N) begin
//					else if (Z80_IO && !Z80_ZBUS_AREA && Z80_MBUS_DTACK_N && !Z80_BGACK_N && Z80_BR_N) begin
						msrc <= MSRC_Z80;
						MBUS_A <= Z80_A[15] ? {BAR[23:15],Z80_A[14:1]} : {16'hC000, Z80_A[7:1]};
						MBUS_DO <= {Z80_DO,Z80_DO};
						MBUS_AS_N <= 0;
						MBUS_UDS_N <= Z80_A[0];
						MBUS_LDS_N <= ~Z80_A[0];
						MBUS_RNW <= Z80_WR_N;
						MBUS_ASEL_N <= Z80_A[15] ? BAR[23] : 1'b1;
						
						if (Z80_A[15]) begin
							case (BAR[23:20])
								//CART: 000000-3FFFFF,400000-7FFFFF
								4'h0,4'h1,4'h2,4'h3,4'h4,4'h5,4'h6,4'h7: begin
									mstate <= MBUS_ROM_READ;
									if (!rfs_rom_delay && rfs_rom_pend) rfs_rom_delay <= 2'd2;
									rfs_rom_pend <= 0;
								end
								
								//800000-9FFFFF
								4'h8,4'h9: begin
									mstate <= MBUS_NOT_USED;
								end
								
								//A00000-BFFFFF
								4'hA,4'hB: begin
									mstate <= MBUS_NOT_USED;
								end
								
								//C00000-DFFFFF
								4'hC,4'hD: begin
									//VDP: C00000-C0001F (+mirrors)
									if (BAR[23:21] == 3'b110 && !BAR[18:16] && !Z80_A[7:5]) begin
										VDP_SEL <= 1;
	//									if (rfs_rom_pend && !Z80_WR_N) rfs_rom_pend <= 0;
	//									if (rfs_ram_pend && !Z80_WR_N) rfs_ram_pend <= 0;
										mstate <= MBUS_VDP_READ;
									end
									
									else begin
										mstate <= MBUS_NOT_USED;
									end
								end
								
								//RAM: E00000-FFFFFF
								4'hE,4'hF: begin
									RAM_SEL <= 1;
									mstate <= MBUS_RAM_REFRESH;
									if (!rfs_ram_delay && rfs_ram_pend) rfs_ram_delay <= 2'd3;
									rfs_ram_pend <= 0;
								end
								
								default:;
							endcase
						end 
						
						//VDP: C00000-C000FF (+mirrors)
						else if (Z80_A[15:8] == 8'h7F) begin
							VDP_SEL <= 1;
	//						if (rfs_rom_pend && !Z80_WR_N) rfs_rom_pend <= 0;
	//						if (rfs_ram_pend && !Z80_WR_N) rfs_ram_pend <= 0;
							mstate <= MBUS_VDP_READ;
						end
					end
				end
				end
	
			MBUS_ZBUS_READ:
				if (!zbus_delay && !MBUS_ZBUS_DTACK_N && M68K_CLKENp) begin
					M68K_MBUS_DTACK_N <= 0;
					mstate <= MBUS_FINISH;
				end
			
			MBUS_RAM_WAIT: begin
					mstate <= rfs_ram_pend ? MBUS_RAM_REFRESH : MBUS_RAM_READ;
					if (rfs_ram_pend) rfs_ram_pend <= 0;
				end
	
			MBUS_RAM_REFRESH: begin
					if (!rfs_ram_delay && M68K_CLKENp) begin
						mstate <= MBUS_RAM_READ;
					end
				end
				
			MBUS_RAM_READ: begin
					M68K_MBUS_DTACK_N <= ~(msrc == MSRC_M68K);
					VDP_MBUS_DTACK_N <= ~(msrc == MSRC_VDP);
					Z80_MBUS_DTACK_N <= ~(msrc == MSRC_Z80);
					if (msrc == MSRC_M68K && MBUS_RNW) OPEN_BUS <= VDI;
					mstate <= MBUS_FINISH;
				end
				
			MBUS_ROM_WAIT: begin
				mstate <= rfs_rom_pend ? MBUS_ROM_REFRESH : MBUS_ROM_READ;
				if (rfs_rom_pend) rfs_rom_pend <= 0;
			end
			
			MBUS_ROM_REFRESH: begin
				if (!rfs_rom_delay && M68K_CLKENp) begin
					mstate <= MBUS_ROM_READ;
				end
			end
			
			MBUS_ROM_READ: begin
				if (MEM_RDY || !DTACK_N) begin
					M68K_MBUS_DTACK_N <= ~(msrc == MSRC_M68K);
					VDP_MBUS_DTACK_N <= ~(msrc == MSRC_VDP);
					Z80_MBUS_DTACK_N <= ~(msrc == MSRC_Z80);
					mstate <= MBUS_FINISH;
				end
			end
				
			MBUS_VDP_READ:
				if (!DTACK_N) begin
					M68K_MBUS_DTACK_N <= ~(msrc == MSRC_M68K);
					Z80_MBUS_DTACK_N <= ~(msrc == MSRC_Z80);
					mstate <= MBUS_FINISH;
				end
	
			MBUS_IO_READ:
				if (!DTACK_N) begin
					M68K_MBUS_DTACK_N <= ~(msrc == MSRC_M68K);
					Z80_MBUS_DTACK_N <= ~(msrc == MSRC_Z80);
					mstate <= MBUS_FINISH;
				end
				
			MBUS_FDC_READ:
				begin
					M68K_MBUS_DTACK_N <= ~(msrc == MSRC_M68K);
					VDP_MBUS_DTACK_N <= ~(msrc == MSRC_VDP);
					Z80_MBUS_DTACK_N <= ~(msrc == MSRC_Z80);
					mstate <= MBUS_FINISH;
				end
				
			MBUS_TIME_READ:
				begin
					M68K_MBUS_DTACK_N <= ~(msrc == MSRC_M68K);
					VDP_MBUS_DTACK_N <= ~(msrc == MSRC_VDP);
					Z80_MBUS_DTACK_N <= ~(msrc == MSRC_Z80);
					mstate <= MBUS_FINISH;
				end
	
			MBUS_NOT_USED: begin
					if (!DTACK_N) begin
						M68K_MBUS_DTACK_N <= ~(msrc == MSRC_M68K);
						VDP_MBUS_DTACK_N <= ~(msrc == MSRC_VDP);
						Z80_MBUS_DTACK_N <= ~(msrc == MSRC_Z80);
						mstate <= MBUS_FINISH;
					end
				end
				
			MBUS_FINISH:
				begin
					if ((M68K_AS_N && !M68K_MBUS_DTACK_N && msrc == MSRC_M68K) ||
						 (!Z80_IO && !Z80_MBUS_DTACK_N && msrc == MSRC_Z80) ||
						 (!VBUS_SEL && !VDP_MBUS_DTACK_N && msrc == MSRC_VDP)) begin
						 if (msrc == MSRC_VDP) MBUS_DO <= MBUS_DI;
						M68K_MBUS_DTACK_N <= 1;
						VDP_MBUS_DTACK_N <= 1;
						Z80_MBUS_DTACK_N <= 1;
						MBUS_AS_N <= 1;
						MBUS_UDS_N <= 1;
						MBUS_LDS_N <= 1;
						MBUS_RNW <= 1;
						MBUS_ASEL_N <= 1;
						RAM_SEL <= 0;
						VDP_SEL <= 0;
						ZBUS_SEL <= 0;
						CTRL_SEL <= 0;
						IO_SEL <= 0;
						FDC_SEL <= 0;
						TIME_SEL <= 0;
						mstate <= MBUS_IDLE;
						if (msrc == MSRC_M68K) begin
							OPEN_BUS <= MBUS_DI;
						end
					end
					MBUS_AS_N <= 1; //Always return execution to SH on finish.
				end
			endcase;
		end
	end
	
	assign MBUS_DI = VDP_SEL ? (MBUS_A[4:2] == 3'b001 ? {OPEN_BUS[15:10],VDI[9:0]} : VDI) :
	                 ZBUS_SEL ? (!Z80_BUSRQ_N ? {MBUS_ZBUS_D, MBUS_ZBUS_D} : OPEN_BUS) :
						  CTRL_SEL ? CTRL_DO :
						  VDI;
	
	assign VA      = MBUS_A;
	assign VDO     = MBUS_DO;
	assign RNW     = MBUS_RNW;
	assign LDS_N   = MBUS_LDS_N;
	assign UDS_N   = MBUS_UDS_N;
	assign AS_N    = MBUS_AS_N;
	assign ASEL_N  = MBUS_ASEL_N;										//000000-7FFFFF
	assign IO_N    = ~IO_SEL;											//A10000-A1001F
	assign TIME_N  = ~TIME_SEL;										//A13000-A130FF
	assign FDC_N   = ~FDC_SEL;											//A12000-A120FF 
	assign RAM_N   = ~RAM_SEL;
	assign VDP_N   = ~VDP_SEL;
	assign VCLK_CE = M68K_CLKENn;
	assign INTAK_N = ~M68K_INTACK;
	
	assign CE0_N  = ~(MBUS_A[23:22] == {1'b0, CART_N     });	//000000-3FFFFF /CART=0 or 400000-7FFFFF /CART=1
	assign ROM_N  = ~(MBUS_A[23:21] == {1'b0,~CART_N,1'b0});	//400000-5FFFFF /CART=0 or 000000-1FFFFF /CART=1
	assign RAS2_N = ~(MBUS_A[23:21] == {1'b0,~CART_N,1'b1});	//600000-7FFFFF /CART=0 or 200000-3FFFFF /CART=1
	assign CAS2_N = ~MBUS_RNW | MBUS_AS_N;							//000000-FFFFFF 
	assign CAS0_N = ~MBUS_RNW | MBUS_AS_N;							//000000-FFFFFF 
	assign LWR_N  =  MBUS_RNW | MBUS_LDS_N;						//000000-FFFFFF 
	assign UWR_N  =  MBUS_RNW | MBUS_UDS_N;						//000000-FFFFFF 
	
	assign M68K_DI = MBUS_DI;
	assign M68K_DTACK_N = M68K_MBUS_DTACK_N;
	assign M68K_BR_N = VBUS_BR_N & Z80_BR_N;
	assign M68K_BGACK_N = VBUS_BGACK_N & Z80_BGACK_N;
	
	assign VBUS_D = MBUS_DI;
	assign VBUS_DTACK_N = VDP_MBUS_DTACK_N;
	assign VBUS_BG_N = M68K_BG_N;
	
	//Z80
	wire        CTRL_F  = (MBUS_A[11:8] == 1) ? Z80_BUSAK_N : (MBUS_A[11:8] == 2) ? Z80_RESET_N : OPEN_BUS[8];
	wire [15:0] CTRL_DO = {OPEN_BUS[15:9], CTRL_F, OPEN_BUS[7:0]};
	always @(posedge CLK) begin
		if (!RST_N) begin
			Z80_BUSRQ_N <= 1;
			Z80_RESET_N <= 0;
		end
		else if (ENABLE) begin
			if (CTRL_SEL & ~MBUS_RNW & ~MBUS_UDS_N) begin
				if (MBUS_A[11:8] == 1) Z80_BUSRQ_N <= ~MBUS_DO[8];
				if (MBUS_A[11:8] == 2) Z80_RESET_N <=  MBUS_DO[8];
			end
		end
	end

	// Z80:   0000-7EFF
	// 68000: A00000-A07FFF (A08000-A0FFFF)
	reg  [14:0] ZBUS_A;
	reg   [7:0] ZBUS_DO;
	reg         ZBUS_WE;
	reg         ZBUS_RD;
	
	reg   [7:0] MBUS_ZBUS_D;
	reg         MBUS_ZBUS_DTACK_N;
	
	reg   [7:0] Z80_ZBUS_D;
	reg         Z80_ZBUS_DTACK_N;
	
	wire        Z80_IO = ~Z80_MREQ_N & (~Z80_RD_N | ~Z80_WR_N);
	wire        Z80_ZBUS_AREA = ~Z80_A[15] && ~&Z80_A[14:8];
	wire        Z80_ZBUS_SEL = Z80_ZBUS_AREA & Z80_IO;
	wire        ZBUS_FREE = ~Z80_BUSRQ_N & Z80_RESET_N;
	
	wire        Z80_MBUS_SEL = ~Z80_MREQ_N & ~Z80_ZBUS_AREA;
//	wire        Z80_MBUS_SEL = Z80_IO & ~Z80_ZBUS_AREA;
	wire  [7:0] Z80_MBUS_D = Z80_A[0] ? MBUS_DI[7:0] : MBUS_DI[15:8];
	
	always @(posedge CLK) begin
		reg [2:0] zstate, zstate2;
		reg Z80_BGACK_DIS, Z80_BGACK_DIS2;
		reg Z80_WAIT_DELAY, Z80_AS_DELAY;
	
		localparam	ZBUS_IDLE        = 0,
						ZBUS_M68K_ACCESS = 1,
						ZBUS_Z80_ACCESS  = 2,
						ZBUS_M68K_FINISH = 3,
						ZBUS_Z80_FINISH  = 4;
	
		ZBUS_WE <= 0;
		ZBUS_RD <= 0;
		
		if (!RST_N) begin
			zstate <= ZBUS_IDLE;
			MBUS_ZBUS_DTACK_N <= 1;
			Z80_ZBUS_DTACK_N  <= 1;
			
			zstate2 <= 0;
			Z80_BR_N <= 1;
			Z80_BGACK_N <= 1;
			Z80_AS_N <= 1;
			Z80_WAIT_N <= 1;
			Z80_BGACK_DIS <= 0;
			Z80_BGACK_DIS2 <= 0;
			Z80_AS_DELAY <= 0;
			Z80_WAIT_DELAY <= 0;
			
			DBG_Z80_HOOK <= 8'd255;
		end
		else if (ENABLE) begin
			if (~ZBUS_SEL)     MBUS_ZBUS_DTACK_N <= 1;
			if (~Z80_ZBUS_SEL) Z80_ZBUS_DTACK_N  <= 1;
	
			case (zstate)
				ZBUS_IDLE:
					if (ZBUS_SEL & MBUS_ZBUS_DTACK_N) begin
						ZBUS_A <= {MBUS_A[14:1], MBUS_UDS_N};
						ZBUS_DO <= (~MBUS_UDS_N) ? MBUS_DO[15:8] : MBUS_DO[7:0];
						ZBUS_WE <= ~MBUS_RNW & ZBUS_FREE;
						ZBUS_RD <= MBUS_RNW & ZBUS_FREE;
						zstate <= ZBUS_M68K_ACCESS;
					end
					else if (Z80_ZBUS_SEL & Z80_ZBUS_DTACK_N) begin
						ZBUS_A <= Z80_A[14:0];
						ZBUS_DO <= Z80_DO;
						ZBUS_WE <= ~Z80_WR_N;
						ZBUS_RD <= ~Z80_RD_N;
						zstate <= ZBUS_Z80_ACCESS;
					end
		
				ZBUS_M68K_ACCESS:
					zstate <= ZBUS_M68K_FINISH;
		
				ZBUS_Z80_ACCESS:
					zstate <= ZBUS_Z80_FINISH;
		
				ZBUS_M68K_FINISH: begin
					MBUS_ZBUS_D <= ZBUS_FREE ? ZDI : 8'hFF;
					MBUS_ZBUS_DTACK_N <= 0;
					zstate <= ZBUS_IDLE;
				end
		
				ZBUS_Z80_FINISH: begin
					Z80_ZBUS_D <= ZDI;
					Z80_ZBUS_DTACK_N <= 0;
					zstate <= ZBUS_IDLE;
				end
			endcase
			
			if (DBG_Z80_HOOK < 254) DBG_Z80_HOOK <= DBG_Z80_HOOK + 1'd1;
			case (zstate2)
				0: if (Z80_MBUS_SEL && Z80_BR_N && Z80_BGACK_N && VBUS_BR_N && VBUS_BGACK_N && M68K_CLKENp) begin
					Z80_BR_N <= 0;
					zstate2 <= zstate2 + 3'd1;
				end
				
				1: if (!M68K_BG_N && VBUS_BR_N && VBUS_BGACK_N && M68K_AS_N && M68K_CLKENn) begin
					Z80_BGACK_N <= 0;
					DBG_Z80_HOOK <= 8'd0;
					zstate2 <= zstate2 + 3'd1;
				end
				
				2: if (!M68K_BG_N && M68K_CLKENp) begin
					Z80_BR_N <= 1;
					zstate2 <= zstate2 + 3'd1;
				end
				
				3: if (M68K_CLKENp) begin
					Z80_AS_N <= 0;
					zstate2 <= zstate2 + 3'd1;
				end
				
				4: if (!Z80_MBUS_SEL && M68K_CLKENp) begin
					zstate2 <= 5;
				end
				
				5: if (M68K_CLKENp) begin
					Z80_AS_N <= 1;
					zstate2 <= 7;
				end
				
				6: if (M68K_CLKENp)begin
					Z80_AS_N <= 1;
					zstate2 <= 7;
				end
				
				7: if (M68K_CLKENp) begin
					Z80_BGACK_N <= 1;
					DBG_Z80_HOOK <= 8'd255;
					zstate2 <= 0;
				end
			endcase
			
	//		
	//		if (Z80_MBUS_SEL && Z80_BR_N && Z80_BGACK_N && VBUS_BR_N && VBUS_BGACK_N && M68K_CLKENp) begin
	//			Z80_BR_N <= 0;
	//		end
	//		else if (!Z80_BR_N && !M68K_BG_N && VBUS_BR_N && VBUS_BGACK_N && M68K_AS_N && M68K_CLKENn) begin
	//			Z80_BGACK_N <= 0;
	//			DBG_Z80_HOOK <= 8'd0;
	//		end
	//		else if (!Z80_BGACK_N && !Z80_BR_N && Z80_AS_N && !M68K_BG_N && M68K_CLKENp) begin
	//			Z80_BR_N <= 1;
	//		end
	//		else if (!Z80_BGACK_N && Z80_BR_N && Z80_AS_N && M68K_CLKENp) begin
	//			Z80_AS_N <= 0;
	//		end
	//		else if (!Z80_MBUS_SEL && !Z80_BGACK_N && Z80_BR_N && !Z80_AS_N && M68K_CLKENp) begin
	//			Z80_AS_DELAY <= ~Z80_AS_DELAY;
	//			if (Z80_AS_DELAY) begin
	//				Z80_AS_N <= 1;
	//			end
	//		end
	//		else if (!Z80_BGACK_N && Z80_BR_N && Z80_AS_N && !Z80_MBUS_SEL && M68K_CLKENp) begin
	//			Z80_BGACK_N <= 1;
	//			DBG_Z80_HOOK <= 8'd255;
	//		end
			
			if (Z80_MBUS_SEL && Z80_MBUS_DTACK_N && Z80_BGACK_N && Z80_WAIT_N) begin
				Z80_WAIT_N <= 0;
			end
			else if (!Z80_BGACK_N && !Z80_AS_N && !Z80_WAIT_N && !Z80_WAIT_DELAY && M68K_CLKENp) begin
				Z80_WAIT_DELAY <= 1;
			end
			else if (!Z80_BGACK_N && !Z80_WAIT_N && Z80_WAIT_DELAY && M68K_CLKENp) begin
				Z80_WAIT_N <= 1;
				Z80_WAIT_DELAY <= 0;
			end
			
//			if (Z80_MBUS_SEL && Z80_BR_N && Z80_BGACK_N && VBUS_BR_N && VBUS_BGACK_N && M68K_CLKENp) begin
//				Z80_BR_N <= 0;
//			end
//			else if (!Z80_BR_N && !M68K_BG_N && VBUS_BR_N && VBUS_BGACK_N && M68K_AS_N && M68K_CLKENn) begin
//				Z80_BGACK_N <= 0;
//			end
//			else if (!Z80_BGACK_N && !Z80_BR_N && !M68K_BG_N && M68K_CLKENp) begin
//				Z80_BR_N <= 1;
//			end
//			else if (!Z80_BGACK_DIS2 && !Z80_BGACK_N && Z80_BR_N && !Z80_MBUS_SEL && M68K_CLKENn) begin
//				Z80_BGACK_DIS <= 1;
//				Z80_BGACK_DIS2 <= Z80_BGACK_DIS;
//			end
//			else if (!Z80_BGACK_N && Z80_BGACK_DIS2 && M68K_CLKENn) begin
//				Z80_BGACK_N <= 1;
//				Z80_BGACK_DIS <= 0;
//				Z80_BGACK_DIS2 <= 0;
//			end
	
			
		end
	end
	
	// RAM 0000-1FFF (2000-3FFF)
	wire ZRAM_SEL = ~ZBUS_A[14];
	
	// Z80 BANK REGISTER
	// 6000-60FF
	wire BANK_SEL = ZBUS_A[14:8] == 7'h60;
	reg [23:15] BAR;
	always @(posedge CLK) begin
		if (!RST_N) BAR <= 0;
		else if (BANK_SEL & ZBUS_WE) BAR <= {ZBUS_DO[0], BAR[23:16]};
	end
	
	// YM2612
	// 4000-4003 (4000-5FFF)
	wire YM_SEL = ZBUS_A[14:13] == 2'b10;
	
	assign Z80_DI = !Z80_ZBUS_DTACK_N ? Z80_ZBUS_D : Z80_MBUS_D;
//	assign Z80_WAIT_N = ~Z80_MBUS_DTACK_N | ~Z80_ZBUS_DTACK_N | ~Z80_IO;
	
	assign ZA = ZBUS_A;
	assign ZDO = ZBUS_DO;
	assign ZWR_N = ~ZBUS_WE;
	assign ZRD_N = ~ZBUS_RD;
	assign ZRAM_N = ~ZRAM_SEL;
	assign YM_N = ~YM_SEL;

endmodule
