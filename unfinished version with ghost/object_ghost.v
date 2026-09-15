
//this module is exactly the same as the regular object module with one difference in which there is an enable with ps2_rec in the FSM state table

module object_ghost (Resetn, Clock, go, ps2_rec, dir, VGA_x, VGA_y, VGA_color, VGA_write, done, stableX, stableY);
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
   
	//CHANGE
	//----------------------------------------------------------------------------------------
		wire enable;
		half_second_count HSC(Clock, Resetn, enable);
	//-----------------------------------------------------------------------------------------

    // state names for the FSM that s the object
   	parameter A = 3'b000, B = 3'b001, C = 3'b010, D = 3'b011, E = 3'b100,
              F = 3'b101, G = 3'b110, H = 3'b111;
    
   	input wire Resetn, Clock;
   	input wire go;                              // can be used to draw at initial position
   	input wire ps2_rec;                         // PS2 data received
   	input wire [2:0] dir;                       // movement direction
	output wire [nX-1:0] VGA_x;                 // for syncing with object memory
	output wire [nY-1:0] VGA_y;                 // for syncing with object memory
   	output wire [nX-1:0] stableX;  // top-left X (not used for drawing)
   	output wire [nY-1:0] stableY;  // top-left Y (not used for drawing)
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

   	upDn_count UX (X0, Clock, Resetn, Lx, Ex, Dir, 8'd160, X);  
		defparam UX.n = nX;
	upDn_count UY (Y0, Clock, Resetn, Ly, Ey, Dir, 8'd120, Y);
		defparam UY.n = nY;

    // these counter are used to generate (x,y) coordinates to read the object's pixels
	upDn_count U3 ({xOBJ{1'd0}}, Clock, Resetn, Lxc, Exc, 2'd1, 8'd160, XC); // object column counter
		defparam U3.n = xOBJ;
	upDn_count U4 ({yOBJ{1'd0}}, Clock, Resetn, Lyc, Eyc, 2'd1, 8'd120, YC); // object row counter
		defparam U4.n = yOBJ;

    // these signals are used to enable the (x,y) object location counters and to make these 
    // counters increment or decrement
			
	//Ireen: deleted assignment of parameter for object file
	parameter INIT_FILE = "./MIF/pacman.mif";

    // FSM state table 110
	always @ (*)
		case (y_Q)
			A: Y_D = B;                        // load (x,y) location counters
         		B: if (go) Y_D = F;                // pushbutton KEY pressed to show object
				else if (ps2_rec & enable) Y_D = C;      // PS2 key received to move object (change: added an enable to slow down ghost movement)
            			else Y_D = B;                   // wait
         		C: if (XC != size_x-1) Y_D = C;    // erase row of object
            			else Y_D = D;
         		D: if (YC != size_y-1) Y_D = C;    // next row of object to erase
				else Y_D = E;                   // done erase cycle
			E: Y_D = F;                        // +/- (x,y)
			F: if (XC != size_x-1) Y_D = F;    // draw row of object
				else Y_D = G;
			G: if (YC != size_y-1) Y_D = F;    // next row of object to draw
				else Y_D = H;                   // done draw cycle
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
    regn U11 (X - (size_x >> 1), Resetn, 1'b1, Clock, stableX);
	defparam U11.n = nX;
    regn U10 (Y - (size_y >> 1), Resetn, 1'b1, Clock, stableY);
	defparam U10.n = nY;

    regn U7 (X - (size_x >> 1) + XC, Resetn, 1'b1, Clock, VGA_x);
        defparam U7.n = nX;
    regn U8 (Y - (size_y >> 1) + YC, Resetn, 1'b1, Clock, VGA_y);
        defparam U8.n = nY;

    // synchronize write signal with VGA_x, VGA_y, VGA_color 
    regn U9 (write, Resetn, 1'b1, Clock, VGA_write);
        defparam U9.n = 1;

    // use the background color (when erasing), or the object color when drawing
    // (black background is assumed below)
    assign VGA_color = erase ? {COLOR_DEPTH{1'b0}} : obj_color;

endmodule