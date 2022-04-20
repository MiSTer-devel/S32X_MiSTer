package VDP_PKG; 

	typedef struct packed	//WO,0
	{
		bit [ 2: 0] UNUSED;
		bit         IE1;
		bit [ 1: 0] UNUSED2;
		bit         M3;
		bit         DD;
	} MR1_t;
	parameter bit [7:0] MR1_MASK = 8'h13;
	
	typedef struct packed	//WO,1
	{
		bit         M128K;
		bit         DISP;
		bit         IE0;
		bit         DMA;
		bit         M2;
		bit         M5;
		bit [ 1: 0] UNUSED2;
	} MR2_t;
	parameter bit [7:0] MR2_MASK = 8'hFC;

	typedef struct packed	//WO,2
	{
		bit [ 1: 0] UNUSED;
		bit [15:13] SA;
		bit [ 2: 0] UNUSED2;
	} NTA_t;
	parameter bit [7:0] NTA_MASK = 8'h38;

	typedef struct packed	//WO,3
	{
		bit [ 1: 0] UNUSED;
		bit [15:11] WD;
		bit         UNUSED2;
	} NTW_t;
	parameter bit [7:0] NTW_MASK = 8'h3E;

	typedef struct packed	//WO,4
	{
		bit [ 4: 0] UNUSED;
		bit [15:13] SB;
	} NTB_t;
	parameter bit [7:0] NTB_MASK = 8'h07;

	typedef struct packed	//WO,5
	{
		bit [16: 9] AT;
	} SAT_t;
	parameter bit [7:0] SAT_MASK = 8'hFF;

	typedef struct packed	//WO,6
	{
		bit [ 7: 0] UNUSED;
	} R6_t;
	parameter bit [7:0] R6_MASK = 8'h00;

	typedef struct packed	//WO,7
	{
		bit [ 1: 0] UNUSED;
		bit [ 1: 0] PAL;
		bit [ 3: 0] COL;
	} BGC_t;
	parameter bit [7:0] BGC_MASK = 8'h3F;

	typedef struct packed	//WO,8
	{
		bit [ 7: 0] UNUSED;
	} R8_t;
	parameter bit [7:0] R8_MASK = 8'h00;

	typedef struct packed	//WO,9
	{
		bit [ 7: 0] UNUSED;
	} R9_t;
	parameter bit [7:0] R9_MASK = 8'h00;

	typedef struct packed	//WO,10
	{
		bit [ 7: 0] HIT;
	} HIR_t;
	parameter bit [7:0] HIR_MASK = 8'hFF;

	typedef struct packed	//WO,11
	{
		bit [ 3: 0] UNUSED;
		bit         IE2;
		bit         VSCR;
		bit [ 1: 0] HSCR;
	} MR3_t;
	parameter bit [7:0] MR3_MASK = 8'h0F;

	typedef struct packed	//WO,12
	{
		bit         RS0;
		bit [ 2: 0] UNUSED;
		bit         STE;
		bit [ 1: 0] LSM;
		bit         RS1;
	} MR4_t;
	parameter bit [7:0] MR4_MASK = 8'h8F;

	typedef struct packed	//WO,13
	{
		bit [ 1: 0] UNUSED;
		bit [15:10] HS;
	} NSDT_t;
	parameter bit [7:0] NSDT_MASK = 8'h3F;

	typedef struct packed	//WO,14
	{
		bit [ 7: 0] UNUSED;
	} R14_t;
	parameter bit [7:0] R14_MASK = 8'h00;

	typedef struct packed	//WO,15
	{
		bit [ 7: 0] INC;
	} AI_t;
	parameter bit [7:0] AI_MASK = 8'hFF;

	typedef struct packed	//WO,16
	{
		bit [ 1: 0] UNUSED;
		bit [ 1: 0] VSZ;
		bit [ 1: 0] UNUSED2;
		bit [ 1: 0] HSZ;
	} SS_t;
	parameter bit [7:0] SS_MASK = 8'h33;

	typedef struct packed	//WO,17
	{
		bit         RIGT;
		bit [ 1: 0] UNUSED;
		bit [ 5: 1] WHP;
	} WHP_t;
	parameter bit [7:0] WHP_MASK = 8'h9F;

	typedef struct packed	//WO,18
	{
		bit         DOWN;
		bit [ 1: 0] UNUSED;
		bit [ 4: 0] WVP;
	} WVP_t;
	parameter bit [7:0] WVP_MASK = 8'h9F;

	typedef bit [15:0] DLC_t;	//WO,19,20
	parameter bit [15:0] DLC_MASK = 16'hFFFF;

	typedef bit [23:0] DSA_t;	//WO,21,22,23
	parameter bit [23:0] DSA_MASK = 24'hFFFFFF;

	typedef bit [15:0] DBG_t;	//WO
	parameter bit [15:0] DBG_MASK = 16'hFFFF;
	
	
	typedef struct packed
	{
		bit [16: 0] ADDR;
		bit [15: 0] DATA;
		bit [ 3: 0] CODE;
	} FifoItem_t;
	parameter FifoItem_t FIFOITEM_NULL = {17'h00000,16'h0000,4'h0};
	
	typedef struct packed
	{
		FifoItem_t [3:0] ITEMS;
		bit [ 1: 0] RD_POS;
		bit [ 1: 0] WR_POS;
		bit [ 2: 0] AMOUNT;
	} Fifo_t;
	parameter Fifo_t FIFO_NULL = {{4{FIFOITEM_NULL}},2'b00,2'b00,3'b000};
	
	
	typedef enum bit [8:0] {
		ST_HSCROLL = 9'b000000001,
		ST_BGAMAP  = 9'b000000010,
		ST_BGACHAR = 9'b000000100,
		ST_BGBMAP  = 9'b000001000,
		ST_BGBCHAR = 9'b000010000,
		ST_SPRMAP  = 9'b000100000,
		ST_SPRCHAR = 9'b001000000,
		ST_EXT     = 9'b010000000,
		ST_REFRESH = 9'b100000000
	} Slot_t;
	
	typedef struct packed
	{
		bit         PRI;
		bit [ 1: 0] CP;
		bit         VF;
		bit         HF;
		bit [10: 0] PT;
	} BGPatterName_t;
	parameter BGPatterName_t BGPN_NULL = {1'b0,2'b00,1'b0,1'b0,11'h000};

	typedef struct packed
	{
		bit [31: 0] DATA;
		bit [ 1: 0] PAL;
		bit         PRIO;
		bit         WIN;
		bit         VGRID;
	} BGTile_t;
	typedef BGTile_t BGTileBuf_t [2];
	
	
	typedef struct packed
	{
		bit [ 5: 0] UNUSED;
		bit [ 1: 0] HS;
		bit [ 1: 0] VS;
		bit         UNUSED2;
		bit [ 6: 0] LINK;
		bit [ 5: 0] UNUSED3;
		bit [ 9: 0] VP;
	} ObjCacheInfo_t;
	
	typedef struct packed
	{
		bit [ 8: 0] HP;
		bit         PRI;
		bit [ 1: 0] CP;
		bit         VF;
		bit         HF;
		bit [10: 0] SN;
		bit [ 1: 0] HS;
		bit [ 1: 0] VS;
		bit [ 5: 0] YOFS;
	} ObjSpriteInfo_t;
	
	typedef struct packed
	{
		bit [ 8: 0] XPOS;
		bit [31: 0] DATA;
		bit [ 1: 0] PAL;
		bit         PRIO;
		bit         EN;
		bit [ 2: 0] BORD;
	} ObjRenderInfo_t;
	
	typedef enum bit [2:0] {
		PIX_NORMAL    = 3'b001,
		PIX_SHADOW    = 3'b010,
		PIX_HIGHLIGHT = 3'b100
	} PixMode_t;

endpackage
