module CCastles   
(
   // clock and reset
   input         clk,         // 10MHz
   input         reset_n,

   // Game Options
   input         WDISn,
   input         SELFTEST,
   input         COCKTAIL,
   // Buttons
   input         STARTJMP1, STARTJMP2,
   input         COINL, COINR, COINA, SLAM,
   // Outputs
   output        STARTLED1, STARTLED2,
   output        LIGHTBULB,
   
   // Video
   output        HBLANK,
   output        HSYNC,
   output        VBLANK,
   output        VSYNC,
   output [8:0]  RGBout,

   // Sound
   output [7:0]  SOUT,

   // User Port
   input   [6:0] USER_IN,
   output  [6:0] USER_OUT
);


wire ce5, ce1H, ce2H, ce2Hd, ce2Hd2, ce2Hd3, ce2Hd4, ce2Hd5, cm2H;
Clock clkgen
(
   .clk(clk), .reset_n(reset_n),
   .ce5(ce5), .ce1H(ce1H), .ce2H(ce2H), .cm2H(cm2H),
   .ce2Hd(ce2Hd), .ce2Hd2(ce2Hd2), .ce2Hd3(ce2Hd3), .ce2Hd4(ce2Hd4), .ce2Hd5(ce2Hd5)
);

wire IRQCLK;
wire [8:0] hc;
wire [7:0] vc;
SyncChain sc
(
   .clk(clk), .reset_n(reset_n), .ce5(ce5),
   
   .hcount(hc), .vcount(vc),
   .HSYNC(HSYNC), .HBLANK(HBLANK),
   .VSYNC(VSYNC), .VBLANK(VBLANK),
   .IRQCLK(IRQCLK)
);

wire WDOGn, wd_reset_n;
Watchdog wd
(
   .clk(clk), .reset_n(reset_n),
   
   .WDISn(WDISn),
   .WDOGn(WDOGn),
   .VBLANK(VBLANK),
   .WDRESETn(wd_reset_n)
);

wire BANK0n, BANK1n;
ProgramMemory rom
(
   .clk(clk),
   .address(BA[12:0]),
   .ROM2n(ROM2n), .ROM1n(ROM1n), .ROM0n(ROM0n),
   .BANK0n(BANK0n), .BANK1n(BANK1n),
   .data_from_rom(rom_to_cpu)
);

wire [15:0] BA;
wire [7:0] BD;
reg [7:0] DI;
wire INTACKn, BRWn;
MicroProcessor cpu
(
   .clk(clk), .ce2H(ce2H),
   .reset_n(reset_n & wd_reset_n),       
        
   .INTACKn(INTACKn),
   .IRQCLK(IRQCLK),
   .BRWn(BRWn),
   
   .BA(BA),
   .data_to_cpu(DI),
   .data_from_cpu(BD)  
);


wire [7:0] rom_to_cpu, sram_to_cpu, bmr_to_cpu, dram_to_cpu, nvram_to_cpu, pokey_to_cpu, leta_to_cpu;
wire [7:0] playerSwitches = { ~STARTJMP2, ~(STARTJMP1|tb1JMP), VBLANK, ~SELFTEST, ~SLAM, ~COINA, ~(COINL|tb1COIN), ~COINR};         // ic11C

always @(posedge clk) 
begin
   if (BA[15])
      begin
         if (NRn)                            // 0xA000-0xFFFF
            DI <= #1 rom_to_cpu;
         else if (~SRAMn)                    // 0x8000-0x8FFF
            DI <= #1 sram_to_cpu;
         else if (NVRAMn == 1'b0)            // 0x9000-0x93FF
            DI <= #1 nvram_to_cpu;
         else if (~IN0n & ~BA[9])            // 0x9400-0x95FF
            DI <= #1 leta_to_cpu;
         else if (~IN0n & BA[9])             // 0x9600-0x97FF
            DI <= #1 playerSwitches;
         else if (~CIOn)                     // 0x9800-0x9BFF
            DI <= #1 pokey_to_cpu;
      end  
   else 
      DI <= #1 dram_to_cpu;                  // 0x0000-0x7FFF, inc BITMODE
end

wire CIOn, IN0n, OUT0n, OUT1n;
wire CRAMn, NVRAMn, SBUSn, SRAMn, UARTn;
wire NRn, ROM0n, ROM1n, ROM2n;
wire VSLDn, HSLDn, BITMDn, XCOORDn, YCOORDn;
AddresDecoder ad
(
   .clk(clk), .ce2H(ce2H), .ce2Hd(ce2Hd),
   .BA(BA), .BRWn(BRWn),
   
   .NRn(NRn), .ROM2n(ROM2n), .ROM1n(ROM1n), .ROM0n(ROM0n),
   
   .WDOGn(WDOGn), .INTACKn(INTACKn), .VSLDn(VSLDn), .HSLDn(HSLDn), .UARTn(UARTn),
   .CIOn(CIOn), .IN0n(IN0n), .OUT0n(OUT0n), .OUT1n(OUT1n), 
   .CRAMn(CRAMn), .NVRAMn(NVRAMn), .SBUSn(SBUSn), .SRAMn(SRAMn),
   
   .BITMDn(BITMDn), .XCOORDn(XCOORDn), .YCOORDn(YCOORDn)
);


wire [14:0] DRBA;
wire PIXA;
AutoIncrement ai
(
   .clk(clk), .reset_n(reset_n), .ce2H(ce2H),
   .BITMDn(BITMDn), .BD(BD), .BA(BA),
   
   .XCOORDn(XCOORDn), .XINCn(XINCn), .AXn(AXn), 
   .YCOORDn(YCOORDn), .YINCn(YINCn), .AYn(AYn), 
   .DRBA(DRBA), .PIXA(PIXA)
);


reg [7:0] hs;
wire HBLANK1 = HBLANK;     // TODO delay 4H  (16 pixels? )
always @(posedge clk or negedge reset_n) 
begin
   if(~reset_n)
        hs <= #1 8'b0000000;
   else if (~HSLDn)
        hs <= #1 BD;
   else if(ce5 & ~VBLANK & ~HBLANK1)
      begin
         if (PLAYER2)
            hs <= #1 hs - 8'b00000001;
         else
            hs <= #1 hs + 8'b00000001;
      end
end

reg [7:0] vs;
reg HSYNCd;
always @(posedge clk or negedge reset_n) 
begin
   if(~reset_n)
        vs <= #1 8'b0000000;
   else if (~VSLDn)
        vs <= #1 BD;
   else 
      begin
         HSYNCd <= #1 HSYNC;
         if (HSYNCd & ~HSYNC & ~VBLANK)
         begin
            if (PLAYER2)
               vs <= #1 vs - 8'b00000001;
            else
               vs <= #1 vs + 8'b00000001;
            end
      end
end


wire [3:0] BIT;
DynamicRam dram
(
   .clk(clk), .ce5(ce5), .ce2Hd2(ce2Hd2), .ce2Hd3(ce2Hd3),
   .DRAMn(BA[15]), .BRWn(BRWn),
   .BITMDn(BITMDn), .PIXA(PIXA),
   .DRBA(DRBA), .BD(BD), 
   .hs(hs), .vs(vs),
   .dram_to_cpu(dram_to_cpu),
   .BIT(BIT)
);

wire LD1n, LD2n, CL1n, CL2n, SHFT0, SHFT1, CK1, DIP2;
PositionControl pc
(
   .clk(clk), .ce(ce5), .ce2Hd4(ce2Hd4),
   .HC(hc), .VC(vc), .PLAYER2(PLAYER2),
   .LD1n(LD1n), .LD2n(LD2n),
   .CL1n(CL1n), .CL2n(CL2n),
   .SHFT0(SHFT0), .SHFT1(SHFT1),
   .CK1(CK1), .DIP2(DIP2)
);


wire [15:0] SR;
WorkingRam sram
(
   .clk(clk), .cm2H(cm2H), .ce2Hd5(ce2Hd5),
   .BA(BA), .SRAMn(SRAMn), .BRWn(BRWn),
   .HC(hc), .BUF1BUF2n(BUF1BUF2n),
   .data_to_sram(BD),
   .data_from_sram(sram_to_cpu),
   .SR(SR)
);

NonVolatileRam nvram
(
   .clk(clk), .ce2Hd(ce2Hd), .reset_n(reset_n),
   .NVRAMn(NVRAMn), .BRWn(BRWn),
   .BA(BA[7:0]),
   .STORE(STORE), .RECALLn(RECALLn), .SIREn(SIREn), //.DCOKn,     // not used
   .data_to_nvram(BD),
   .data_from_nvram(nvram_to_cpu)
); 

wire MATCHn;
wire [4:0] MOVADR;
wire [2:0] AR;
MotionObjectPictureRom mopr
(
   .clk(clk), .ce5(ce5), .ce2Hd5(ce2Hd5),
   .CK1(CK1), .PLAYER2(PLAYER2),
   .addrlo(MOVADR), .MATCHn(MATCHn), .SHFT0(SHFT0), .SHFT1(SHFT1),
   .SR(SR), .AR(AR)
);

MotionObjectVerticalControl movc
(
   .clk(clk), .ce2Hd5(ce2Hd5),
   .SR(SR), .VC(vc), .CK1(CK1), .PLAYER2(PLAYER2),
   .addr(MOVADR), .MATCHn(MATCHn)
);

wire [7:0] MOH1ADR, MOH2ADR;
MotionObjectHorizontalControl mohc
(
   .clk(clk), .ce5(ce5), .SR(SR), 
   .LD1n(LD1n), .LD2n(LD2n),
   .CL1n(CL1n), .CL2n(CL2n),
   .addr1(MOH1ADR), .addr2(MOH2ADR)
);

wire MPI;
wire [2:0] MV;
MotionObjectBuffer mob
(
   .clk(clk), .ce5(ce5), .ce2Hd5(ce2Hd5),
   .CK1(CK1), .SR7(SR[7]),
   .AR(AR), .DIP2(DIP2),
   .addr1(MOH1ADR), .addr2(MOH2ADR),
   .MPI(MPI), .MV(MV)
);


wire tb1VD,tb1VC,tb1HD,tb1HC;
LETA tb
(
   .clk(clk), .reset_n(reset_n),
   .X1(tb1VD), .Y1(tb1VC), .X2(tb1HD), .Y2(tb1HC), 
   .X3(), .Y3(), .X4(), .Y4(),  
   .addr(BA[1:0]),
   .data(leta_to_cpu)
);

AudioOutput ao
(
   .clk(clk), .reset_n(reset_n), .ce2Hd(ce2Hd),
   
   .BA(BA), .BD(BD),
   .CIOn(CIOn), .BRWn(BRWn),
   
   .COCKTAIL(COCKTAIL),
   .STARTJMP1(STARTJMP1),
   .STARTJMP2(STARTJMP2),
   
   .pokey_to_cpu(pokey_to_cpu),
   .SOUT(SOUT)
);

wire [8:0] rgb_data;
ColorMemory cmem
(
   .clk(clk), .ce5(ce5),
   .CRAMn(CRAMn), .BD(BD), .BA(BA[5:0]),
   
   .MPI(MPI), .MV(MV),
   .BIT(BIT),
  
   .o(rgb_data)
);


wire YINCn, XINCn, AYn, AXn;
wire BUF1BUF2n, PLAYER2, SIREn;
AutoIncOutput aio
(
   .clk(clk), .reset_n(reset_n), 
   .OUT1n(OUT1n),
   .BA(BA[2:0]), .BD3(BD[3]),
   
   .BUF1BUF2n(BUF1BUF2n), .STARTLED1(STARTLED1), 
   .SIREn(SIREn), .PLAYER2(PLAYER2),
   .YINCn(YINCn), .XINCn(XINCn),
   .AYn(AYn), .AXn(AXn)
);

wire COINCNTL_L, STORE, RECALLn;
CoinCountOutput cco
(
   .clk(clk), .reset_n(reset_n), 
   .OUT0n(OUT0n),
   .BA(BA[2:0]), .BD0(BD[0]),
   
   .BANK0n(BANK0n), .BANK1n(BANK1n), 
   .COINCNTL_L(COINCNTL_L), .COINCNTL_R(),
   .RECALLn(RECALLn), .STORE(STORE),
   .STARTLED2(STARTLED2), .LIGHTBULB(LIGHTBULB)
);


assign USER_OUT = { 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1 };
wire tb1JMP = ~USER_IN[0];
wire tb1COIN = ~USER_IN[1];
assign tb1VD = USER_IN[2];
assign tb1VC = USER_IN[3];
assign tb1HD = USER_IN[4];
assign tb1HC = USER_IN[5];

assign RGBout = HBLANK | VBLANK ? 9'b000000000 : rgb_data; 

endmodule

