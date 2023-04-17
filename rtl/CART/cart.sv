module CART 
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
	input             TIME_N,
	
	output     [23:1] ROM_A,
	input      [15:0] ROM_DI,
	output     [15:0] ROM_DO,
	output            ROM_RD,
	output            ROM_WRL,
	output            ROM_WRH,
	
	output     [14:0] SRAM_A,
	input       [7:0] SRAM_DI,
	output      [7:0] SRAM_DO,
	output            SRAM_RD,
	output            SRAM_WR,
	
	input      [23:0] rom_sz,
	input             s32x,					//[3] EPPROM bank present, [2:0] 0:none,1:128B,2:128B,3:256B
	input       [3:0] eeprom_map,
	input             noram_quirk,
	input             realtec_map,
	input       [2:0] sf_map					//[2] SRAM bank present, [1:0] 0:none,1:SF-001,2:SF-002,3:SF-004
);

	reg old_LWR_N, old_UWR_N;
	always @(posedge CLK) begin
		old_LWR_N <= LWR_N;
		old_UWR_N <= UWR_N;
	end
	
	//SRAM, SFF2 mappers
	reg         SRAM_BANK;
	reg   [4:0] ROM_BANK[8];
	reg         ROM_BANK_EN;
	reg         ROM_BANK_WP;
	always @(posedge CLK) begin
		if (!RST_N) begin
			SRAM_BANK <= 0;
			ROM_BANK_EN <= 0;
			ROM_BANK_WP <= 0;
			ROM_BANK <= '{0,1,2,3,4,5,6,7};
		end else begin
			if (!TIME_N) begin
				if (!LWR_N && old_LWR_N) begin
					if (rom_sz > 'h200000) begin // SSF2/Pier Solar ROM banking
						if (VA[3:1]) begin
							ROM_BANK_EN <= 1;
//							if (~PIER_QUIRK) begin // SSF2
								ROM_BANK[VA[3:1]] <= VDI[4:0];
//							end
//							else if (MBUS_A[3:1] == 4) begin // Pier EEPROM
//								{ep_cs, ep_hold , ep_sck, ep_si} <= MBUS_DO[3:0];
//							end
//							else if (~MBUS_A[3]) begin // Pier Banks
//								ROM_BANK[{1'b1,MBUS_A[2:1]}] <= MBUS_DO[3:0];
//							end
						end
						else /*if (~PIER_QUIRK)*/ begin // SRAM control only in the first register on SSF2 mapper
							{ROM_BANK_WP,SRAM_BANK} <= VDI[1:0];
						end
					end else begin
						SRAM_BANK <= VDI[0];
					end
				end
			end
		end
	end
	wire ROM_LIN_EN = (rom_sz > 'h400000) & ~ROM_BANK_EN & ~s32x;	//Linear mapper
	wire [23:1] ROM_BANK_A = ROM_BANK_EN ? {ROM_BANK[VA[21:19]], VA[18:1]} : 
	                         ROM_LIN_EN  ? VA[23:1] :
	                         {2'b00,VA[21:1]};
	wire [15:1] SRAM_BANK_A = VA[15:1];
	wire SRAM_EN = ((SRAM_BANK || ({2'b00,VA[21:1]} >= rom_sz[23:1] && !noram_quirk)) && VA[21] && !CE0_N);
	
	//EEPROM mappers
	reg         EEPROM_SDAI;
	wire        EEPROM_SDAO;
	reg         EEPROM_SCL;
	wire [14:0] EEPROM_RAM_A;
	wire  [7:0] EEPROM_RAM_D;
	wire        EEPROM_RAM_WE;
	wire  [7:0] EEPROM_RAM_Q;
	reg         EEPROM_BANK;
	always @(posedge CLK) begin
		if (!RST_N) begin
			EEPROM_BANK <= 0;
			EEPROM_SDAI <= 1;
			EEPROM_SCL <= 1;
		end else if (eeprom_map) begin
			if (VA[23:21] == 3'b001 && !CE0_N && ((!LWR_N && old_LWR_N) || (!UWR_N && old_UWR_N))) begin
				if (!LWR_N && !UWR_N) EEPROM_BANK <= ~VDI[0];
				case (eeprom_map)
					4'b0001: if (!LWR_N) {EEPROM_SDAI,EEPROM_SCL} <= VDI[7:6];
					4'b0010,
					4'b0011: if (!LWR_N) {EEPROM_SCL,EEPROM_SDAI} <= VDI[1:0];
					4'b1011: if      (!LWR_N &&  UWR_N) EEPROM_SDAI <= VDI[0];
					         else if ( LWR_N && !UWR_N) EEPROM_SCL <= VDI[8];
					default: {EEPROM_SCL,EEPROM_SDAI} <= '1;//TODO 4'b1100-4'b1101
				endcase
			end
		end
	end
	wire EEPROM_EN = (|eeprom_map[2:0] && (EEPROM_BANK || !eeprom_map[3])) && VA[23:21] == 3'b001;
	wire [15:0] EEPROM_DO = {16{EEPROM_SDAO & EEPROM_SDAI}};
	
	wire [1:0] EEPROM_MODE = eeprom_map[2:0] <= 3'b010 ? 2'd0 : 2'd1;
	wire [12:0] EEPROM_MASK = eeprom_map[2:0] <= 3'b010 ? 13'h07F : 13'h0FF;
	EPPROM_24CXX E24CXX
	(
		.clk(CLK),
		.rst(~RST_N),
		.en(EEPROM_EN && !CE0_N),
		
		.mode(EEPROM_MODE),
		.mask(EEPROM_MASK),
		
		.sda_i(EEPROM_SDAI),
		.sda_o(EEPROM_SDAO),
		.scl(EEPROM_SCL),

		.ram_addr(EEPROM_RAM_A),
		.ram_d(EEPROM_RAM_D),
		.ram_wr(EEPROM_RAM_WE),
		.ram_q(EEPROM_RAM_Q)
	);
	
	spram #(10,8) eeprom_ram
	(
		.clock(CLK),
		.address(EEPROM_RAM_A[9:0]),
		.data(EEPROM_RAM_D),
		.wren(EEPROM_RAM_WE),
		.q(EEPROM_RAM_Q)
	);
	
	//Realtec mapper
	reg [21:17] REALTEC_BANK;
	reg   [4:0] REALTEC_MASK;
	reg         REALTEC_BOOT;
	always @(posedge CLK) begin
		if (!RST_N) begin
			REALTEC_BANK <= '0;
			REALTEC_MASK <= '0;
			REALTEC_BOOT <= realtec_map;
		end else begin
			if (realtec_map) begin
				if (VA[23:16] == 8'h40 && !	VA[11:1] && !UWR_N && old_UWR_N) begin
					case (VA[15:12])
						4'h0: begin REALTEC_BANK[21:20] <= VDI[2:1]; REALTEC_BOOT <= ~VDI[0]; end
						4'h2: begin 
							case (VDI[5:0])
								6'd0,6'd1:                                      REALTEC_MASK <= 5'b00000;
								6'd2:                                           REALTEC_MASK <= 5'b00001;
								6'd3,6'd4:                                      REALTEC_MASK <= 5'b00011;
								6'd5,6'd6,6'd7,6'd8:                            REALTEC_MASK <= 5'b00111;
								6'd9,6'd10,6'd11,6'd12,6'd13,6'd14,6'd15,6'd16: REALTEC_MASK <= 5'b01111;
								default:                                        REALTEC_MASK <= 5'b11111;
							endcase
						end
						4'h4: begin REALTEC_BANK[19:17] <= VDI[2:0]; end
					endcase
				end
			end
		end
	end
	wire [23:1] REALTEC_A = REALTEC_BOOT ? {11'b00000111111,VA[12:1]} : {2'b00,(VA[21:17] & REALTEC_MASK) + REALTEC_BANK,VA[16:1]};
	
	//SF-001,SF-002,SF-004 mappers
	reg   [7:0] SF001_BANK_REG;
	reg   [7:0] SF002_BANK_REG;
	reg         SF004_SRAM_REG;
	reg   [7:0] SF004_BANK_REG;
	reg   [2:0] SF004_FIRST_PAGE;
	always @(posedge CLK) begin
		if (!RST_N) begin
			SF001_BANK_REG <= 8'h00;
			SF002_BANK_REG <= 8'h00;
			SF004_SRAM_REG <= 0;
			SF004_BANK_REG <= 8'h80;
			SF004_FIRST_PAGE <= '0;
		end else begin
			if (sf_map == 2'd1) begin	//SF-001
				if (!SF001_BANK_REG[5] && VA[23:16] == 8'h00 && !LWR_N && old_LWR_N) begin
					case (VA[11:8])
						4'hE: SF001_BANK_REG <= VDI[7:0];
					endcase
				end
			end else if (sf_map == 2'd2) begin	//SF-002
				if (VA[23:16] == 8'h00 && !LWR_N && old_LWR_N) begin
					SF002_BANK_REG <= VDI[7:0];
				end
			end else if (sf_map == 2'd3) begin	//SF-004
				if (SF004_BANK_REG[7] && VA[23:16] == 8'h00 && !LWR_N && old_LWR_N) begin
					case (VA[11:8])
						4'hD: SF004_SRAM_REG <= VDI[7];
						4'hE: SF004_BANK_REG <= VDI[7:0];
						4'hF: SF004_FIRST_PAGE <= VDI[6:4];
					endcase
				end
			end
		end
	end
	wire [23:1] SF001_ROM_A = SF001_BANK_REG[7] && VA[21:18] == 4'b0000 ? {6'b001110,VA[17:1]} : {2'b00,VA[21:1]};
	wire [15:1] SF001_SRAM_A = VA[15:1];
	wire        SF001_SRAM_EN = (VA[23:20] == 4'h4 && !sf_map[2]) || (VA[23:18] == 6'b001111 && SF001_BANK_REG[7] && sf_map[2]);
	
	wire [23:1] SF002_ROM_A = VA[23:16] >= 8'h20 ? {2'b00,~SF002_BANK_REG[7],VA[20:1]} : {2'b00,VA[21:1]};
	wire [15:1] SF002_SRAM_A = VA[15:1];
	wire        SF002_SRAM_EN = (VA[23:18] == 6'b001111);
							
	wire [23:1] SF004_ROM_A = VA[23:16] < 8'h14 && SF004_BANK_REG[6] ? {3'b000,SF004_FIRST_PAGE + VA[20:18],VA[17:1]} : {3'b000,SF004_FIRST_PAGE,VA[17:1]};
	wire [15:0] SF004_DO = {8'hFF,1'b0,SF004_FIRST_PAGE,4'b0000};
	wire [15:1] SF004_SRAM_A = VA[15:1];
	wire        SF004_SRAM_EN = (VA[23:21] == 3'b001 && SF004_SRAM_REG);
	
	wire ROM_ACCESS =  ~CE0_N | ROM_LIN_EN;//TODO
	wire SRAM_ACCESS = sf_map[1:0] == 2'd1 ? SF001_SRAM_EN :
	                   sf_map[1:0] == 2'd2 ? SF002_SRAM_EN :
	                   sf_map[1:0] == 2'd3 ? SF004_SRAM_EN :
	                                         SRAM_EN;
	
	assign ROM_A = realtec_map         ? REALTEC_A : 
					   sf_map[1:0] == 2'd1 ? SF001_ROM_A : 
						sf_map[1:0] == 2'd2 ? SF002_ROM_A : 
						sf_map[1:0] == 2'd3 ? SF004_ROM_A : 
						                      ROM_BANK_A;
	assign ROM_DO = VDI;
	assign ROM_RD = ROM_ACCESS & ~SRAM_ACCESS & ~CAS0_N;
	assign {ROM_WRH,ROM_WRL} = {ROM_ACCESS&~UWR_N,ROM_ACCESS&~LWR_N};
	
	assign SRAM_A = realtec_map         ? VA[15:1] : 
					    sf_map[1:0] == 2'd1 ? SF001_SRAM_A : 
						 sf_map[1:0] == 2'd2 ? SF002_SRAM_A : 
						 sf_map[1:0] == 2'd3 ? SF004_SRAM_A : 
						                       SRAM_BANK_A;
	assign SRAM_DO = VDI[7:0];
	assign SRAM_RD = SRAM_ACCESS & ~CAS0_N;
	assign SRAM_WR = SRAM_ACCESS & ~LWR_N;
	
	assign VDO = EEPROM_EN ? EEPROM_DO : 
	             !TIME_N ? (sf_map[1:0] == 2'd3 ? SF004_DO : 16'h0000) :
					 SRAM_ACCESS ? {8'hFF,SRAM_DI} : 
					 ROM_ACCESS ? ROM_DI : 
	             16'h0000;
	assign DTACK_N = ~(ROM_LIN_EN & ~AS_N & (VA[23:22] == 2'b10));

endmodule
