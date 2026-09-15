`default_nettype none

/*  This code first displays a background image (MIF) on the VGA output. Then, the code
 *  displays two objects, each of which is read from a small memory, on the screen. Each
 *  object can be moved left/right/up/down by pressing PS2 keyboard keys. To use the circuit,
 *  first use KEY[0] to perform a reset. The background MIF should appear on the VGA output. 
 *  Pressing KEY[1] displays one object, at its initial position, and pressing KEY[2] displays
 *  the other object. Move the first object left/right/up/down using PS2 keys a/s/w/z, and 
 *  the other object using d/f/r/c.
*/
module vga_demo(CLOCK_50, SW, KEY, LEDR, PS2_CLK, PS2_DAT, HEX0,
				VGA_R, VGA_G, VGA_B,
				VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);

//change: we removed all hex displays except HEX0
//change: resolution was set to 160x120
    parameter RESOLUTION = "160x120"; // "640x480" "320x240" "160x120"

    // specify the color depth. This design supports depths of 9, 6, and 3
    parameter COLOR_DEPTH = 9; // 9 6 3

    // specify the number of bits needed for an X (column) pixel coordinate on the VGA display
    parameter nX = (RESOLUTION == "640x480") ? 10 : ((RESOLUTION == "320x240") ? 9 : 8);
    // specify the number of bits needed for a Y (row) pixel coordinate on the VGA display
    parameter nY = (RESOLUTION == "640x480") ? 9 : ((RESOLUTION == "320x240") ? 8 : 7);

    `define COLOR_DEPTH_9
    
    // state names for the FSM that controls drawing of objects
    parameter A = 2'b00, B = 2'b01, C = 2'b10, D = 2'b11;

	input wire CLOCK_50;	
	input wire [9:0] SW;
	input wire [3:0] KEY;
	output wire [9:0] LEDR;
        inout wire PS2_CLK, PS2_DAT;
        output wire [6:0] HEX0;
	output wire [7:0] VGA_R;
	output wire [7:0] VGA_G;
	output wire [7:0] VGA_B;
	output wire VGA_HS;
	output wire VGA_VS;
	output wire VGA_BLANK_N;
	output wire VGA_SYNC_N;
	output wire VGA_CLK;	
	
	//change: added new wires that would draw the three coins and the game won screen
	//change: changed O1 wires to be pacman
	wire [nX-1:0] pacman_x, coin1_x, coin2_x, coin3_x, gameWon_x, MUX_x;    // x coordinate multiplexer
	wire [nY-1:0] pacman_y, coin1_y, coin2_y, coin3_y, gameWon_y, MUX_y;    // y coordinate multiplexer
	wire [COLOR_DEPTH-1:0] pacman_color, coin1_color, coin2_color, coin3_color, gameWon_color, MUX_color; // color multiplexer
	wire pacman_write, coin1_write, coin2_write, coin3_write, gameWon_write, MUX_write; // write control multiplexer

	reg prev_ps2_clk;               // ps2_clk value in the previous clock cycle
  	wire negedge_ps2_clk;           // used for PS2 keyboard signals
   	wire ps2_rec;                   // set when a PS2 packet has been received
  	wire object_sel;
   	reg [32:0] Serial;              // each PS2 serial data packet has 11 bits:
                                   	// STOP (1) PARITY d7 d6 d5 d4 d3 d2 d1 d0 START (0)
                                   	// 33 total bits are received (scancode/release/scancode
  	reg [3:0] Packet;               // used to know when 11 bits have been received
  	wire [7:0] scancode;            // used to save the current ps2 scancode
  	reg Esc;                        // enable scancode register
  	reg step;                       // move an object

	//change: add more done wires for the new objects (coins and game won screen)
   	wire pacman_done, coin1_done, coin2_done, coin3_done, gameWon_done, done;             // object move completed

	//change: object selector is now a 3 bit wire called whichObject
   	reg [2:0] whichObject;          
   	wire [2:0] pacman_dir;          //change: used to set direction for moving pacman
  	reg [1:0] y_Q, Y_D;             // FSM, used to control drawing of objects

   	wire Resetn, KEY0;        	// Reset, and synchronized versions of KEYs
   	wire PS2_CLK_S, PS2_DAT_S;      // synchronized versions of PS2 signals

	//change: Resetn is now assigned to switch zero	
   	assign Resetn = !SW[0];
	sync S0 (~KEY[0], Resetn, CLOCK_50, KEY0);

  	sync S4 (PS2_CLK, Resetn, CLOCK_50, PS2_CLK_S);
  	sync S5 (PS2_DAT, Resetn, CLOCK_50, PS2_DAT_S);

   	always @(posedge CLOCK_50)  // record PS2 clock value in previous CLOCK_50 cycle
		prev_ps2_clk <= PS2_CLK_S;

    	// check when PS2_CLK has changed from 1 to 0
   	assign negedge_ps2_clk = (prev_ps2_clk & !PS2_CLK_S);

    	// save PS2 data packet
   	always @(posedge CLOCK_50) begin    // specify a 33-bit shift register
		if (Resetn == 0)
            	Serial <= 33'b0;
      	else if (negedge_ps2_clk) begin
            	Serial[31:0] <= Serial[32:1];
            	Serial[32] <= PS2_DAT_S;
		end
	end
        
    	// 'count' ps2 data bits
	always @(posedge CLOCK_50) begin    // specify a 34-bit shift register
		if (!Resetn || Packet == 'd11)
            Packet <= 'b0;
		else if (negedge_ps2_clk) begin
            Packet <= Packet + 'b1;
		end
	end
        
   	// used to start an object move. Key press makes scancode/release/scancode, so we check
   	// for Serial[30:23] == Serial[8:1]. Key repeat makes scancode/scancode/...
	assign ps2_rec = (Packet == 'd11) && (Serial[30:23] == Serial[8:1]); //1d1c1b23 (wasd)

    	// ps2 scancode is in Serial[8:1]
	regn USC (Serial[8:1], Resetn, Esc, CLOCK_50, scancode);

    	//change: select object based on current game condition 
	reg select;
	assign object_sel = select;
	
	//change: created a bunch of wires (& reg) to help with coin & maze collision logic
	reg  [2:0] temp_direction; //change: register to pick direction then assign it to pacman based on key pressed
	wire [2:0] coinEnable;     //change: each bit of this vector corresponds to one coin, 1 means coin enabled and 0 means disabled
	wire [2:0] coinDisable;    //change: used in a pulse module that tells the coin to disable when coinEnable is 0
	wire [3:0] moveEnable;	   //change: used to prevent pacman's movement if colliding with a maze wall
	wire [1:0] score;	   //change: used to keep track of score
	
	wire [7:0] stableX;	   //change: pacman's top left x coordinate that isnt being sent to draw
	wire [6:0] stableY;	   //change: pacman's top left y coordinate that isnt being sent to draw
		 
	//change: collision module that checks if pacman is colliding with a coin or the wall
	collision_checker U1(CLOCK_50, Resetn, pacman_x, pacman_y, coinEnable, moveEnable, score, stableX, stableY);
	
	//change: registers to indicate if the game is won or not
	reg isGameWon;
	reg gameWon;
	
	//change: comb. cct. -> if score is 3 then game is won, don't select pacman and instead select the game won screen
	//change: otherwise, select pacman and not the game won screen
	always @ (*)
		if (score == 2'b11)
		begin
			isGameWon = 1'b1;
			select = 1'b0;
		end
		else
		begin
			isGameWon = 1'b0;
			select = 1'b1;
		end
	
	//change: load the game won screen on the positive edge of clock
	//change: make game won screen display forever if chosen
	always @(posedge CLOCK_50) begin
    		if (!Resetn)
       			gameWon <= 1'b0;
    		else if (isGameWon)
        		gameWon <= 1'b1; 
		end
	
	//change: send coinEnables into a pulse module that goes high for one clock cycle if a coin is disabled
	pulse P1 (CLOCK_50, Resetn, !coinEnable[0], coinDisable[0]);
	pulse P2 (CLOCK_50, Resetn, !coinEnable[1], coinDisable[1]);
	pulse P3 (CLOCK_50, Resetn, !coinEnable[2], coinDisable[2]);

	//change: comb. cct. to decide what direction pacman moves based on the key pressed (WASD)
	always @ (*) 
		case (scancode[7:0])//0 = up, 1 = down, 2 = left, 3 = right
			 7'h1d: if (moveEnable[0]) temp_direction <= 3'b001; else temp_direction <= 3'b100;
			 7'h1b: if (moveEnable[1]) temp_direction <= 3'b010; else temp_direction <= 3'b100;
			 7'h1c: if (moveEnable[2]) temp_direction <= 3'b000; else temp_direction <= 3'b100;
			 7'h23: if (moveEnable[3]) temp_direction <= 3'b011; else temp_direction <= 3'b100;
			 //LEFT = 2'b00 /*'d'*/, RIGHT = 2'b11/*'a'*/, UP = 2'b01/*'w'*/, DOWN = 2'b10/*'s'*/
			 default: temp_direction <= 3'b100;
		endcase
	
	assign pacman_dir = temp_direction;
	
	//change: multiplexer to pick which object is drawn based on game logic/current game condition
	always @(posedge CLOCK_50)
		if (!Resetn | KEY0)
			whichObject <= 3'b000;  //change: on reset or when key0 is pressed, draw pacman
		else if (coinDisable[0])
			whichObject <= 3'b001;  //change: make coin 1 disappear when coin 1 is disabled
		else if (coinDisable[1])
			whichObject <= 3'b010;  //change: make coin 2 disappear when coin 2 is disabled
		else if (coinDisable[2])
			whichObject <= 3'b011;  //change: make coin 2 disappear when coin 2 is disabled
		else if (step & (gameWon == 0)) 
			whichObject <= 3'b000;  //change: choose pacman if a key is pressed and game is not over yet
		else if (gameWon & (coin1_done | coin2_done | coin3_done))
			whichObject <= 3'b100;  //change: pick game won screen if game is over and the last coin is done disappearing

    // FSM state table
	always @ (*)
		case (y_Q)
			A: if (!ps2_rec) Y_D = A;
            else Y_D = B;
         B: Y_D = C;        // enable scancode register
			C: Y_D = D;        // send step signal to object
			D: if (done == 1'b0) Y_D = D;
				else Y_D = A;
			default: Y_D = A;
      endcase
    // FSM outputs
	always @ (*)
	begin
        // default assignments
		Esc = 1'b0; step = 1'b0;
		case (y_Q)
			A:  ;
			B:  Esc = 1'b1;
			C:  step = 1'b1;  
			D:  ;
        endcase
    end

    // FSM state FFs
	always @(posedge CLOCK_50)
		if (!Resetn)
            y_Q <= A;
		else
            y_Q <= Y_D;

	//change: dummy variables for values we don't need
	wire [7:0] dummyStableX;
	wire [6:0] dummyStableY;

	//change: object one is now pacman drawn at a specific location
	object O1 (Resetn, CLOCK_50, KEY0, object_sel & step, pacman_dir, pacman_x, pacman_y, 
               pacman_color, pacman_write, pacman_done, stableX, stableY);
		defparam O1.RESOLUTION = RESOLUTION;
		defparam O1.LEFT  = 2'b00;  // 'a'
		defparam O1.RIGHT = 2'b11;  // 'd'
		defparam O1.UP    = 2'b01;  // 'w'
		defparam O1.DOWN =  2'b10;  // 's'
		defparam O1.XOFFSET = 47;
		defparam O1.YOFFSET = 73;
      		defparam O1.nX = nX;
		defparam O1.nY = nY;
		defparam O1.COLOR_DEPTH = COLOR_DEPTH;
		defparam O1.INIT_FILE = "./MIF/pacman.mif";

	//change: top left coin
	object O2 (Resetn, CLOCK_50, coinDisable[0], 1'b0, 3'b100, coin1_x, coin1_y, 
               coin1_color, coin1_write, coin1_done, dummyStableX, dummyStableY);
		defparam O2.RESOLUTION = RESOLUTION;
		defparam O2.XOFFSET = 4;
		defparam O2.YOFFSET = 5;
      		defparam O2.nX = nX;
		defparam O2.nY = nY;
		defparam O2.COLOR_DEPTH = COLOR_DEPTH;
		defparam O2.INIT_FILE = "./MIF/black_coin.mif";
	
	//change: top right coin
	object O3 (Resetn, CLOCK_50, coinDisable[1], 1'b0, 3'b100, coin2_x, coin2_y, 
               coin2_color, coin2_write, coin2_done, dummyStableX, dummyStableY);
		defparam O3.RESOLUTION = RESOLUTION;
		defparam O3.XOFFSET = 156;
		defparam O3.YOFFSET = 5;
      		defparam O3.nX = nX;
		defparam O3.nY = nY;
		defparam O3.COLOR_DEPTH = COLOR_DEPTH;
		defparam O3.INIT_FILE = "./MIF/black_coin.mif";
		
	//change: bottom right coin
	object O4 (Resetn, CLOCK_50, coinDisable[2], 1'b0, 3'b100, coin3_x, coin3_y, 
               coin3_color, coin3_write, coin3_done, dummyStableX, dummyStableY);
		defparam O4.RESOLUTION = RESOLUTION;
		defparam O4.XOFFSET = 156;
		defparam O4.YOFFSET = 116;
      		defparam O4.nX = nX;
		defparam O4.nY = nY;
		defparam O4.COLOR_DEPTH = COLOR_DEPTH;
		defparam O4.INIT_FILE = "./MIF/black_coin.mif";
	
	//change: game won screen
	object O5 (Resetn, CLOCK_50, gameWon & (coin1_done | coin2_done | coin3_done), 1'b0, 3'b100, gameWon_x, gameWon_y, 
               gameWon_color, gameWon_write, gameWon_done, dummyStableX, dummyStableY);
		defparam O5.RESOLUTION = RESOLUTION;
		defparam O5.xOBJ = 7;
		defparam O5.yOBJ = 6;
      		defparam O5.nX = nX;
		defparam O5.nY = nY;
		defparam O5.COLOR_DEPTH = COLOR_DEPTH;
		defparam O5.INIT_FILE = "./MIF/gameWon.mif";
	

		//change: add more done signals for each object
		assign done = pacman_done | coin1_done | coin2_done | coin3_done | gameWon_done;

	 //change: these assign statements decide which object (1, 2, 3, 4 or 5) get drawn based on the value of whichObject
		assign MUX_x =
		 (whichObject == 3'b000) ? pacman_x :
		 (whichObject == 3'b001) ? coin1_x :
		 (whichObject == 3'b010) ? coin2_x :
		 (whichObject == 3'b011) ? coin3_x :
		 (whichObject == 3'b100) ? gameWon_x : 1'b0;

		assign MUX_y =
		 (whichObject == 3'b000) ? pacman_y :
		 (whichObject == 3'b001) ? coin1_y :
		 (whichObject == 3'b010) ? coin2_y :
		 (whichObject == 3'b011) ? coin3_y :
		 (whichObject == 3'b100) ? gameWon_y : 1'b0;

		assign MUX_color =
		 (whichObject == 3'b000) ? pacman_color :
		 (whichObject == 3'b001) ? coin1_color :
		 (whichObject == 3'b010) ? coin2_color :
		 (whichObject == 3'b011) ? coin3_color :
		 (whichObject == 3'b100) ? gameWon_color : 1'b0;

		assign MUX_write =
		 (whichObject == 3'b000) ? pacman_write :
		 (whichObject == 3'b001) ? coin1_write :
		 (whichObject == 3'b010) ? coin2_write :
		 (whichObject == 3'b011) ? coin3_write :
		 (whichObject == 3'b100) ? gameWon_write : 1'b0;

    //change: display score on the hex
    hex7seg H0 (score, HEX0);

    // connect to VGA controller
    vga_adapter VGA (
			.resetn(Resetn),
			.clock(CLOCK_50),
			.color(MUX_color),
			.x(MUX_x),
			.y(MUX_y),
			.write(MUX_write),
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK_N(VGA_BLANK_N),
			.VGA_SYNC_N(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = RESOLUTION;
        // choose background image according to resolution and color depth
		defparam VGA.BACKGROUND_IMAGE = "./MIF/maze_with_coins.mif";
		defparam VGA.COLOR_DEPTH = COLOR_DEPTH;

endmodule

// syncronizer, implemented as two FFs in series
module sync(D, Resetn, Clock, Q);
    input wire D;
    input wire Resetn, Clock;
    output reg Q;

    reg Qi; // internal node

    always @(posedge Clock)
        if (Resetn == 0) begin
            Qi <= 1'b0;
            Q <= 1'b0;
        end
        else begin
            Qi <= D;
            Q <= Qi;
        end
endmodule

// n-bit register with enable
module regn(R, Resetn, E, Clock, Q);
    parameter n = 8;
    input wire [n-1:0] R;
    input wire Resetn, E, Clock;
    output reg [n-1:0] Q;

    always @(posedge Clock)
        if (!Resetn)
            Q <= 0;
        else if (E)
            Q <= R;
endmodule

//change: pulse module to emulate a key press
module pulse (Clock, Resetn, Enable, Q);
	input wire Clock, Resetn, Enable;
	output wire Q;
	reg out, prevEnable;

	always @ (posedge Clock)
	begin
		if (!Resetn)
		begin
			prevEnable <= 1'b0;
			out <= 1'b0;
		end
		else
		begin
			out <= Enable & ~prevEnable;
			prevEnable <= Enable;
		end
	end
	assign Q = out;
endmodule

//n-bit up/down-counter with reset, load, enable, and direction control
module upDn_count (R, Clock, Resetn, L, E, Dir, Res, Q);
   	//same inputs as the demo updown counter
	parameter n = 8;
   	input wire [7:0] Res; //Ireen: New Res input
   	input wire [n-1:0] R;
   	input wire Clock, Resetn, E, L;
	input wire [1:0]Dir;
   	output reg [n-1:0] Q;

	//change: everything written below in this module is new
	//this counter handles pacman moving past the screen edges as well
   	reg [7:0] next_Q;

   	always @(*) 
	begin
		next_Q = Q;  //default

      		if (E) 
		begin
			if (Dir == 2'b01) 
				begin
				//moving down or right
					if (Q == 8'd163 & Res == 8'd160)
						next_Q = 8'd253;       //wrap around to start
					else if (Q == 8'd122 & Res == 8'd120)
						next_Q = 8'd253; 
					else
						next_Q = Q + 1'b1;
				end 
			else if (Dir == 2'b10)
				begin
				//moving up or left
					if (Q == 8'd253 & Res == 8'd160)
						next_Q = Res + 3;     //wrap around to end
					else if (Q == 8'd252 & Res == 8'd120) 
						next_Q = 8'd122;
					else
						next_Q = Q - 1'b1;
					end
		 end
	end
	
	//load the right value of Q on Reset
	always @(posedge Clock) begin
		if (!Resetn)
			Q <= 8'd0;
		else if (L)
			Q <= R;
		else
			Q <= next_Q;
	end
endmodule

module hex7seg (hex, display);
    input wire [1:0] hex;
    output reg [6:0] display;

    /*
     *       0  
     *      ---  
     *     |   |
     *    5|   |1
     *     | 6 |
     *      ---  
     *     |   |
     *    4|   |2
     *     |   |
     *      ---  
     *       3  
     */

//change: made hex only display from 0 to 3 and made input a 2 bit value
    always @ (hex)
        case (hex)
            2'h0: display = 7'b1000000;
            2'h1: display = 7'b1111001;
            2'h2: display = 7'b0100100;
            2'h3: display = 7'b0110000;
        endcase
endmodule

// implements a movable object
module object (Resetn, Clock, go, ps2_rec, dir, VGA_x, VGA_y, VGA_color, VGA_write, done, stableX, stableY);
	parameter RESOLUTION = "160x120"; // "640x480" "320x240" "160x120"
    	// specify the number of bits needed for an X (column) pixel coordinate on the VGA display
	parameter nX = 8;
    	// specify the number of bits needed for a Y (row) pixel coordinate on the VGA display
   	parameter nY = 7;
   	parameter COLOR_DEPTH = 3;
    	// by default, use offsets to center the object on the VGA display
   	parameter XOFFSET = 80;
   	parameter YOFFSET = 60;
   	parameter LEFT = 3'b000 /*'d'*/, RIGHT = 3'b011/*'a'*/, UP = 3'b001/*'w'*/, DOWN = 3'b010/*'s'*/;

	//change: set object size to 3 because pacman is a 8x8 mif (so are most of the other objects)
   	parameter xOBJ = 3, yOBJ = 3;   // object size is 2^xOBJ x 2^yOBJ
   	parameter BOX_SIZE_X = 1 << xOBJ;
   	parameter BOX_SIZE_Y = 1 << yOBJ;
   	parameter Mn = xOBJ + yOBJ; // address lines needed for the object memory
    

    // state names for the FSM that draws the object
   	parameter A = 3'b000, B = 3'b001, C = 3'b010, D = 3'b011, E = 3'b100,
              F = 3'b101, G = 3'b110, H = 3'b111;
    
   	input wire Resetn, Clock;
   	input wire go;                              // can be used to draw at initial position
   	input wire ps2_rec;                         // PS2 data received
   	input wire [2:0] dir;                       // movement direction
	output wire [nX-1:0] VGA_x;                 // for syncing with object memory
	output wire [nY-1:0] VGA_y;                 // for syncing with object memory

   	output wire [nX-1:0] stableX;  //change: top-left X (not used for drawing)
   	output wire [nY-1:0] stableY;  //change: top-left Y (not used for drawing)

	output wire [COLOR_DEPTH-1:0] VGA_color;    // used to draw pixels
   	output wire VGA_write;                      // pixel write control
   	output reg done;                            // done drawing cycle

	wire [nX-1:0] X, X0;    // starting X location 
	wire [nY-1:0] Y, Y0;    // starting Y location 
	wire [nX-1:0] size_x = BOX_SIZE_X;   // store the X size (must be power of 2)
	wire [nY-1:0] size_y = BOX_SIZE_Y;   // store the Y size
   	wire [xOBJ-1:0] XC;                  // used to access object memory
   	wire [yOBJ-1:0] YC;                  // used to access object memory
   	reg write, Lxc, Lyc, Exc, Eyc;       // object control signals
   	reg erase;                           // erase/draw object
   	wire Right, Left, Up, Down;          // object direction
   	reg Lx, Ly, Ex, Ey;                  // object counter controls
   	reg [2:0] y_Q, Y_D;                  // FSM
    
	wire [COLOR_DEPTH-1:0] obj_color;    // object pixel colors, read from memory
	
    // object (x,y) location. For x, counter will be enabled when moving L/R, increment
    // for R, decrement for L. For y, counter will be enabled when moving U/D, increment 
    // for D, decrement for U
		
	 
   	assign X0 = XOFFSET;
   	assign Y0 = YOFFSET;

   	assign Left = (dir == LEFT);
    	assign Right = (dir == RIGHT);
    	assign Up = (dir == UP);
    	assign Down = (dir == DOWN);
	 
	//change: create new direction registers that allows for pacman to never move if the wrong key is pressed (not WASD)
	reg [1:0]Direc;
	wire [1:0] Dir;
	 
	always @ (*)
		if (Right == 1 | Down == 1) 
			Direc = 2'b01;
		else if (Left == 1| Up == 1)
			Direc = 2'b10;
		else 
			Direc = 2'b00;
	assign Dir = Direc;

    	// these signals are used to enable the (x,y) object location counters and to make these 
   	// counters increment or decrement

	//change: sends this new direction into its movement counters
   	upDn_count UX (X0, Clock, Resetn, Lx, Ex, Dir, 8'd160, X);  
		defparam UX.n = nX;
	upDn_count UY (Y0, Clock, Resetn, Ly, Ey, Dir, 8'd120, Y);
		defparam UY.n = nY;

    // these counter are used to generate (x,y) coordinates to read the object's pixels
	upDn_count U3 ({xOBJ{1'd0}}, Clock, Resetn, Lxc, Exc, 2'd1, 8'd160, XC); // object column counter
		defparam U3.n = xOBJ;
	upDn_count U4 ({yOBJ{1'd0}}, Clock, Resetn, Lyc, Eyc, 2'd1, 8'd120, YC); // object row counter
		defparam U4.n = yOBJ;


			
	//change: default parameter mif is now pacman
	parameter INIT_FILE = "./MIF/pacman.mif";

    // FSM state table 110
	always @ (*)
		case (y_Q)
			A: Y_D = B;                        // load (x,y) location counters
        		B: if (go) Y_D = F;                // pushbutton KEY pressed to show object
				else if (ps2_rec) Y_D = C; // PS2 key received to move object
            			else Y_D = B;              // wait
         		C: if (XC != size_x-1) Y_D = C;    // erase row of object
            			else Y_D = D;
         		D: if (YC != size_y-1) Y_D = C;    // next row of object to erase
				else Y_D = E;              // done erase cycle
			E: Y_D = F;                        // +/- (x,y)
			F: if (XC != size_x-1) Y_D = F;    // draw row of object
				else Y_D = G;
			G: if (YC != size_y-1) Y_D = F;    // next row of object to draw
				else Y_D = H;              // done draw cycle
			H: if (go) Y_D = H;                // wait for KEY press
				else Y_D = B;
			default: Y_D = A;
		endcase
    // FSM outputs
    always @ (*)
    begin
        // default assignments
        Lx = 1'b0; Ly = 1'b0; Ex = 1'b0; Ey = 1'b0; write = 1'b0; 
        Lxc = 1'b0; Lyc = 1'b0; Exc = 1'b0; Eyc = 1'b0; erase = 1'b0; done = 1'b0;
        case (y_Q)
            A:  begin Lx = 1'b1; Ly = 1'b1; end                   // load (X,Y) counters
            B:  begin Lxc = 1'b1; Lyc = 1'b1; end                 // load (XC,YC) counters
            C:  begin Exc = 1'b1; write = 1'b1; erase = 1'b1; end // enable XC, write pixel
            D:  begin Lxc = 1'b1; Eyc = 1'b1; erase = 1'b1; end   // load XC, enable YC
            // state E is reached after erasing the object. Now, move and draw the object
            E:  begin Ex = Right | Left; Ey = Up | Down; end      // move L/R or U/D
            F:  begin Exc = 1'b1; write = 1'b1; end               // enable XC, write pixel
            G:  begin Lxc = 1'b1; Eyc = 1'b1; end                 // load XC, enable YC
            H:  done = 1'b1;
        endcase
    end

    // FSM state FFs
    always @(posedge Clock)
        if (!Resetn)
            y_Q <= 3'b0;
        else
            y_Q <= Y_D;

    // read a pixel color from the object memory. We can use {YC,XC} because the x dimension
    // of the object memory is a power of 2
    object_mem U6 ({YC,XC}, Clock, obj_color);
        defparam U6.n = COLOR_DEPTH;
        defparam U6.Mn = xOBJ + yOBJ;
        defparam U6.INIT_FILE = INIT_FILE;

    // compute the (x,y) location of the current pixel to be drawn (or erased). We subtract
    // half the object's width and height because we want the object to be centered at its 
    // original (x,y) location. We add (Xc,YC) to form the correct address of the pixel. The
    // object memory takes one clock cycle to provide data, so we register the computed (x,y)
    // location to remain synchronized
    regn U7 (X - (size_x >> 1) + XC, Resetn, 1'b1, Clock, VGA_x);
        defparam U7.n = nX;
    regn U8 (Y - (size_y >> 1) + YC, Resetn, 1'b1, Clock, VGA_y);
        defparam U8.n = nY;

    //change: created the exact same configuration as VGA_x and VGA_y but these are not being sent to be drawn the the VGA
    //change: stableX and stableY are only used for coin collisions
    regn U11 (X - (size_x >> 1), Resetn, 1'b1, Clock, stableX);
	defparam U11.n = nX;
    regn U10 (Y - (size_y >> 1), Resetn, 1'b1, Clock, stableY);
	defparam U10.n = nY;

    // synchronize write signal with VGA_x, VGA_y, VGA_color 
    regn U9 (write, Resetn, 1'b1, Clock, VGA_write);
        defparam U9.n = 1;

    // use the background color (when erasing), or the object color when drawing
    // (black background is assumed below)
    assign VGA_color = erase ? {COLOR_DEPTH{1'b0}} : obj_color;

endmodule