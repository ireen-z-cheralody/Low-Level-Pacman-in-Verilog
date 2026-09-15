
//this module takes the coordinates of pacman and the ghost and it outputs 1 if they are colliding. if not colliding, outputs 0
module ghost_pacman_collision_checker(pacmanX, pacmanY, ghostX, ghostY, result);
	input [7:0] pacmanX, ghostX;
	input [6:0] pacmanY, ghostY;
	output result;
	
	wire [7:0] pacmanX_1, ghostX_1;
	wire [6:0] pacmanY_1, ghostY_1;
	
	assign pacmanX_1 = pacmanX + 8'd7;
	assign ghostX_1 = ghostX + 8'd7;
	assign pacmanY_1 = pacmanY + 7'd7;
	assign ghostY_1 = ghostY + 7'd7;
	
	wire verticalOverlap, horizontalOverlap;
	
	assign verticalOverlap = (pacmanY_1 >= ghostY) & (pacmanY <= ghostY_1);
	assign horizontalOverlap = (pacmanX_1 >= ghostX) & (pacmanX <= ghostX_1);
	
	assign result = verticalOverlap & horizontalOverlap;
	
endmodule