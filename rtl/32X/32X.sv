module S32X 
#(parameter bit USE_ROM_WAIT=0, bit USE_ASYNC_FB=1)
(
	input             CLK,
	input             RST_N,
	
	input             VCLK,
	input      [23:1] VA,
	input      [15:0] VDI,
	output     [15:0] VDO,
	input             AS_N,
	output            DTACK_N,
	input             LWR_N,
	input             UWR_N,
	input             CE0_N,
	input             CAS0_N,
	input             CAS2_N,
	input             ASEL_N,
	input             VRES_N,
	input             MRES_N,
	input             CART_N,
	
	input             EDCLK,
	input             VSYNC_N,
	input             HSYNC_N,
	input             YS_N,
	input             PAL,
	
	output     [23:1] CA,
	input      [15:0] CDI,
	output     [15:0] CDO,
	output            CASEL_N,
	output            CLWR_N,
	output            CUWR_N,
	output            CCE0_N,
	output            CCAS0_N,
	output            CCAS2_N,
	
	input             ROM_WAIT,
	
	output     [17:1] SDR_A,
	input      [15:0] SDR_DI,
	output     [15:0] SDR_DO,
	output            SDR_CS,
	output      [1:0] SDR_WE,
	output            SDR_RD,
	input             SDR_WAIT,
	
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
	output            YSO_N,
	
	output     [15:0] PWM_L,
	output     [15:0] PWM_R,
	
	output     [23:0] DBG_CA
);
	import S32X_PKG::*;

	bit CE_R, CE_F;
	// The SH2 clock ticks 3 full times for each VCLK
	always @(posedge CLK) begin
		bit [2:0] CLK_CNT = 3'b111;
		if (~&CLK_CNT)
			CLK_CNT <= CLK_CNT + 1'd1;

		CE_F <= 0;
		CE_R <= 0;
	
		if (VCLK) begin
			CLK_CNT <= 1;
			CE_F <= 1;
		end

		case (CLK_CNT)
			3'd0: CE_F <= 1;
			3'd1: CE_R <= 1;
			3'd2: CE_F <= 1;
			3'd3: CE_R <= 1;
			3'd4: CE_F <= 1;
			3'd5: CE_R <= 1;
			default:;
		endcase

		if (~RST_N)
			CLK_CNT <= 3'b111;
	end

	bit  [26:0] SHA;
	bit  [31:0] SHDO;
	bit  [31:0] SHDI;
	bit         SHBS_N;
	bit         SHCS0M_N;
	bit         SHCS1_N;
	bit         SHCS2_N;
	bit         SHCS3_N;
	bit         SHRD_WR_N;
	bit   [3:0] SHDQM_N;
	bit         SHRD_N;
	bit   [3:1] SHMIRL_N;
	bit         SHMFTOA;
	
	bit  [26:0] SHSA;
	bit  [31:0] SHSDO;
	bit  [31:0] SHSDI;
	bit         SHSBS_N;
	bit         SHCS0S_N;
	bit         SHSCS1_N;
	bit         SHSCS2_N;
	bit         SHSCS3_N;
	bit         SHSRD_WR_N;
	bit   [3:0] SHSDQM_N;
	bit         SHSRD_N;
	bit   [3:1] SHSIRL_N;
	bit         SHSFTOA;
	
	bit         SHRES_N;
	bit         SHWAIT_N;
	bit         SHBREQ_N;
	bit         SHBACK_N;
	bit         SHDREQ0_N;
	bit         SHDREQ1_N;
	bit         TXDM;
	bit         TXDS;
	bit         SCKM;
	bit         SCKS;
	SH7604 #(.BUS_AREA_TIMIMG(4'b1000), .BUS_SIZE_BYTE_DISABLE(1)) MSH
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		.EN(1),
		
		.RES_N(SHRES_N),
		.NMI_N(1'b1),
		
		.IRL_N({SHMIRL_N,1'b1/*SHMFTOA*/}),
		
		.A(SHA),
		.DI(SHDI),
		.DO(SHDO),
		.BS_N(SHBS_N),
		.CS0_N(SHCS0M_N),
		.CS1_N(SHCS1_N),
		.CS2_N(SHCS2_N),
		.CS3_N(SHCS3_N),
		.RD_WR_N(SHRD_WR_N),
		.WE_N(SHDQM_N),
		.RD_N(SHRD_N),
		
		.EA(SHSA),
		.EDI(SHSDI),
		.EDO(SHSDO),
		.EBS_N(SHSBS_N),
		.ECS0_N(1'b1),
		.ECS1_N(SHSCS1_N),
		.ECS2_N(SHSCS2_N),
		.ECS3_N(SHSCS3_N),
		.ERD_WR_N(SHSRD_WR_N),
		.EWE_N(SHSDQM_N),
		.ERD_N(SHSRD_N),
		
		.WAIT_N(SHWAIT_N),
		.BRLS_N(SHBREQ_N),
		.BGR_N(SHBACK_N),
		
		.DREQ0(SHDREQ0_N),
		.DREQ1(SHDREQ1_N),
		
		.RXD(TXDS),
		.TXD(TXDM),
		.SCKO(SCKM),
		.SCKI(SCKS),
		
		.FTOA(SHMFTOA),
		
		.MD(6'b001000),
		
		.FAST(0)
	);
	
	SH7604 #(.BUS_AREA_TIMIMG(4'b1000), .BUS_SIZE_BYTE_DISABLE(1)) SSH
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		.EN(1),
		
		.RES_N(SHRES_N),
		.NMI_N(1'b1),
		
		.IRL_N({SHSIRL_N,1'b1/*SHSFTOA*/}),
		
		.A(SHSA),
		.DI(SHSDI),
		.DO(SHSDO),
		.BS_N(SHSBS_N),
		.CS0_N(SHCS0S_N),
		.CS1_N(SHSCS1_N),
		.CS2_N(SHSCS2_N),
		.CS3_N(SHSCS3_N),
		.RD_WR_N(SHSRD_WR_N),
		.WE_N(SHSDQM_N),
		.RD_N(SHSRD_N),
		
		.EA('0),
		.EDI(),
		.EDO('0),
		.EBS_N(1'b1),
		.ECS0_N(1'b1),
		.ECS1_N(1'b1),
		.ECS2_N(1'b1),
		.ECS3_N(1'b1),
		.ERD_WR_N(1'b1),
		.EWE_N(4'b1111),
		.ERD_N(1'b1),
		
		.WAIT_N(SHWAIT_N),
		.BRLS_N(SHBACK_N),
		.BGR_N(SHBREQ_N),
		
		.DREQ0(SHDREQ0_N),
		.DREQ1(SHDREQ1_N),
		
		.RXD(TXDM),
		.TXD(TXDS),
		.SCKO(SCKS),
		.SCKI(SCKM),
		
		.FTOA(SHSFTOA),
		
		.MD(6'b101000),
		
		.FAST(0)
	);
	
	
	bit [ 15:0] IF_DO;
	bit         IF_WAIT_N;
	bit [21:19] IF_OVA;
	bit         IF_SEL;
	
	bit  [17:1] VDP_A;
	bit  [15:0] VDP_DI;
	bit  [15:0] VDP_DO;
	bit         VDP_RD_N;
	bit         VDP_LWR_N;
	bit         VDP_UWR_N;
	bit         VDP_ACK_N;
	bit         VDP_DRAM_CS_N;
	bit         VDP_REG_CS_N;
	bit         VDP_PAL_CS_N;
	bit         VDP_VINT;
	bit         VDP_HINT;
	S32X_IF #(USE_ROM_WAIT) s32x_if
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),

		.VCLK(CE_R),
		.VA(VA),
		.VDI(VDI),
		.VDO(VDO),
		.AS_N(AS_N),
		.DTACK_N(DTACK_N),
		.LWR_N(LWR_N),
		.UWR_N(UWR_N),
		.CE0_N(CE0_N),
		.CAS0_N(CAS0_N),
		.CAS2_N(CAS2_N),
		.ASEL_N(ASEL_N),
		.VRES_N(VRES_N),
		.MRES_N(MRES_N),
		.CART_N(CART_N),
	
		.SHA(SHA[17:1]),
		.SHDI(SHDO[15:0]),
		.SHDO(IF_DO),
		.SHCS0M_N(SHCS0M_N),
		.SHCS0S_N(SHCS0S_N),
		.SHCS1_N(SHCS1_N),
		.SHCS2_N(SHCS2_N),
		.SHBS_N(SHBS_N),
		.SHRD_WR_N(SHRD_WR_N),
		.SHRD_N(SHRD_N),
		.SHDQMLL_N(SHDQM_N[0]),
		.SHDQMLU_N(SHDQM_N[1]),
		.SHWAIT_N(IF_WAIT_N),
		.SHRES_N(SHRES_N),
		.SHDREQ0_N(SHDREQ0_N),
		.SHDREQ1_N(SHDREQ1_N),
		.SHMIRL_N(SHMIRL_N),
		.SHSIRL_N(SHSIRL_N),
		
		.OVA(IF_OVA),
		.SEL(IF_SEL),
	
		.CDI(CDI),
		.CDO(CDO),
		.CASEL_N(CASEL_N),
		.CLWR_N(CLWR_N),
		.CUWR_N(CUWR_N),
		.CCE0_N(CCE0_N),
		.CCAS0_N(CCAS0_N),
		.CCAS2_N(CCAS2_N),
		
		.VDP_A(VDP_A),
		.VDP_DI(VDP_DI),
		.VDP_DO(VDP_DO),
		.VDP_RD_N(VDP_RD_N),
		.VDP_LWR_N(VDP_LWR_N),
		.VDP_UWR_N(VDP_UWR_N),
		.VDP_ACK_N(VDP_ACK_N),
		.VDP_DRAM_CS_N(VDP_DRAM_CS_N),
		.VDP_REG_CS_N(VDP_REG_CS_N),
		.VDP_PAL_CS_N(VDP_PAL_CS_N),
//		.VDP_RW(),
//		.VDP_DIR(),
//		.VDP_ACCS(),
//		.VDP_VACK(1'b0),
		.VDP_VINT(VDP_VINT),
		.VDP_HINT(VDP_HINT),
//		.VDP_C23(),

		.PWM_L(PWM_L),
		.PWM_R(PWM_R),
		
		.ROM_WAIT(ROM_WAIT)
	);
	
	assign CA = IF_SEL ? {2'b00,SHA[21:1]} : {VA[23:22],IF_OVA,VA[18:1]};
	
	assign SDR_A = SHA[17:1];
	assign SDR_DO = SHDO[15:0];
	assign SDR_CS = ~SHCS3_N;
	assign SDR_WE = ~SHDQM_N[1:0];
	assign SDR_RD = ~SHRD_N;
	
	assign SHDI = !SHCS3_N ? {16'h0000,SDR_DI} : {16'h0000,IF_DO};
	assign SHWAIT_N = IF_WAIT_N & ~SDR_WAIT;

	
	S32X_VDP #(USE_ASYNC_FB) S32X_VDP
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),

		.MRES_N(MRES_N),
		
		.EDCLK(EDCLK),
		.VSYNC_N(VSYNC_N),
		.HSYNC_N(HSYNC_N),
		.YS_N(YS_N),
		.PAL(PAL),
	
		.A(VDP_A),
		.DI(VDP_DO),
		.DO(VDP_DI),
		.RD_N(VDP_RD_N),
		.LWR_N(VDP_LWR_N),
		.UWR_N(VDP_UWR_N),
		.ACK_N(VDP_ACK_N),
		.DRAM_CS_N(VDP_DRAM_CS_N),
		.REG_CS_N(VDP_REG_CS_N),
		.PAL_CS_N(VDP_PAL_CS_N),
		
		.VINT(VDP_VINT),
		.HINT(VDP_HINT),
		
		.FB0_A(FB0_A),
		.FB0_DI(FB0_DI),
		.FB0_DO(FB0_DO),
		.FB0_WE(FB0_WE),
		.FB0_RD(FB0_RD),
		
		.FB1_A(FB1_A),
		.FB1_DI(FB1_DI),
		.FB1_DO(FB1_DO),
		.FB1_WE(FB1_WE),
		.FB1_RD(FB1_RD),
		
		.R(R),
		.G(G),
		.B(B),
		.HS_N(HS_N),
		.VS_N(VS_N),
		.YSO_N(YSO_N)
	);
	
	assign DBG_CA = {CA,1'b0};
	
endmodule
