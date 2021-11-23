`timescale 1ns / 1ps



module ramcpld(

		input	CLKCPU,
		input	RESET,

		input	[23:0] A,
		
		inout	[7:0] D,
		input [1:0] SIZ,
        
		input 		AS20,
		input			RW20,
		input 		DS20,
		
		// ram chip control
		output reg 		  RAMOE,
		output reg [3:0] CAS,
		output reg [1:0] RAS,
		output  [9:0] RAM_A,

		output  [1:0] DSACK,
		output  		  nOVR, 
		
		input 		 MEMSIZE,
		
		// Debug
		output LED,
		output [7:0] TEST,
		
		// unused spare pins
      output  INT2,
		input [2:0] IPL,
		input IOR,
		input IOW,
		input IDENT,
		input RS2
);

reg [2:0] POR = 3'b000;


reg debug_bit = 'b0;

// FASTRAM part

reg RAM_READY;
reg RAM_MUX;

wire [5:0] zaddr = {A[6:1]};


reg configured = 'b0;
reg shutup	   = 'b0;
reg half_ram;

reg [7:4] data_out;
reg [7:0] base_address;

wire Z2_nWRITE = (Z2_ACCESS | RW20);
wire Z2_nREAD = (Z2_ACCESS | ~RW20);
wire RAM_ACCESS = (AS20 | chip_selected);
wire Z2_ACCESS = ({A[23:16]} != {8'hE8}) | AS20 | DS20 | configured | shutup;

wire Z2_ADDRESS = ({A[23:16]} != {8'hE8}) | AS20 | configured | shutup;

assign D = Z2_nREAD ? 8'bzzzzzzzz : {data_out,4'bzzzz};

wire fastcycle_int = Z2_ACCESS;
wire FASTCYCLE = fastcycle_int | AS20;


wire FR_RESET = (	RESET & POR[2]);

// /OVR needs to be asserted prior to the CPU asserting /AS
//	(see http://www.ianstedman.co.uk/downloads/A1200FuncSpec.txt)
//	This prevents the Amiga from internally generating DSACK signals for
//	the memory areas that we are managing. 
assign nOVR = (~POR[2]) | (RAM_ACCESS & Z2_ADDRESS)  ? 1'bz : 1'b0;


//nDSACK="10" for 8-bit cycles (IO) and "00" for 32-bit cycles (RAM)
assign DSACK[0] = FASTCYCLE & RAM_READY ? 1'bz : 1'b0;
assign DSACK[1] = RAM_READY? 1'bz : 1'b0;

 // reset delay
 always @(posedge CLKCPU) 
 begin	

   if (!RESET) 
      POR <= 'h0;
   else begin

       // Make a clock dependant RESET
      POR[2:0] <= {POR[1:0], 1'b1};
      
   end

end

always @(posedge CLKCPU) begin 

    if (!FR_RESET) begin 

        half_ram <= MEMSIZE;

    end

end 


// Zorro II Autoconfig


always @(negedge DS20 or negedge FR_RESET) begin

    if (!FR_RESET) 
	 begin

        configured <= 1'b0; 
        shutup <= 1'b0;     
    end 
	  else 
	   begin

        if (!(Z2_ADDRESS | RW20)) 
		  begin
            case (zaddr)
                'h24: begin
                    base_address[7:4] <= D[7:4];
                    configured <= 1'b1;
                end
                //'h25: base_address[3:0] <= D[7:4];
					 // 0x4C ec_Shutup
                'h26: shutup <= 1'b1;
            endcase
				debug_bit <= 1'b1; 
        end

			  case (zaddr)
					// 0x00 - Zorro II PIC: er_Type HI
					'h00: data_out[7:4] <= 4'he;
					// 0x02 - RAM size: er_Type LO
					'h01: begin   
						 if (half_ram == 1'b1) begin
							  data_out[7:4] <= 4'h7; // 0111 for 4mb,
						 end else begin 
							  data_out[7:4] <= 4'h0; // 0000 for 8mb
						 end 
					end
					//0x04 - Product number: er_Product
					'h02: data_out[7:4] <= 4'hb; //4'hb;//  HI
					'h03: data_out[7:4] <= 4'hd;//4'hd;//  LO
					
					// 0x08 er_Flags
					'h04: data_out[7:4] <= 4'h3; // 7
					'h05: data_out[7:4] <= 4'hf; // F 
					// Must be 00 (0xff inverted)
					// 06 - F
					// 07 - F
					// er_Manufacturer HI byte
					'h08: data_out[7:4] <= 4'he;
					'h09: data_out[7:4] <= 4'he;
					// er_Manufacturer LO byte
					'h0a: data_out[7:4] <= 4'he;
					'h0b: data_out[7:4] <= 4'he;
					// 0x0c er_SerialNumber 4 bytes
					// 0x0d 
					// 0x0e
					// 0x0f
					// 0x10
					//'h11: data_out[7:4] <= 4'he;
					'h12: data_out[7:4] <= 4'he;
					'h13: data_out[7:4] <= 4'hd;
					
					default: data_out[7:4] <= 4'hf;
			  endcase
      end
end

// zorro II chip bank decoder.
wire [3:0] bank;
assign bank[0] = A[23:21] != 3'b001; // $200000
assign bank[1] = A[23:21] != 3'b010; // $400000
assign bank[2] = (half_ram | A[23:21] != 3'b011) & (~half_ram | A[23:20] != 4'hC); // $600000 or $C00000
assign bank[3] = (half_ram | A[23:21] != 3'b100) & (~half_ram | A[23:19] != {4'hD, 1'b0}); // $800000 of D0 0000

wire [1:0] chip_ras = {&bank[3:2], &bank[1:0]};
wire    chip_selected = &chip_ras[1:0];
   

wire [3:0] casint;
assign casint[3] = A[1] | A[0];
assign casint[2] = (~SIZ[1] & SIZ[0] & ~A[0]) | A[1];
assign casint[1] = (SIZ[1] & ~SIZ[0] & ~A[1] & ~A[0]) | (~SIZ[1] & SIZ[0] & ~A[1]) |(A[1] & A[0]);
assign casint[0] = (~SIZ[1] & SIZ[0] & ~A[1] ) | (~SIZ[1] & SIZ[0] & ~A[0] ) | (SIZ[1] & ~A[1] & ~A[0] ) | (SIZ[1] & ~SIZ[0] & ~A[1] );

assign RAM_A[1:0] = RAM_MUX ? {A[21:20]} : {A[3:2]} ;
assign RAM_A[9:2] = RAM_MUX ? {A[19:12]} : {A[11:4]};


reg 	  AS20_D; 
reg [2:0] state = 'd0;
reg [7:0] refresh_count ='d0;
reg 	  refresh_req  ='d0;  
      
localparam CYCLE_IDLE = 'd0,
			  CYCLE_CAS = 'd1,
           CYCLE_WAIT = 'd2,
           CYCLE_CBR1 = 'd3,
           CYCLE_CBR2 = 'd4;
             
// ram state machine
always @(posedge CLKCPU, posedge AS20) begin

    if( AS20 == 1 ) begin       
       state <= CYCLE_IDLE;
       AS20_D <= 1'b1;     
       RAS <= 2'b11;
       CAS <= 4'b1111;
       RAM_READY <= 1'b1;
       RAMOE <= 1'b1;
        
    end else begin
       AS20_D <= AS20; 
       case (state)
                
     CYCLE_IDLE: begin 
        RAS <= 2'b11;
        CAS <= 4'b1111;

        if (AS20_D & ~AS20) begin 	       
           refresh_count <= refresh_count + 'd1;
        end
           
        if (refresh_count > 'd60) begin
           refresh_req <= 1;
           refresh_count <= 'd0; 
        end
        
        if (refresh_req & RW20) begin 
        CAS <= 4'b0000;
        state <= CYCLE_CBR1;
        refresh_req <= 1'b0;  
            
        end else if (chip_selected == 1'b0) begin
        RAS[0] <= chip_ras[0];
        RAS[1] <= chip_ras[1];	
        RAM_READY <= 1'b0;
        state <= CYCLE_CAS;
        RAMOE <=  1'b0;
        end
     end
           
     CYCLE_CAS: begin
        CAS[3] <= casint[3] & ~RW20;
            CAS[2] <= casint[2] & ~RW20;
            CAS[1] <= casint[1] & ~RW20;
            CAS[0] <= casint[0] & ~RW20;
        RAM_READY <= 1'b0;
        state <= CYCLE_WAIT; 
     end
           
     CYCLE_WAIT: begin  		 		
        state <= CYCLE_WAIT;
     end
         
     CYCLE_CBR1: begin
        RAS <= 2'b00;		 
        state <= CYCLE_CBR2;
     end
     
     CYCLE_CBR2: begin   
        RAS <= 2'b11;	  
        CAS <= 4'b1111;
        state <= CYCLE_IDLE;
     end
     
     default: state <= CYCLE_IDLE;
       endcase // case (state)
    end // else: !if( AS20 == 1 )
end
           
always @(negedge CLKCPU or posedge AS20) begin
     // ram address mux
     if(AS20==1)begin
            RAM_MUX <= 1'b1;
         
     end else begin 
          RAM_MUX <= &RAS;			  
    end
end


// ~ FASTRAM part




 

// Unused spare pins

assign INT2 = 1'bz;


// Debug pins
assign LED = configured;

assign TEST[0] = Z2_ADDRESS; //p100 
assign TEST[1] = Z2_nWRITE; // p99 
assign TEST[2] = Z2_nREAD;  // p98 
assign TEST[3] = configured;// p97 

assign TEST[4] = debug_bit; 
assign TEST[5] = FR_RESET; 
assign TEST[6] = POR[2]; 
assign TEST[7] = (A[23:16] == 8'hE8);

endmodule
