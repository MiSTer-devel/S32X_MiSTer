// Copyright (c) 2010 Gregory Estrade (greg@torlus.com)
// Copyright (c) 2018 Sorgelig
//
// All rights reserved
//
// Redistribution and use in source and synthezised forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
//
// Redistributions in synthesized form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
//
// Neither the name of the author nor the names of other contributors may
// be used to endorse or promote products derived from this software without
// specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
// Please report bugs to the author, but before you do so, please
// make sure that this is not a derivative work and that
// you have the latest version of this file.

module gen
(
	input         RESET_N,
	input         MCLK,
	
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
	output        ROM_N,
	output        FDC_N,
	input         CART_N,
	input         DISK_N,
	output        TIME_N,
	
	input  [15:0] EXT_SL,
	input  [15:0] EXT_SR,

	input   [1:0] LPF_MODE,
	input         EN_GEN_FM,
	input         EN_GEN_PSG,
	input         EN_32X_PWM,
	output [15:0] DAC_LDATA,
	output [15:0] DAC_RDATA,

	input         LOADING,
	input         PAL,
	input         EXPORT,

	input         EN_HIFI_PCM,
	input         LADDER,
	input         OBJ_LIMIT_HIGH,
	input         FMBUSY_QUIRK,

	output  [3:0] RED,
	output  [3:0] GREEN,
	output  [3:0] BLUE,
	output        YS_N,
	output        EDCLK,
	output        VS,
	output        HS,
	output        HBL,
	output        VBL,
	output        CE_PIX,
	input         BORDER,

	output        INTERLACE,
	output        FIELD,
	output  [1:0] RESOLUTION,

	input         J3BUT,
	input  [11:0] JOY_1,
	input  [11:0] JOY_2,
	input  [11:0] JOY_3,
	input  [11:0] JOY_4,
	input  [11:0] JOY_5,
	input   [2:0] MULTITAP,

	input  [24:0] MOUSE,
	input   [2:0] MOUSE_OPT,
	
	input         GUN_OPT,
	input         GUN_TYPE,
	input         GUN_SENSOR,
	input         GUN_A,
	input         GUN_B,
	input         GUN_C,
	input         GUN_START,

	input   [7:0] SERJOYSTICK_IN,
	output  [7:0] SERJOYSTICK_OUT,
	input   [1:0] SER_OPT,

	input         MEM_RDY,

	input         GG_RESET,
	input         GG_EN,
	input [128:0] GG_CODE,
	output        GG_AVAILABLE,
	
	input         PAUSE_EN,
	input         BGA_EN,
	input         BGB_EN,
	input         SPR_EN,
	input   [1:0] BG_GRID_EN,
	input         SPR_GRID_EN,

	output [23:0] DBG_M68K_A,
	output [23:0] DBG_VA_A
);

reg reset;
always @(posedge MCLK) if(M68K_CLKENn) begin
	reset <= ~RESET_N | LOADING;
end


//--------------------------------------------------------------
// CLOCK ENABLERS
//--------------------------------------------------------------
wire M68K_CLKEN = M68K_CLKENp;
reg  M68K_CLKENp, M68K_CLKENn;
reg  Z80_CLKENp, Z80_CLKENn;

always @(negedge MCLK) begin
	reg [3:0] VCLKCNT = 0;
	reg [3:0] ZCLKCNT = 0;

	if(~RESET_N | LOADING) begin
		VCLKCNT <= 0;
		ZCLKCNT = 0;
		Z80_CLKENp <= 0;
		Z80_CLKENn <= 0;
		M68K_CLKENp <= 0;
		M68K_CLKENn <= 1;
	end
	else begin
		M68K_CLKENp <= 0;
		VCLKCNT <= VCLKCNT + 1'b1;
		if (VCLKCNT == 4'd6) begin
			VCLKCNT <= 0;
			M68K_CLKENp <= 1;
		end

		M68K_CLKENn <= 0;
		if (VCLKCNT == 4'd3) begin
			M68K_CLKENn <= 1;
		end
		
		Z80_CLKENn <= 0;
		ZCLKCNT <= ZCLKCNT + 1'b1;
		if (ZCLKCNT == 14) begin
			ZCLKCNT <= 0;
			Z80_CLKENn <= 1;
		end
		
		Z80_CLKENp <= 0;
		if (ZCLKCNT == 7) begin
			Z80_CLKENp <= 1;
		end

	end
end

reg [16:1] ram_rst_a;
always @(posedge MCLK) ram_rst_a <= ram_rst_a + LOADING;

//--------------------------------------------------------------
// CPU 68000
//--------------------------------------------------------------
wire [23:1] M68K_A;
wire [15:0] M68K_DI;
wire [15:0] M68K_DO;
wire        M68K_AS_N;
wire        M68K_UDS_N;
wire        M68K_LDS_N;
wire        M68K_RNW;
wire        M68K_DTACK_N;
wire  [2:0] M68K_FC;
wire        M68K_BG_N;
wire        M68K_BR_N;
wire        M68K_BGACK_N;
reg   [2:0] M68K_IPL_N;

fx68k M68K
(
	.clk(MCLK),
	.extReset(reset),
	.pwrUp(reset),
	.enPhi1(M68K_CLKENp),
	.enPhi2(M68K_CLKENn),

	.eRWn(M68K_RNW),
	.ASn(M68K_AS_N),
	.UDSn(M68K_UDS_N),
	.LDSn(M68K_LDS_N),

	.FC0(M68K_FC[0]),
	.FC1(M68K_FC[1]),
	.FC2(M68K_FC[2]),

	.BGn(M68K_BG_N),
	.BRn(M68K_BR_N),
	.BGACKn(M68K_BGACK_N),
	.HALTn(1),

	.DTACKn(M68K_DTACK_N),
	.VPAn(~M68K_INTACK),
	.BERRn(1),
	.IPL0n(1),
	.IPL1n(M68K_IPL_N[1]),
	.IPL2n(M68K_IPL_N[2]),
	.iEdb(/*genie_ovr ? genie_data : */M68K_DI),
	.oEdb(M68K_DO),
	.eab(M68K_A)
);

wire M68K_INTACK = &M68K_FC & ~M68K_AS_N;

/*wire genie_ovr;
wire [15:0] genie_data;

CODES #(.ADDR_WIDTH(24), .DATA_WIDTH(16)) codes (
	.clk(MCLK),
	.reset(GG_RESET),
	.enable(~GG_EN),
	.addr_in({M68K_A[23:1], 1'b0}),
	.data_in(MBUS_DI),
	.code(GG_CODE),
	.available(GG_AVAILABLE),
	.genie_ovr(genie_ovr),
	.genie_data(genie_data)
);*/


//-----------------------------------------------------------------------
// 68K RAM
//-----------------------------------------------------------------------
wire [15:0] WRAM_Q;
dpram #(15) ram68k_u
(
	.clock(MCLK),
	.address_a(VA[15:1]),
	.data_a(VDO[15:8]),
	.wren_a(~RAM_N & ~RNW & ~UDS_N),
	.q_a(WRAM_Q[15:8]),

	.address_b(ram_rst_a[15:1]),
	.wren_b(LOADING)
);

dpram #(15) ram68k_l
(
	.clock(MCLK),
	.address_a(VA[15:1]),
	.data_a(VDO[7:0]),
	.wren_a(~RAM_N & ~RNW & ~LDS_N),
	.q_a(WRAM_Q[7:0]),

	.address_b(ram_rst_a[15:1]),
	.wren_b(LOADING)
);


//--------------------------------------------------------------
// CPU Z80
//--------------------------------------------------------------
wire [15:0] Z80_A;
wire  [7:0] Z80_DI;
wire  [7:0] Z80_DO;
wire        Z80_RD_N;
wire        Z80_WR_N;
wire        Z80_MREQ_N;
wire        Z80_WAIT_N;
wire        Z80_INT_N;
wire        Z80_RFSH_N;
wire        Z80_RESET_N;
wire        Z80_BUSRQ_N;
wire        Z80_BUSAK_N;

//T80s #(.T2Write(1)) Z80
T80pa Z80
(
	.RESET_n(Z80_RESET_N),
	.CLK(MCLK),
	.CEN_p(Z80_CLKENp),
	.CEN_n(Z80_CLKENn),
//	.CEN(Z80_CLKENn),
	.BUSRQ_n(Z80_BUSRQ_N),
	.BUSAK_n(Z80_BUSAK_N),
	.RFSH_n(Z80_RFSH_N),
	.WAIT_n(Z80_WAIT_N),
	.INT_n(Z80_INT_N),
	.MREQ_n(Z80_MREQ_N),
	.IORQ_n(1),
	.RD_n(Z80_RD_N),
	.WR_n(Z80_WR_N),
	.A(Z80_A),
	.DI(Z80_DI),
	.DO(Z80_DO)
);

wire  [7:0] ZRAM_DO;
dpram #(13) ramZ80
(
	.clock(MCLK),
	.address_a(ZA[12:0]),
	.data_a(ZDO),
	.wren_a(~ZWR_N & ~ZRAM_N),
	.q_a(ZRAM_DO)
);


//--------------------------------------------------------------
// Bus arbiter
//--------------------------------------------------------------
wire [15:0] BA_DI;

wire        RAM_N;
wire        IO_N;
wire        VDP_N;
wire        INTACK_N;

wire [15:0] ZA;
wire  [7:0] ZDI;
wire  [7:0] ZDO;
wire        ZWR_N;
wire        ZRD_N;
wire        ZRAM_N;
wire        YM_N;

BA ba
(
	.RST_N(~reset),
	.CLK(MCLK),
	.ENABLE(1),
	
	.VA(VA),
	.VDI(BA_DI),
	.VDO(VDO),
	.RNW(RNW),
	.LDS_N(LDS_N),
	.UDS_N(UDS_N),
	.AS_N(AS_N),
	.DTACK_N(DTACK_N & IO_DTACK_N & VDP_DTACK_N),
	.ASEL_N(ASEL_N),
	.VCLK_CE(VCLK_CE),
	.CE0_N(CE0_N),
	.LWR_N(LWR_N),
	.UWR_N(UWR_N),
	.CAS0_N(CAS0_N),
	.RAS2_N(RAS2_N),
	.CAS2_N(CAS2_N),
	.RAM_N(RAM_N),
	.IO_N(IO_N),
	.ROM_N(ROM_N),
	.FDC_N(FDC_N),
	.CART_N(CART_N),
	.TIME_N(TIME_N),
	.VDP_N(VDP_N),
	.INTAK_N(INTACK_N),
	
	.ZA(ZA),
	.ZDI(ZDI),
	.ZDO(ZDO),
	.ZWR_N(ZWR_N),
	.ZRD_N(ZRD_N),
	.ZRAM_N(ZRAM_N),
	.YM_N(YM_N),
	
	.M68K_CLKENp(M68K_CLKENp),
	.M68K_CLKENn(M68K_CLKENn),
	.M68K_A(M68K_A),
	.M68K_DI(M68K_DI),
	.M68K_DO(M68K_DO),
	.M68K_RNW(M68K_RNW),
	.M68K_LDS_N(M68K_LDS_N),
	.M68K_UDS_N(M68K_UDS_N),
	.M68K_AS_N(M68K_AS_N),
	.M68K_DTACK_N(M68K_DTACK_N),
	.M68K_FC(M68K_FC[1:0]),
	.M68K_BR_N(M68K_BR_N),
	.M68K_BG_N(M68K_BG_N),
	.M68K_BGACK_N(M68K_BGACK_N),
	
	.Z80_CLKENp(Z80_CLKENp),
	.Z80_CLKENn(Z80_CLKENn),
	.Z80_A(Z80_A),
	.Z80_DI(Z80_DI),
	.Z80_DO(Z80_DO),
	.Z80_WR_N(Z80_WR_N),
	.Z80_RD_N(Z80_RD_N),
	.Z80_MREQ_N(Z80_MREQ_N),
//	.Z80_M1_N(Z80_M1_N),
	.Z80_WAIT_N(Z80_WAIT_N),
//	.Z80_RFSH_N(Z80_RFSH_N),
	.Z80_BUSRQ_N(Z80_BUSRQ_N),
	.Z80_BUSAK_N(Z80_BUSAK_N),
	.Z80_RESET_N(Z80_RESET_N),
	
	.VBUS_A(VBUS_A),
	.VBUS_D(VBUS_D),
	.VBUS_SEL(VBUS_SEL),
	.VBUS_DTACK_N(VBUS_DTACK_N),
	.VBUS_BR_N(VBUS_BR_N),
	.VBUS_BG_N(VBUS_BG_N),
	.VBUS_BGACK_N(VBUS_BGACK_N),
	
	.MEM_RDY(MEM_RDY),
	.PAUSE_EN(PAUSE_EN)
);

assign BA_DI = !RAM_N ? WRAM_Q :
               !IO_N ? IO_DO :
               !VDP_N ? VDP_DO :
					VDI;
assign ZDI = !ZRAM_N ? ZRAM_DO :
             !YM_N ? FM_DO :
				 8'hFF;

				 
assign DBG_VA_A = {VA,1'b0};
assign DBG_M68K_A = {M68K_A,1'b0};


//--------------------------------------------------------------
// VDP + PSG
//--------------------------------------------------------------
wire [15:0] VDP_DO;
wire        VDP_DTACK_N;

wire [23:1] VBUS_A;
wire [15:0] VBUS_D;
wire        VBUS_SEL;
wire        VBUS_DTACK_N;
wire        VBUS_BR_N;
wire        VBUS_BG_N;
wire        VBUS_BGACK_N;

wire        M68K_EXINT;
wire        M68K_HINT;
wire        M68K_VINT;

wire        VRAM_RFRS;

wire [15:0] vram_a;
wire  [7:0] vram_d;
wire  [7:0] vram_q;
wire        vram_we;

VDP vdp
(
	.RST_N(~reset),
	.CLK(MCLK),
	.ENABLE(1),

	.VCLK_ENp(M68K_CLKENp),
	.VCLK_ENn(M68K_CLKENn),
	.SEL(~VDP_N),
	.A(VA[4:1]),
	.RNW(RNW),
	.AS_N(AS_N),
	.DI(VDO),
	.DO(VDP_DO),
	.DTACK_N(VDP_DTACK_N),

	.VRAM_A(vram_a),
	.VRAM_D(vram_d),
	.VRAM_Q(vram_q),
	.VRAM_WE(vram_we),
	
	.HL(HL),
//	.HINT(M68K_HINT),
//	.VINT(M68K_VINT),
	.IPL_N(M68K_IPL_N[2:1]),
	.INTACK_N(INTACK_N),
	.Z80_INT_N(Z80_INT_N),
	
	.REFRESH(VRAM_RFRS),

	.VBUS_A(VBUS_A),
	.VBUS_DATA(VBUS_D),
	.VBUS_SEL(VBUS_SEL),
	.VBUS_DTACK_N(VBUS_DTACK_N),

	.BG_N(VBUS_BG_N),
	.BR_N(VBUS_BR_N),
	.BGACK_N(VBUS_BGACK_N),

	.FIELD_OUT(FIELD),
	.INTERLACE(INTERLACE),
	.RESOLUTION(RESOLUTION),

	.PAL(PAL),
	.R(RED),
	.G(GREEN),
	.B(BLUE),
	.YS_N(YS_N),
	.EDCLK(EDCLK),
	.HS_N(HS),
	.VS_N(VS),
	.CE_PIX(CE_PIX),
	.HBL(HBL),
	.VBL(VBL),
	
	.BORDER_EN(BORDER),
	.VSCROLL_BUG(0),
	.OBJ_MAX(OBJ_LIMIT_HIGH),
	
	.BGA_EN(BGA_EN),
	.BGB_EN(BGB_EN),
	.SPR_EN(SPR_EN),
	.BG_GRID_EN(BG_GRID_EN),
	.SPR_GRID_EN(SPR_GRID_EN)
);

dpram #(16,8) vram
(
	.clock(MCLK),
	.address_a(vram_a),
	.data_a(vram_d),
	.wren_a(vram_we),
	.q_a(vram_q),

	.address_b(ram_rst_a[16:1]),
	.wren_b(LOADING)
);


// PSG 0x10-0x17 in VDP space
wire signed [10:0] PSG_SND;
jt89 psg
(
	.rst(reset),
	.clk(MCLK),
	.clk_en(Z80_CLKENn),

	.wr_n(RNW | VDP_N | ~VA[4] | VA[3]),
	.din(VDO[15:8]),

	.sound(PSG_SND)
);


//--------------------------------------------------------------
// Gamepads
//--------------------------------------------------------------
wire  [7:0] IO_DO;
wire        IO_DTACK_N;
wire        HL;

multitap multitap
(
	.RESET(reset),
	.CLK(MCLK),
	.CE(M68K_CLKEN),

	.J3BUT(J3BUT),

	.P1_UP(~JOY_1[3]),
	.P1_DOWN(~JOY_1[2]),
	.P1_LEFT(~JOY_1[1]),
	.P1_RIGHT(~JOY_1[0]),
	.P1_A(~JOY_1[4]),
	.P1_B(~JOY_1[5]),
	.P1_C(~JOY_1[6]),
	.P1_START(~JOY_1[7]),
	.P1_MODE(~JOY_1[8]),
	.P1_X(~JOY_1[9]),
	.P1_Y(~JOY_1[10]),
	.P1_Z(~JOY_1[11]),

	.P2_UP(~JOY_2[3]),
	.P2_DOWN(~JOY_2[2]),
	.P2_LEFT(~JOY_2[1]),
	.P2_RIGHT(~JOY_2[0]),
	.P2_A(~JOY_2[4]),
	.P2_B(~JOY_2[5]),
	.P2_C(~JOY_2[6]),
	.P2_START(~JOY_2[7]),
	.P2_MODE(~JOY_2[8]),
	.P2_X(~JOY_2[9]),
	.P2_Y(~JOY_2[10]),
	.P2_Z(~JOY_2[11]),

	.P3_UP(~JOY_3[3]),
	.P3_DOWN(~JOY_3[2]),
	.P3_LEFT(~JOY_3[1]),
	.P3_RIGHT(~JOY_3[0]),
	.P3_A(~JOY_3[4]),
	.P3_B(~JOY_3[5]),
	.P3_C(~JOY_3[6]),
	.P3_START(~JOY_3[7]),
	.P3_MODE(~JOY_3[8]),
	.P3_X(~JOY_3[9]),
	.P3_Y(~JOY_3[10]),
	.P3_Z(~JOY_3[11]),

	.P4_UP(~JOY_4[3]),
	.P4_DOWN(~JOY_4[2]),
	.P4_LEFT(~JOY_4[1]),
	.P4_RIGHT(~JOY_4[0]),
	.P4_A(~JOY_4[4]),
	.P4_B(~JOY_4[5]),
	.P4_C(~JOY_4[6]),
	.P4_START(~JOY_4[7]),
	.P4_MODE(~JOY_4[8]),
	.P4_X(~JOY_4[9]),
	.P4_Y(~JOY_4[10]),
	.P4_Z(~JOY_4[11]),
	
	.P5_UP(~JOY_5[3]),
	.P5_DOWN(~JOY_5[2]),
	.P5_LEFT(~JOY_5[1]),
	.P5_RIGHT(~JOY_5[0]),
	.P5_A(~JOY_5[4]),
	.P5_B(~JOY_5[5]),
	.P5_C(~JOY_5[6]),
	.P5_START(~JOY_5[7]),
	.P5_MODE(~JOY_5[8]),
	.P5_X(~JOY_5[9]),
	.P5_Y(~JOY_5[10]),
	.P5_Z(~JOY_5[11]),

	.DISK(~DISK_N),

	.FOURWAY_EN(MULTITAP == 1),
	.TEAMPLAYER_EN({MULTITAP == 3,MULTITAP == 2}),

	.MOUSE(MOUSE),
	.MOUSE_OPT(MOUSE_OPT),
	
	.GUN_OPT(GUN_OPT),
	.GUN_TYPE(GUN_TYPE),
	.GUN_SENSOR(GUN_SENSOR),
	.GUN_A(GUN_A),
	.GUN_B(GUN_B),
	.GUN_C(GUN_C),
	.GUN_START(GUN_START),

	.SERJOYSTICK_IN(SERJOYSTICK_IN),
	.SERJOYSTICK_OUT(SERJOYSTICK_OUT),
	.SER_OPT(SER_OPT),

	.PAL(PAL),
	.EXPORT(EXPORT),

	.SEL(~IO_N),
	.A(VA[4:1]),
	.RNW(RNW),
	.DI(VDO[7:0]),
	.DO(IO_DO),
	.DTACK_N(IO_DTACK_N),
	.HL(HL)
);


//--------------------------------------------------------------
// YM2612
//--------------------------------------------------------------
wire  [7:0] FM_DO;
wire signed [15:0] FM_right;
wire signed [15:0] FM_left;
wire signed [15:0] FM_LPF_right;
wire signed [15:0] FM_LPF_left;
wire [15:0] SL;
wire [15:0] SR;
wire signed [15:0] PRE_LPF_L;
wire signed [15:0] PRE_LPF_R;

jt12 fm
(
	.rst(~Z80_RESET_N),
	.clk(MCLK),
	.cen(M68K_CLKENp),

	.cs_n(0),
	.addr(ZA[1:0]),
	.wr_n(YM_N | ZWR_N),
	.din(ZDO),
	.dout(FM_DO),
	.en_hifi_pcm(EN_HIFI_PCM),
	.ladder(LADDER),
	.snd_left(FM_left),
	.snd_right(FM_right)
);

wire signed [15:0] fm_adjust_l = (FM_left << 4) + (FM_left << 2) + (FM_left << 1) + (FM_left >>> 2);
wire signed [15:0] fm_adjust_r = (FM_right << 4) + (FM_right << 2) + (FM_right << 1) + (FM_right >>> 2);

genesis_fm_lpf fm_lpf_l
(
	.clk(MCLK),
	.reset(reset),
	.in(fm_adjust_l),
	.out(FM_LPF_left)
);

genesis_fm_lpf fm_lpf_r
(
	.clk(MCLK),
	.reset(reset),
	.in(fm_adjust_r),
	.out(FM_LPF_right)
);

wire signed [15:0] fm_select_l = ((LPF_MODE == 2'b01) ? FM_LPF_left : fm_adjust_l);
wire signed [15:0] fm_select_r = ((LPF_MODE == 2'b01) ? FM_LPF_right : fm_adjust_r);

wire signed [10:0] psg_adjust = PSG_SND - (PSG_SND >>> 5);

jt12_genmix genmix
(
	.rst(reset),
	.clk(MCLK),
	.fm_left(fm_select_l),
	.fm_right(fm_select_r),
	.psg_snd(psg_adjust),
	.fm_en(EN_GEN_FM),
	.psg_en(EN_GEN_PSG),
	.snd_left(SL),
	.snd_right(SR)
);

SND_MIX mix
(
	.CH0_R(SR),
	.CH0_L(SL),
	.CH0_EN(1),
	
	.CH1_R(EXT_SR),
	.CH1_L(EXT_SL),
	.CH1_EN(EN_32X_PWM),
	
	.OUT_R(PRE_LPF_R),
	.OUT_L(PRE_LPF_L)
);

genesis_lpf lpf_right
(
	.clk(MCLK),
	.reset(reset),
	.lpf_mode(LPF_MODE[1:0]),
	.in(PRE_LPF_R),
	.out(DAC_RDATA)
);

genesis_lpf lpf_left
(
	.clk(MCLK),
	.reset(reset),
	.lpf_mode(LPF_MODE[1:0]),
	.in(PRE_LPF_L),
	.out(DAC_LDATA)
);

endmodule
