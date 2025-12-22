//============================================================================
//  FPGAGen port to MiSTer
//  Copyright (c) 2017-2019 Sorgelig
//
//  YM2612 implementation by Jose Tejada Gomez. Twitter: @topapate
//  Original Genesis code: Copyright (c) 2010-2013 Gregory Estrade (greg@torlus.com) 
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign BUTTONS   = osd_btn;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign LED_DISK  = 0;
assign LED_POWER = 0;
assign LED_USER  = rom_download | sav_pending;

assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S = 1;
assign AUDIO_MIX = 0;
assign HDMI_FREEZE = 0;

wire [1:0] ar = status[49:48];
wire [7:0] arx,ary;

always_comb begin
	case(res) // {V30, H40}
		2'b00: begin // 256 x 224
			arx = 8'd64;
			ary = 8'd49;
		end

		2'b01: begin // 320 x 224
			arx = status[30] ? 8'd10: 8'd64;
			ary = status[30] ? 8'd7 : 8'd49;
		end

		2'b10: begin // 256 x 240
			arx = 8'd128;
			ary = 8'd105;
		end

		2'b11: begin // 320 x 240
			arx = status[30] ? 8'd4 : 8'd128;
			ary = status[30] ? 8'd3 : 8'd105;
		end
	endcase
end

wire       vcrop_en = status[34];
wire [3:0] vcopt    = status[53:50];
reg        en216p;
reg  [4:0] voff;
always @(posedge CLK_VIDEO) begin
	en216p <= ((HDMI_WIDTH == 1920) && (HDMI_HEIGHT == 1080) && !forced_scandoubler && !scale);
	voff <= (vcopt < 6) ? {vcopt,1'b0} : ({vcopt,1'b0} - 5'd24);
end

wire vga_de;
video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? arx : (ar - 1'd1)),
	.ARY((!ar) ? ary : 12'd0),
	.CROP_SIZE((en216p & vcrop_en) ? 10'd216 : 10'd0),
	.CROP_OFF(voff),
	.SCALE(status[55:54])
);

// Status Bit Map:
//             Upper                             Lower              
// 0         1         2         3          4         5         6   
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXXXXXX XXXXXXXXXXXXXXXXXXX XXXXXXXXXXXXXXXXXXXXXXXX

`include "build_id.v"
localparam CONF_STR = {
	"S32X;;",
	"FS,32X;",
	"-;",
	"O67,Region,JP,US,EU;",
	"O9,Auto Region,Header,Disabled;",
	"D2ORS,Priority,US>EU>JP,EU>US>JP,US>JP>EU,JP>US>EU;",
	"-;",
	/*
	"C,Cheats;",
	"H1OO,Cheats Enabled,Yes,No;",
	"-;",
	*/
	"D0RG,Load Backup RAM;",
	"D0RH,Save Backup RAM;",
	"D0OD,Autosave,Off,On;",
	"-;",

	"P1,Audio & Video;",
	"P1-;",
	"P1oGH,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1OU,320x224 Aspect,Original,Corrected;",
	"P1O13,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P1-;",
	"d5P1o2,Vertical Crop,Disabled,216p(5x);",
	"d5P1oIL,Crop Offset,0,2,4,8,10,12,-12,-10,-8,-6,-4,-2;",
	"P1oMN,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1-;",
	"P1OT,Border,No,Yes;",
	"P1oEF,Composite Blend,Off,On,Adaptive;",
	"P1-;",
	"P1OEF,Audio Filter,Model 1,Model 2,Minimal,No Filter;",
	"P1OB,FM Chip,YM2612,YM3438;",
	"P1ON,HiFi PCM,No,Yes;",

	"P2,Input;",
	"P2-;",
	"P2O4,Swap Joysticks,No,Yes;",
	"P2O5,6 Buttons Mode,No,Yes;",
	"P2o57,Multitap,Disabled,4-Way,TeamPlayer: Port1,TeamPlayer: Port2,J-Cart;",
	"P2-;",
	"P2OIJ,Mouse,None,Port1,Port2;",
	"P2OK,Mouse Flip Y,No,Yes;",
	"P2-;",
	"P2oD,Serial,OFF,SNAC;",
	"P2-;",
	"P2o89,Gun Control,Disabled,Joy1,Joy2,Mouse;",
	"D4P2oA,Gun Fire,Joy,Mouse;",
	"D4P2oBC,Cross,Small,Medium,Big,None;",

	"P3,Miscellaneous;",
	"P3-;",
	"P3o34,ROM Storage,Auto,SDRAM,DDR3;",
	"P3-;",
	"P3OPQ,CPU Turbo,None,Medium,High;",
	"P3OV,Sprite Limit,Normal,High;",
	"P3-;",

	"- ;",
	"H3o0,Enable FM,Yes,No;",
	"H3o1,Enable PSG,Yes,No;",
	"H3-;",
	"R0,Reset;",
	"J1,A,B,C,Start,Mode,X,Y,Z;",
	"jn,A,B,R,Start,Select,X,Y,L;", // name map to SNES layout.
	"jp,Y,B,A,Start,Select,L,X,R;", // positional map to SNES layout (3 button friendly) 
	"V,v",`BUILD_DATE
};

wire [63:0] status;
wire  [1:0] buttons;
wire [11:0] joystick_0,joystick_1,joystick_2,joystick_3,joystick_4;
wire  [7:0] joy0_x,joy0_y,joy1_x,joy1_y;
wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [15:0] ioctl_data;
wire  [7:0] ioctl_index;
reg         ioctl_wait = 0;

reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [7:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;

wire        forced_scandoubler;
wire [10:0] ps2_key;
wire [24:0] ps2_mouse;

wire [21:0] gamma_bus;
wire [15:0] sdram_sz;

hps_io #(.CONF_STR(CONF_STR), .WIDE(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.joystick_2(joystick_2),
	.joystick_3(joystick_3),
	.joystick_4(joystick_4),
	.joystick_l_analog_0({joy0_y, joy0_x}),
	.joystick_l_analog_1({joy1_y, joy1_x}),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),
	.new_vmode(new_vmode),

	.status(status),
	.status_in({status[63:8],region_req,status[5:0]}),
	.status_set(region_set),
	.status_menumask({en216p,!gun_mode,1'b1,status[9],~gg_available,~bk_ena}),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	.ioctl_wait(ioctl_wait),

	.sd_lba('{sd_lba}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{sd_buff_din}),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.gamma_bus(gamma_bus),
	.sdram_sz(sdram_sz),

	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse)
);

wire [1:0] gun_mode = status[41:40];
wire       gun_btn_mode = status[42];

wire code_index = &ioctl_index;
wire rom_download = ioctl_download & ~code_index;
wire code_download = ioctl_download & code_index;

reg osd_btn = 0;
always @(posedge clk_sys) begin
	integer timeout = 0;
	reg     has_bootrom = 0;
	reg     last_rst = 0;

	if (RESET) last_rst = 0;
	if (status[0]) last_rst = 1;

	if (rom_download & ioctl_wr & status[0]) has_bootrom <= 1;

	if(last_rst & ~status[0]) begin
		osd_btn <= 0;
		if(timeout < 24000000) begin
			timeout <= timeout + 1;
			osd_btn <= ~has_bootrom;
		end
	end
end
///////////////////////////////////////////////////
wire clk_sys, clk_ram, locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(clk_ram),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll),
	.locked(locked)
);

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_cfg pll_cfg
(
	.mgmt_clk(CLK_50M),
	.mgmt_reset(0),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_read(0),
	.mgmt_readdata(),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

always @(posedge CLK_50M) begin
	reg pald = 0, pald2 = 0;
	reg [2:0] state = 0;
	reg pal_r;

	pald <= PAL;
	pald2 <= pald;

	cfg_write <= 0;
	if(pald2 == pald && pald2 != pal_r) begin
		state <= 1;
		pal_r <= pald2;
	end

	if(!cfg_waitrequest) begin
		if(state) state<=state+1'd1;
		case(state)
			1: begin
					cfg_address <= 0;
					cfg_data <= 0;
					cfg_write <= 1;
				end
			5: begin
					cfg_address <= 7;
					cfg_data <= pal_r ? 2201376125 : 2537930535;
					cfg_write <= 1;
				end
			7: begin
					cfg_address <= 2;
					cfg_data <= 0;
					cfg_write <= 1;
				end
		endcase
	end
end

wire reset = RESET | status[0] | buttons[1] | region_set;

///////////////////////////////////////////////////
// Code loading for WIDE IO (16 bit)
reg [128:0] gg_code;
wire        gg_available;

// Code layout:
// {clock bit, code flags,     32'b address, 32'b compare, 32'b replace}
//  128        127:96          95:64         63:32         31:0
// Integer values are in BIG endian byte order, so it up to the loader
// or generator of the code to re-arrange them correctly.

always_ff @(posedge clk_sys) begin
	gg_code[128] <= 1'b0;

	if (code_download & ioctl_wr) begin
		case (ioctl_addr[3:0])
			0:  gg_code[111:96]  <= ioctl_data; // Flags Bottom Word
			2:  gg_code[127:112] <= ioctl_data; // Flags Top Word
			4:  gg_code[79:64]   <= ioctl_data; // Address Bottom Word
			6:  gg_code[95:80]   <= ioctl_data; // Address Top Word
			8:  gg_code[47:32]   <= ioctl_data; // Compare Bottom Word
			10: gg_code[63:48]   <= ioctl_data; // Compare top Word
			12: gg_code[15:0]    <= ioctl_data; // Replace Bottom Word
			14: begin
				gg_code[31:16]   <= ioctl_data; // Replace Top Word
				gg_code[128]     <=  1'b1;      // Clock it in
			end
		endcase
	end
end



//Genesis
wire [23:1] GEN_VA;
wire [15:0] GEN_VDI, GEN_VDO;
wire        GEN_RNW, GEN_LDS_N, GEN_UDS_N;
wire        GEN_AS_N, GEN_DTACK_N, GEN_ASEL_N;
wire        GEN_RAS2_N, GEN_CAS2_N;
wire        EXT_ROM_N;
wire        EXT_FDC_N;
wire        GEN_VCLK_CE;
wire        GEN_CE0_N;
wire        GEN_LWR_N, GEN_UWR_N, GEN_CAS0_N;
wire        GEN_ROM_CE_N;
wire        GEN_RAM_CE_N;
wire        GEN_TIME_N;
wire        GEN_DOT_CE;
wire        GEN_HBLANK;

//wire [15:0] GEN_MEM_DO;
wire        GEN_MEM_BUSY;

wire [7:0] color_lut[16] = '{
	8'd0,   8'd27,  8'd49,  8'd71,
	8'd87,  8'd103, 8'd119, 8'd130,
	8'd146, 8'd157, 8'd174, 8'd190,
	8'd206, 8'd228, 8'd255, 8'd255
};

wire [3:0] GEN_R, GEN_G, GEN_B;
wire YS_N;
wire EDCLK;
wire vs,hs;
wire ce_pix;
wire hblank, vblank;
wire interlace;
wire [1:0] resolution;

gen gen
(
	.RESET_N(~reset),
	.MCLK(clk_sys),
	
	.VA(GEN_VA),
	.VDI(GEN_VDI),
	.VDO(GEN_VDO),
	.RNW(GEN_RNW),
	.LDS_N(GEN_LDS_N),
	.UDS_N(GEN_UDS_N),
	.AS_N(GEN_AS_N),
	.DTACK_N(GEN_DTACK_N),
	.ASEL_N(GEN_ASEL_N),
	.VCLK_CE(GEN_VCLK_CE),
	.CE0_N(GEN_CE0_N),
	.RAS2_N(GEN_RAS2_N),
	.CAS2_N(GEN_CAS2_N),
	.ROM_N(EXT_ROM_N),
	.FDC_N(EXT_FDC_N),
	.CART_N(0),
	.DISK_N(1),
	.LWR_N(GEN_LWR_N),
	.UWR_N(GEN_UWR_N),
	.CAS0_N(GEN_CAS0_N),
	.TIME_N(GEN_TIME_N),

	.LOADING(rom_download),
	.EXPORT(|status[7:6]),
	.PAL(PAL),

	.RED(GEN_R),
	.GREEN(GEN_G),
	.BLUE(GEN_B),
	.YS_N(YS_N),
	.EDCLK(EDCLK),
	.VS(vs),
	.HS(hs),
	.HBL(GEN_HBLANK),
	.VBL(vblank),
	.BORDER(status[29]),
	.DOT_CE(GEN_DOT_CE),
	.FIELD(VGA_F1),
	.INTERLACE(interlace),
	.RESOLUTION(resolution),

	.J3BUT(~status[5]),
	.JOY_1(status[4] ? joystick_1 : joystick_0),
	.JOY_2(status[4] ? joystick_0 : joystick_1),
	.JOY_3(joystick_2),
	.JOY_4(joystick_3),
	.JOY_5(joystick_4),
	.MULTITAP(status[22:21]),

	.MOUSE(ps2_mouse),
	.MOUSE_OPT(status[20:18]),

	.GUN_OPT(|gun_mode),
	.GUN_TYPE(gun_type),
	.GUN_SENSOR(lg_sensor),
	.GUN_A(lg_a),
	.GUN_B(lg_b),
	.GUN_C(lg_c),
	.GUN_START(lg_start),

	.SERJOYSTICK_IN(SERJOYSTICK_IN),
	.SERJOYSTICK_OUT(SERJOYSTICK_OUT),
	.SER_OPT(SER_OPT),

	.EN_GEN_FM(EN_GEN_FM),
	.EN_GEN_PSG(EN_GEN_PSG),
	.EN_32X_PWM(EN_32X_PWM),
	.EN_HIFI_PCM(status[23]), // Option "N"
	.LADDER(~status[8]),
	.LPF_MODE(status[15:14]),
	.FMBUSY_QUIRK(fmbusy_quirk),

	.EXT_SL(S32X_SL),
	.EXT_SR(S32X_SR),

	.DAC_LDATA(AUDIO_L),
	.DAC_RDATA(AUDIO_R),

	.OBJ_LIMIT_HIGH(status[31]),

	.MEM_RDY(~GEN_MEM_BUSY),
	.GG_RESET(code_download && ioctl_wr && !ioctl_addr),
	.GG_EN(status[24]),
	.GG_CODE({~gg_code[95] & gg_code[128], gg_code[127:0]}),
	.GG_AVAILABLE(gg_available),
	
	.PAUSE_EN(DBG_PAUSE_EN),
	.BGA_EN(VDP_BGA_EN),
	.BGB_EN(VDP_BGB_EN),
	.SPR_EN(VDP_SPR_EN),
	.BG_GRID_EN(VDP_BG_GRID_EN),
	.SPR_GRID_EN(VDP_SPR_GRID_EN)
);

assign GEN_MEM_BUSY = !GEN_RAS2_N                  ? 1'b0 : 
                      CART_SRAM_RD || CART_SRAM_WR ? sdr_busy[2] : 
							                                sdr_busy[1];

assign GEN_VDI = s32x_rom ? S32X_VDO : CART_VDO;
assign GEN_DTACK_N = S32X_DTACK_N & CART_DTACK_N;

// 32X
wire [23:1] S32X_CA;
wire [15:0] S32X_CDO;
wire [15:0] S32X_CDI;
wire        S32X_CASEL_N;
wire        S32X_CLWR_N;
wire        S32X_CUWR_N;
wire        S32X_CCE0_N;
wire        S32X_CCAS0_N;
wire        S32X_CCAS2_N;

wire [15:0] S32X_VDO;
wire        S32X_DTACK_N;

wire [17:1] S32X_SDR_A;
wire [15:0] S32X_SDR_DO;
reg  [15:0] S32X_SDR_DI;
wire        S32X_SDR_CS;
wire  [1:0] S32X_SDR_WE;
wire        S32X_SDR_RD;
wire        S32X_SDR_WAIT;

wire [15:0] S32X_MEM_DO;
wire        S32X_ROM_WAIT;

wire [15:0] S32X_FB0_A;
wire [15:0] S32X_FB0_DI;
wire [15:0] S32X_FB0_DO;
wire  [1:0] S32X_FB0_WE;
wire        S32X_FB0_RD;
wire [15:0] S32X_FB1_A;
wire [15:0] S32X_FB1_DI;
wire [15:0] S32X_FB1_DO;
wire  [1:0] S32X_FB1_WE;
wire        S32X_FB1_RD;
	
wire        S32X_DOT_CE;
wire  [4:0] S32X_R;
wire  [4:0] S32X_G;
wire  [4:0] S32X_B;
wire        S32X_YSO_N;
wire        S32X_HBLANK;

wire [15:0] S32X_SL;
wire [15:0] S32X_SR;

S32X #(
	.USE_ROM_WAIT(1),
	.USE_ASYNC_FB(0)
) S32X
(
	.RST_N(~(reset | rom_download)),
	.CLK(clk_sys),

	.VCLK(GEN_VCLK_CE),
	.VA(GEN_VA),
	.VDI(GEN_VDO),
	.VDO(S32X_VDO),
	.AS_N(GEN_AS_N),
	.DTACK_N(S32X_DTACK_N),
	.LWR_N(GEN_LWR_N),
	.UWR_N(GEN_UWR_N),
	.CE0_N(GEN_CE0_N),
	.CAS0_N(GEN_CAS0_N),
	.CAS2_N(GEN_CAS2_N),
	.ASEL_N(GEN_ASEL_N),
	.VRES_N(1'b1),
	.MRES_N(1'b1),
	.CART_N(1'b0),
	
	.VSYNC_N(vs),
	.HSYNC_N(hs),
	.EDCLK(EDCLK),
	.YS_N(YS_N),
	.PAL(PAL),
	
	.CA(S32X_CA),
	.CDI(S32X_CDI),
	.CDO(S32X_CDO),
	.CASEL_N(S32X_CASEL_N),
	.CLWR_N(S32X_CLWR_N),
	.CUWR_N(S32X_CUWR_N),
	.CCE0_N(S32X_CCE0_N),
	.CCAS0_N(S32X_CCAS0_N),
	.CCAS2_N(S32X_CCAS2_N),
	.ROM_WAIT(S32X_ROM_WAIT),
	
	.SDR_A(S32X_SDR_A),
	.SDR_DI(S32X_SDR_DI),
	.SDR_DO(S32X_SDR_DO),
	.SDR_CS(S32X_SDR_CS),
	.SDR_WE(S32X_SDR_WE),
	.SDR_RD(S32X_SDR_RD),
	.SDR_WAIT(S32X_SDR_WAIT),
	
	.FB0_A(S32X_FB0_A),
	.FB0_DI(S32X_FB0_DI),
	.FB0_DO(S32X_FB0_DO),
	.FB0_WE(S32X_FB0_WE),
	.FB0_RD(S32X_FB0_RD),
	.FB1_A(S32X_FB1_A),
	.FB1_DI(S32X_FB1_DI),
	.FB1_DO(S32X_FB1_DO),
	.FB1_WE(S32X_FB1_WE),
	.FB1_RD(S32X_FB1_RD),
	
	.DOT_CE(S32X_DOT_CE),
	.R(S32X_R),
	.G(S32X_G),
	.B(S32X_B),
	.YSO_N(S32X_YSO_N),
	.HBL(S32X_HBLANK),

	.PWM_L(S32X_SL),
	.PWM_R(S32X_SR)
);
assign S32X_CDI = CART_VDO;
assign S32X_ROM_WAIT = CART_SRAM_RD || CART_SRAM_WR ? sdr_busy[2] : sdr_busy[1];


//Cart
wire [15:0] CART_VDO;
wire        CART_DTACK_N;

wire [23:1] CART_ROM_A;
wire [15:0] CART_ROM_DI;
wire [15:0] CART_ROM_DO;
wire        CART_ROM_WRL;
wire        CART_ROM_WRH;
wire        CART_ROM_RD;

wire [15:1] CART_SRAM_A;
wire  [7:0] CART_SRAM_DI;
wire  [7:0] CART_SRAM_DO;
wire        CART_SRAM_WR;
wire        CART_SRAM_RD;
CART cart
(
	.CLK(clk_sys),
	.RST_N(~(reset || rom_download)),
	
	.VCLK(GEN_VCLK_CE),
	.VA(!s32x_rom ? GEN_VA : S32X_CA),
	.VDI(!s32x_rom ? GEN_VDO : S32X_CDO),
	.VDO(CART_VDO),
	.AS_N(GEN_AS_N),
	.DTACK_N(CART_DTACK_N),
	.LWR_N(!s32x_rom ? GEN_LWR_N : S32X_CLWR_N),
	.UWR_N(!s32x_rom ? GEN_UWR_N : S32X_CUWR_N),
	.CE0_N(!s32x_rom ? GEN_CE0_N : S32X_CCE0_N),
	.CAS0_N(!s32x_rom ? GEN_CAS0_N : S32X_CCAS0_N),
	.CAS2_N(!s32x_rom ? GEN_CAS2_N : S32X_CCAS2_N),
	.ASEL_N(!s32x_rom ? GEN_ASEL_N : S32X_CASEL_N),
	.TIME_N(GEN_TIME_N),
	
	.ROM_A(CART_ROM_A),
	.ROM_DI(CART_ROM_DI),
	.ROM_DO(CART_ROM_DO),
	.ROM_RD(CART_ROM_RD),
	.ROM_WRL(CART_ROM_WRL),
	.ROM_WRH(CART_ROM_WRH),
	
	.SRAM_A(CART_SRAM_A),
	.SRAM_DI(CART_SRAM_DI),
	.SRAM_DO(CART_SRAM_DO),
	.SRAM_RD(CART_SRAM_RD),
	.SRAM_WR(CART_SRAM_WR),
	
	.rom_sz(rom_sz),
	.s32x(s32x_rom),
	.eeprom_map(eeprom_map),
	.noram_quirk(noram_quirk),
	.realtec_map(realtec_map),
	.sf_map(sf_map)
);
assign CART_ROM_DI = sdr_do[1];
assign CART_SRAM_DI = sdr_do[2][7:0];

always @(posedge clk_sys) begin
	reg old_busy;
	
	old_busy <= sdr_busy[3];
	if(rom_download & ioctl_wr) ioctl_wait <= 1;
	if(old_busy & ~sdr_busy[3]) ioctl_wait <= 0;
end

reg use_sdr = 0;

wire ddr_busy;
wire [31:0] ddr_do;
ddram ddram
(
	.*,

	.clk(clk_ram),

	.mem_addr({10'b0000000000,S32X_SDR_A}),
	.mem_dout(ddr_do),
	.mem_din({16'h0000,S32X_SDR_DO}),
	.mem_rd(S32X_SDR_CS & S32X_SDR_RD),
	.mem_wr({2'b00,{2{S32X_SDR_CS}} & S32X_SDR_WE}),
	.mem_chan(0),
	.mem_16b(1),
	.mem_busy(ddr_busy)
);
assign S32X_SDR_DI   = ddr_do[15:0];
assign S32X_SDR_WAIT = ddr_busy;


wire sdr_busy[4];
wire [15:0] sdr_do[4];
sdram sdram
(
	.*,
	.init(~locked),
	.clk(clk_ram),

	//SDRAM
	.addr0({7'b1000000,S32X_SDR_A}), // 1000000-103FFFF
	.din0(S32X_SDR_DO),
	.dout0(sdr_do[0]),
	.rd0(use_sdr & S32X_SDR_CS & S32X_SDR_RD),
	.wr0(S32X_SDR_WE & {2{use_sdr & S32X_SDR_CS}}),
	.busy0(sdr_busy[0]),

	//CART ROM
	.addr1({1'b0,CART_ROM_A[23:1]}),
	.din1(CART_ROM_DO),
	.dout1(sdr_do[1]),
	.rd1(CART_ROM_RD | CART_ROM_WRL | CART_ROM_WRH),
	.wr1({CART_ROM_WRH,CART_ROM_WRL} & {2{schan_quirk}}),
	.busy1(sdr_busy[1]),

	//CART SRAM
	.addr2({9'b110000000,CART_SRAM_A[15:1]}),	//CART RAM 1800000-180FFFF
	.din2({8'hFF,CART_SRAM_DO}),
	.dout2(sdr_do[2]),
	.rd2(CART_SRAM_RD),
	.wr2({2{CART_SRAM_WR}}),
	.busy2(sdr_busy[2]),
	
	//ROM/BRAM Load/Save
	.addr3(rom_download ? {1'b0,ioctl_addr[23:1]} : {9'b110000000,sd_lba[6:0],tmpram_addr}),
	.din3(rom_download ? {ioctl_data[7:0],ioctl_data[15:8]} : {tmpram_dout[7:0],tmpram_dout[15:8]}),
	.dout3(sdr_do[3]),
	.rd3(rom_download ? 1'b0 : (tmpram_req & ~bk_loading)),
	.wr3(rom_download ? {2{ioctl_wait}} : {2{tmpram_req & bk_loading}}),
	.busy3(sdr_busy[3])
);

`ifdef DUAL_SDRAM
wire sdr2_busy;
wire [15:0] sdr2_do;
sdram2 sdram2
(
	.SDRAM_CLK(SDRAM2_CLK),
	.SDRAM_A(SDRAM2_A),
	.SDRAM_BA(SDRAM2_BA),
	.SDRAM_DQ(SDRAM2_DQ),
	.SDRAM_nCS(SDRAM2_nCS),
	.SDRAM_nWE(SDRAM2_nWE),
	.SDRAM_nRAS(SDRAM2_nRAS),
	.SDRAM_nCAS(SDRAM2_nCAS),
	
	.init(~locked),
	.clk(clk_ram),

	//
	.addr0({8'b00000000,S32X_FB0_A}), // 0000000-001FFFF
	.din0(S32X_FB0_DO),
	.dout0(S32X_FB0_DI),
	.rd0(S32X_FB0_RD),
	.wrl0(S32X_FB0_WE[0]),
	.wrh0(S32X_FB0_WE[1]),
	.busy0(sdr2_busy),

	//
	.addr1('0),
	.din1('0),
	.dout1(),
	.rd1(0),
	.wrl1(0),
	.wrh1(0),
	.busy1(),

	//
	.addr2('0),
	.din2('0),
	.dout2(),
	.rd2(0),
	.wrl2(0),
	.wrh2(0),
	.busy2()
);

`else

spram #(16,8) vdp_fb0_l
(
	.clock(clk_sys),
	.address(S32X_FB0_A),
	.data(S32X_FB0_DO[7:0]),
	.wren(S32X_FB0_WE[0]),
	.q(S32X_FB0_DI[7:0])
);

spram #(16,8) vdp_fb0_u
(
	.clock(clk_sys),
	.address(S32X_FB0_A),
	.data(S32X_FB0_DO[15:8]),
	.wren(S32X_FB0_WE[1]),
	.q(S32X_FB0_DI[15:8])
);

`endif

spram #(16,8) vdp_fb1_l
(
	.clock(clk_sys),
	.address(S32X_FB1_A),
	.data(S32X_FB1_DO[7:0]),
	.wren(S32X_FB1_WE[0]),
	.q(S32X_FB1_DI[7:0])
);

spram #(16,8) vdp_fb1_u
(
	.clock(clk_sys),
	.address(S32X_FB1_A),
	.data(S32X_FB1_DO[15:8]),
	.wren(S32X_FB1_WE[1]),
	.q(S32X_FB1_DI[15:8])
);



wire [7:0] r, g, b;
always_comb begin
	if ((VDP_MD_EN && !VDP_32X_EN) || !s32x_rom) begin
		r = color_lut[GEN_R];
		g = color_lut[GEN_G];
		b = color_lut[GEN_B];
	end else if (!VDP_MD_EN && VDP_32X_EN) begin
		r = {S32X_R,S32X_R[4:2]};
		g = {S32X_G,S32X_G[4:2]};
		b = {S32X_B,S32X_B[4:2]};
	end else begin
		r = !S32X_YSO_N ? {S32X_R,S32X_R[4:2]} : color_lut[GEN_R];
		g = !S32X_YSO_N ? {S32X_G,S32X_G[4:2]} : color_lut[GEN_G];
		b = !S32X_YSO_N ? {S32X_B,S32X_B[4:2]} : color_lut[GEN_B];
	end
end

assign hblank = s32x_rom ? S32X_HBLANK : GEN_HBLANK;
assign ce_pix = s32x_rom ? S32X_DOT_CE : GEN_DOT_CE;

/////////////////////////////////////////////////////////////
reg TRANSP_DETECT = 0;
wire cofi_enable = status[46] || (status[47] && TRANSP_DETECT);

wire PAL = status[7];

reg new_vmode;
always @(posedge clk_sys) begin
	reg old_pal;
	int to;
	
	if(~(reset | rom_download)) begin
		old_pal <= PAL;
		if(old_pal != PAL) to <= 5000000;
	end
	else to <= 5000000;
	
	if(to) begin
		to <= to - 1;
		if(to == 1) new_vmode <= ~new_vmode;
	end
end


//lock resolution for the whole frame.
reg [1:0] res;
always @(posedge clk_sys) begin
	reg old_vbl;
	
	old_vbl <= vblank;
	if(old_vbl & ~vblank) res <= resolution;
end

wire [2:0] scale = status[3:1];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;

assign CLK_VIDEO = clk_ram;
assign VGA_SL = {~interlace,~interlace}&sl[1:0];

reg old_ce_pix;
always @(posedge CLK_VIDEO) old_ce_pix <= ce_pix;

wire [7:0] red, green, blue;

cofi coffee (
	.clk(clk_sys),
	.pix_ce(ce_pix),
	.enable(cofi_enable),

	.hblank(hblank),
	.vblank(vblank),
	.hs(hs),
	.vs(vs),
	.red(r),
	.green(g),
	.blue(b),

	.hblank_out(hblank_c),
	.vblank_out(vblank_c),
	.hs_out(hs_c),
	.vs_out(vs_c),
	.red_out(red),
	.green_out(green),
	.blue_out(blue)
);

wire hs_c,vs_c,hblank_c,vblank_c;

video_mixer #(.LINE_LENGTH(320), .HALF_DEPTH(0), .GAMMA(1)) video_mixer
(
	.*,
	.ce_pix(~old_ce_pix & ce_pix),
	.scandoubler(~interlace && (scale || forced_scandoubler)),
	.hq2x(scale==1),
	.freeze_sync(),

	.VGA_DE(vga_de),
	.R((lg_target && gun_mode && (~&status[44:43])) ? {8{lg_target[0]}} : red),
	.G((lg_target && gun_mode && (~&status[44:43])) ? {8{lg_target[1]}} : green),
	.B((lg_target && gun_mode && (~&status[44:43])) ? {8{lg_target[2]}} : blue),

	// Positive pulses.
	.HSync(hs_c),
	.VSync(vs_c),
	.HBlank(hblank_c),
	.VBlank(vblank_c)
);

wire [2:0] lg_target;
wire       lg_sensor;
wire       lg_a;
wire       lg_b;
wire       lg_c;
wire       lg_start;

lightgun lightgun
(
	.CLK(clk_sys),
	.RESET(reset),

	.MOUSE(ps2_mouse),
	.MOUSE_XY(&gun_mode),

	.JOY_X(gun_mode[0] ? joy0_x : joy1_x),
	.JOY_Y(gun_mode[0] ? joy0_y : joy1_y),
	.JOY(gun_mode[0] ? joystick_0 : joystick_1),

	.RELOAD(gun_type),

	.HDE(~hblank_c),
	.VDE(~vblank_c),
	.CE_PIX(ce_pix),
	.H40(res[0]),

	.BTN_MODE(gun_btn_mode),
	.SIZE(status[44:43]),
	.SENSOR_DELAY(gun_sensor_delay),

	.TARGET(lg_target),
	.SENSOR(lg_sensor),
	.BTN_A(lg_a),
	.BTN_B(lg_b),
	.BTN_C(lg_c),
	.BTN_START(lg_start)
);


//////////////////////////////////////////////////////////////////
wire [3:0] hrgn = ioctl_data[3:0] - 4'd7;

reg cart_hdr_ready = 0;
reg hdr_j = 0, hdr_u = 0, hdr_e = 0;
reg  [1:0] region_req;
reg        region_set = 0;

wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state, old_ready = 0;
	old_state <= ps2_key[10];

	if(old_state != ps2_key[10]) begin
		casex(code)
			'h005: begin region_req <= 0; region_set <= pressed; end // F1
			'h006: begin region_req <= 1; region_set <= pressed; end // F2
			'h004: begin region_req <= 2; region_set <= pressed; end // F3
		endcase
	end

	old_ready <= cart_hdr_ready;
	if(~status[9] & ~old_ready & cart_hdr_ready) begin
		//if(status[8]) begin
			region_set <= 1;
			case(status[28:27])
				0: if(hdr_u) region_req <= 1;
					else if(hdr_e) region_req <= 2;
					else if(hdr_j) region_req <= 0;
					else region_req <= 1;
				
				1: if(hdr_e) region_req <= 2;
					else if(hdr_u) region_req <= 1;
					else if(hdr_j) region_req <= 0;
					else region_req <= 2;
				
				2: if(hdr_u) region_req <= 1;
					else if(hdr_j) region_req <= 0;
					else if(hdr_e) region_req <= 2;
					else region_req <= 1;

				3: if(hdr_j) region_req <= 0;
					else if(hdr_u) region_req <= 1;
					else if(hdr_e) region_req <= 2;
					else region_req <= 0;
			endcase
		/*
		end
		else begin
			region_set <= |ioctl_index;
			region_req <= ioctl_index[7:6];
		end
		*/
	end

	if(old_ready & ~cart_hdr_ready) region_set <= 0;
end

reg [24:0] rom_sz;
reg s32x_rom = 0;
always @(posedge clk_sys) begin
	reg old_download;
	old_download <= rom_download;

	if(~old_download && rom_download) begin
		{hdr_j,hdr_u,hdr_e} <= 0;
		s32x_rom <= 1; //&ioctl_index[7:6];
	end
	
	if(old_download && ~rom_download) begin
		cart_hdr_ready <= 0;
		rom_sz <= ioctl_addr[24:0];
	end

	if(ioctl_wr & rom_download) begin
		if(ioctl_addr == 'h1F0) begin
			if(ioctl_data[7:0] == "J") hdr_j <= 1;
			else if(ioctl_data[7:0] == "U") hdr_u <= 1;
			else if(ioctl_data[7:0] == "E") hdr_e <= 1;
			else if(ioctl_data[7:0] >= "0" && ioctl_data[7:0] <= "9") {hdr_e, hdr_u, hdr_j} <= {ioctl_data[3], ioctl_data[2], ioctl_data[0]};
			else if(ioctl_data[7:0] >= "A" && ioctl_data[7:0] <= "F") {hdr_e, hdr_u, hdr_j} <= {      hrgn[3],       hrgn[2],       hrgn[0]};
		end
		if(ioctl_addr == 'h1F2) begin
			if(ioctl_data[7:0] == "J") hdr_j <= 1;
			else if(ioctl_data[7:0] == "U") hdr_u <= 1;
			else if(ioctl_data[7:0] == "E") hdr_e <= 1;
		end
		if(ioctl_addr == 'h1F0) begin
			if(ioctl_data[15:8] == "J") hdr_j <= 1;
			else if(ioctl_data[15:8] == "U") hdr_u <= 1;
			else if(ioctl_data[15:8] == "E") hdr_e <= 1;
		end
		if(ioctl_addr == 'h200) cart_hdr_ready <= 1;
	end
end

reg [3:0] eeprom_map = '0;
reg realtec_map = 0;
//reg fifo_quirk = 0;
reg noram_quirk = 0;
reg pier_quirk = 0;
reg svp_quirk = 0;
reg fmbusy_quirk = 0;
reg schan_quirk = 0;
reg [2:0] sf_map = '0;
reg gun_type = 0;
reg [7:0] gun_sensor_delay = 8'd44;
always @(posedge clk_sys) begin
	reg [87:0] cart_id;
	reg [15:0] crc = '0;
	reg [31:0] realtec_id = '0;
	reg old_download;
	old_download <= rom_download;

	if(~old_download && rom_download) {/*fifo_quirk,*/eeprom_map,realtec_map,noram_quirk,pier_quirk,svp_quirk,fmbusy_quirk,schan_quirk,sf_map} <= 0;

	if(ioctl_wr & rom_download) begin
		if(ioctl_addr == 'h180) cart_id[87:72] <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h182) cart_id[71:56] <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h184) cart_id[55:40] <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h186) cart_id[39:24] <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h188) cart_id[23:08] <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h18A) cart_id[07:00] <= ioctl_data[7:0];
		if(ioctl_addr == 'h18E) crc <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h190) begin
			if     (cart_id[63:0] == "T-50446 ") eeprom_map        <= 4'b0001; 	// John Madden Football 93
			else if(cart_id[63:0] == "T-50516 ") eeprom_map        <= 4'b0001; 	// John Madden Football 93 Championship Edition
			else if(cart_id[63:0] == "T-50396 ") eeprom_map        <= 4'b0001; 	// NHLPA Hockey 93
			else if(cart_id[63:0] == "T-50176 ") eeprom_map        <= 4'b0001; 	// Rings of Power
			else if(cart_id[63:0] == "T-50606 ") eeprom_map        <= 4'b0001; 	// Bill Walsh College Football
			else if(cart_id[63:0] == "MK-1215 ") eeprom_map        <= 4'b0010; 	// Evander Real Deal Holyfield's Boxing
			else if(cart_id[63:0] == "G-4060  ") eeprom_map        <= 4'b0010; 	// Wonder Boy
			else if(cart_id[63:0] == "00001211") eeprom_map        <= 4'b0010; 	// Sports Talk Baseball
			else if(cart_id[63:0] == "MK-1228 ") eeprom_map        <= 4'b0010; 	// Greatest Heavyweights
			else if(cart_id[63:0] == "G-5538  ") eeprom_map        <= 4'b0010; 	// Greatest Heavyweights JP
			else if(cart_id[63:0] == "00004076") eeprom_map        <= 4'b0010; 	// Honoo no Toukyuuji Dodge Danpei
			else if(cart_id[63:0] == "T-12046 ") eeprom_map        <= 4'b0010; 	// Mega Man - The Wily Wars 
			else if(cart_id[63:0] == "T-12053 ") eeprom_map        <= 4'b0010; 	// Rockman Mega World 
			else if(cart_id[63:0] == "G-4524  ") eeprom_map        <= 4'b0010; 	// Ninja Burai Densetsu
			else if(cart_id[63:0] == "00054503") eeprom_map        <= 4'b0010; 	// Game Toshokan
			else if(cart_id[63:0] == "T-81033 ") eeprom_map        <= 4'b0011; 	// NBA Jam (J)
			else if(cart_id[63:0] == "T-081326") eeprom_map        <= 4'b0011; 	// NBA Jam (U)(E)
			else if(cart_id[63:0] == "T-081276") eeprom_map        <= 4'b1011; 	// NFL Quarterback Club
			else if(cart_id[63:0] == "T-81406 ") eeprom_map        <= 4'b1011; 	// NBA Jam TE
			else if(cart_id[63:0] == "T-081586") eeprom_map        <= 4'b1100; 	// NFL Quarterback Club '96
			else if(cart_id[63:0] == "T-81576 ") eeprom_map        <= 4'b1101; 	// College Slam
			else if(cart_id[63:0] == "T-81476 ") eeprom_map        <= 4'b1101; 	// Frank Thomas Big Hurt Baseball
			else if(cart_id[63:0] == "T-8104B ") eeprom_map        <= 4'b1011; 	// NBA Jam TE (32X)
			else if(cart_id[63:0] == "T-8102B ") eeprom_map        <= 4'b1011; 	// NFL Quarterback Club (32X)
			else if(cart_id[63:0] == "T-113016") noram_quirk       <= 1; 			// Puggsy fake ram check
//			else if(cart_id[63:0] == "T-89016 ") fifo_quirk        <= 1; 			// Clue
			else if(cart_id[63:0] == "T-574023") pier_quirk        <= 1; 			// Pier Solar Reprint
			else if(cart_id[63:0] == "T-574013") pier_quirk        <= 1; 			// Pier Solar 1st Edition
			else if(cart_id[63:0] == "MK-1229 ") svp_quirk         <= 1; 			// Virtua Racing EU/US
			else if(cart_id[63:0] == "G-7001  ") svp_quirk         <= 1; 			// Virtua Racing JP
			else if(cart_id[63:0] == "T-35036 ") fmbusy_quirk      <= 1; 			// Hellfire US
			else if(cart_id[63:0] == "T-25073 ") fmbusy_quirk      <= 1; 			// Hellfire JP
			else if(cart_id[63:0] == "MK-1137-") fmbusy_quirk      <= 1; 			// Hellfire EU
			else if(cart_id[63:0] == "T-68???-") schan_quirk       <= 1; 			// Game no Kanzume Otokuyou
			else if(cart_id[87:40] == "SF-001")  sf_map            <= {crc == 16'h3E08,2'b01}; // Beggar Prince (Unl), Beggar Prince rev 1 (Unl)
			else if(cart_id[87:40] == "SF-002")  sf_map            <= {1'b1,2'b10}; // Legend of Wukong (Unl)
			else if(cart_id[87:40] == "SF-004")  sf_map            <= {1'b1,2'b11}; // Star Odyssey (Unl)
			
			// Lightgun device and timing offsets
			if(cart_id[63:0] == "MK-1533 ") begin						  // Body Count
				gun_type  <= 0;
				gun_sensor_delay <= 8'd100;
			end
			else if(cart_id[63:0] == "T-95096-") begin				  // Lethal Enforcers
				gun_type  <= 1;
				gun_sensor_delay <= 8'd52;
			end
			else if(cart_id[63:0] == "T-95136-") begin				  // Lethal Enforcers II
				gun_type  <= 1;
				gun_sensor_delay <= 8'd30;
			end
			else if(cart_id[63:0] == "MK-1658 ") begin				  // Menacer 6-in-1
				gun_type  <= 0;
				gun_sensor_delay <= 8'd120;
			end
			else if(cart_id[63:0] == "T-081156") begin				  // T2: The Arcade Game
				gun_type  <= 0;
				gun_sensor_delay <= 8'd126;
			end
			else begin
				gun_type  <= 0;
				gun_sensor_delay <= 8'd44;
			end
		end
		
		if(ioctl_addr == 'h7E100) realtec_id[31:16] <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h7E102) realtec_id[15: 0] <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h7E104) begin
			if (realtec_id == "SEGA") realtec_map <= 1; // Earth Defend, Funny World & Balloon Boy, Whac-a-Critter
		end
	end
end


/////////////////////////  BRAM SAVE/LOAD  /////////////////////////////
wire downloading = rom_download;
wire bk_change  = CART_SRAM_WR;
wire autosave   = status[13];
wire bk_load    = status[16];
wire bk_save    = status[17];

reg bk_ena = 0;
reg sav_pending = 0;
always @(posedge clk_sys) begin
	reg old_downloading = 0;
	reg old_change = 0;

	old_downloading <= downloading;
	if(~old_downloading & downloading) bk_ena <= 0;

	//Save file always mounted in the end of downloading state.
	if(downloading && img_mounted && !img_readonly) bk_ena <= 1;

	old_change <= bk_change;
	if (~old_change & bk_change) sav_pending <= 1;
	else if (bk_state) sav_pending <= 0;
end

wire bk_save_a  = autosave & OSD_STATUS;
reg  bk_loading = 0;
reg  bk_state   = 0;
//reg  bk_reload  = 0;

always @(posedge clk_sys) begin
	reg old_downloading = 0;
	reg old_load = 0, old_save = 0, old_save_a = 0, old_ack;
	reg [1:0] state;

	old_downloading <= downloading;

	old_load   <= bk_load;
	old_save   <= bk_save;
	old_save_a <= bk_save_a;
	old_ack    <= sd_ack;

	if(~old_ack & sd_ack) {sd_rd, sd_wr} <= 0;

	if (!bk_state) begin
		tmpram_tx_start <= 0;
		state <= 0;
		sd_lba <= 0;
//		bk_reload <= 0;
		bk_loading <= 0;
		if (bk_ena & ((~old_load & bk_load) | (~old_save & bk_save) | (~old_save_a & bk_save_a & sav_pending))) begin
			bk_state <= 1;
			bk_loading <= bk_load;
//			bk_reload <= bk_load;
			sd_rd <=  bk_load;
			sd_wr <= 0;
		end
		if (old_downloading & ~rom_download & bk_ena) begin
			bk_state <= 1;
			bk_loading <= 1;
			sd_rd <= 1;
			sd_wr <= 0;
		end
	end
	else begin
		if (bk_loading) begin
			case(state)
				0: begin
						sd_rd <= 1;
						state <= 1;
					end
				1: if(old_ack & ~sd_ack) begin
						tmpram_tx_start <= 1;
						state <= 2;
					end
				2: if(tmpram_tx_finish) begin
						tmpram_tx_start <= 0;
						state <= 0;
						sd_lba <= sd_lba + 1'd1;
						if(sd_lba[6:0] == 7'h7F) bk_state <= 0;
					end
			endcase
		end
		else begin
			case(state)
				0: begin
						tmpram_tx_start <= 1;
						state <= 1;
					end
				1: if(tmpram_tx_finish) begin
						tmpram_tx_start <= 0;
						sd_wr <= 1;
						state <= 2;
					end
				2: if(old_ack & ~sd_ack) begin
						state <= 0;
						sd_lba <= sd_lba + 1'd1;
						if(sd_lba[6:0] == 7'h7F) bk_state <= 0;
					end
			endcase
		end
	end
end

wire [15:0] tmpram_dout;
wire [15:0] tmpram_din = {sdr_do[3][7:0],sdr_do[3][15:8]};
wire        tmpram_busy = sdr_busy[3];

wire [15:0] tmpram_sd_buff_q;
dpram_dif #(8,16,8,16) tmpram
(
	.clock(clk_sys),

	.address_a(tmpram_addr),
	.wren_a(~bk_loading & tmpram_busy_d & ~tmpram_busy),
	.data_a(tmpram_din),
	.q_a(tmpram_dout),

	.address_b(sd_buff_addr),
	.wren_b(sd_buff_wr & sd_ack /*& |sd_lba[10:4]*/),
	.data_b(sd_buff_dout),
	.q_b(tmpram_sd_buff_q)
);

//reg [10:0] tmpram_lba;
reg  [8:1] tmpram_addr;
reg tmpram_tx_start;
reg tmpram_tx_finish;
reg tmpram_req;
reg tmpram_busy_d;
always @(posedge clk_sys) begin
	reg state;

//	tmpram_lba <= sd_lba[10:0] - 11'h10;
	
	tmpram_busy_d <= tmpram_busy;
	if (~tmpram_busy_d & tmpram_busy) tmpram_req <= 0;

	if (~tmpram_tx_start) {tmpram_addr, state, tmpram_tx_finish} <= '0;
	else if(~tmpram_tx_finish) begin
		if(!state) begin
			tmpram_req <= 1;
			state <= 1;
		end
		else if(tmpram_busy_d & ~tmpram_busy) begin
			state <= 0;
			if(~&tmpram_addr) tmpram_addr <= tmpram_addr + 1'd1;
			else tmpram_tx_finish <= 1;
		end
	end
end

assign sd_buff_din = tmpram_sd_buff_q;


wire [7:0] SERJOYSTICK_IN;
wire [7:0] SERJOYSTICK_OUT;
wire [1:0] SER_OPT;

always @(posedge clk_sys) begin
	if (status[45]) begin
		SERJOYSTICK_IN[0] <= USER_IN[1];//up
		SERJOYSTICK_IN[1] <= USER_IN[0];//down	
		SERJOYSTICK_IN[2] <= USER_IN[5];//left	
		SERJOYSTICK_IN[3] <= USER_IN[3];//right
		SERJOYSTICK_IN[4] <= USER_IN[2];//b TL		
		SERJOYSTICK_IN[5] <= USER_IN[6];//c TR GPIO7			
		SERJOYSTICK_IN[6] <= USER_IN[4];//  TH
		SERJOYSTICK_IN[7] <= 0;
		SER_OPT[0] <= status[4];
		SER_OPT[1] <= ~status[4];
		USER_OUT[1] <= SERJOYSTICK_OUT[0];
		USER_OUT[0] <= SERJOYSTICK_OUT[1];
		USER_OUT[5] <= SERJOYSTICK_OUT[2];
		USER_OUT[3] <= SERJOYSTICK_OUT[3];
		USER_OUT[2] <= SERJOYSTICK_OUT[4];
		USER_OUT[6] <= SERJOYSTICK_OUT[5];
		USER_OUT[4] <= SERJOYSTICK_OUT[6];
	end else begin
		SER_OPT  <= 0;
		USER_OUT <= '1;
	end
end

//debug
reg       VDP_MD_EN = 1;
reg       VDP_32X_EN = 1;
reg       VDP_BGA_EN = 1;
reg       VDP_BGB_EN = 1;
reg       VDP_SPR_EN = 1;
reg [1:0] VDP_BG_GRID_EN = '0;
reg       VDP_SPR_GRID_EN = 0;
reg       DBG_PAUSE_EN = 0;
reg       EN_GEN_FM = 1;
reg       EN_GEN_PSG = 1;
reg       EN_32X_PWM = 1;

always @(posedge clk_sys) begin
	reg old_state = 0;

	old_state <= ps2_key[10];

	if((ps2_key[10] != old_state) && pressed) begin
		casex(code)
			'h00C: begin VDP_32X_EN <= ~VDP_32X_EN; end 	// F4
			'h003: begin VDP_MD_EN <= ~VDP_MD_EN; end 	// F5
			'h00B: begin VDP_BGA_EN <= ~VDP_BGA_EN; end 	// F6
			'h083: begin VDP_BGB_EN <= ~VDP_BGB_EN; end 	// F7
			'h00A: begin VDP_SPR_EN <= ~VDP_SPR_EN; end 	// F8
			'h001: begin VDP_BG_GRID_EN[0] <= ~VDP_BG_GRID_EN[0]; end 	// F9
			'h009: begin VDP_BG_GRID_EN[1] <= ~VDP_BG_GRID_EN[1]; end 	// F10
			'h078: begin VDP_SPR_GRID_EN <= ~VDP_SPR_GRID_EN; end 	// F11
			'h177: begin DBG_PAUSE_EN <= ~DBG_PAUSE_EN; end 	// Pause
			'h016: begin EN_GEN_FM <= ~EN_GEN_FM; end 	// 1
			'h01E: begin EN_GEN_PSG <= ~EN_GEN_PSG; end 	// 1
			'h026: begin EN_32X_PWM <= ~EN_32X_PWM; end 	// 2
			'h025: begin  end 	// 3
		endcase
	end
end

endmodule
