module collision_checker(Clock, Resetn, PacmanX, PacmanY, coinEnable, moveEnable, score, stableX, stableY);
	input Clock, Resetn;
	input [7:0] PacmanX, stableX;
	input [6:0] PacmanY, stableY; //Represents pacman's coordinates (xPos, xPos + width, yPos, yPos + height)
	
	output reg [2:0] coinEnable; //Whether each coin1, coin2, coin3 should be drawn to the screen
	output reg [1:0] score;

	
	output reg [3:0] moveEnable; //0 = up, 1 = down, 2 = left, 3 = right
	
	wire [7:0] pacmanX, pacmanX_1, stableX1;
	wire [6:0] pacmanY, pacmanY_1, stableY1; 

	assign pacmanX = PacmanX;
	assign pacmanX_1 = pacmanX + 4'd7; //pacman's rightmost coordinate
	assign stableX1 = stableX + 4'd7;
	
	assign pacmanY = PacmanY;
	assign pacmanY_1 = pacmanY + 4'd7; //pacman's bottommost coordinate
	assign stableY1 = stableY + 4'd7;
	
	//parameters representing coin location
	parameter coin1X = 8'd3, coin1X_1 = 8'd7, coin1Y = 7'd4, coin1Y_1 = 7'd8, coin2X = 8'd152, coin2X_1 = 8'd156, coin2Y = 7'd4, coin2Y_1 = 7'd8,
				 coin3X = 8'd152, coin3X_1 = 8'd156, coin3Y = 7'd112, coin3Y_1 = 7'd116;
	
	//parameters representing maze wall location
	parameter maze1X = 8'd18, maze1X_1 = 8'd47, maze1Y = 7'd19, maze1Y_1 = 7'd115, maze2X = 8'd59, maze2X_1 = 8'd155, maze2Y = 7'd19, maze2Y_1 = 7'd73,
				 maze3X = 8'd59, maze3X_1 = 8'd155, maze3Y = 7'd85, maze3Y_1 = 7'd115;
		
	//wires to check if a coin has been collided with (1 if yes, 0 if no)
	wire colCoin1, colCoin2, colCoin3;
	
	coin_collision_checker U1(stableX, stableX1, stableY, stableY1, coin1X, coin1X_1, coin1Y, coin1Y_1, colCoin1);
	coin_collision_checker U2(stableX, stableX1, stableY, stableY1, coin2X, coin2X_1, coin2Y, coin2Y_1, colCoin2);
	coin_collision_checker U3(stableX, stableX1, stableY, stableY1, coin3X, coin3X_1, coin3Y, coin3Y_1, colCoin3);
	
	//wires to check if any part of the maze walls have been collided with (up, left, right, down)
	//three wires because theres three bounding boxes
	wire [3:0] maze1Col, maze2Col, maze3Col;
	
	maze_left_collision U4(pacmanX, pacmanX_1, pacmanY, pacmanY_1, maze1X, maze1X_1, maze1Y, maze1Y_1, maze1Col[3]);
	maze_left_collision U5(pacmanX, pacmanX_1, pacmanY, pacmanY_1, maze2X, maze2X_1, maze2Y, maze2Y_1, maze2Col[3]);
	maze_left_collision U6(pacmanX, pacmanX_1, pacmanY, pacmanY_1, maze3X, maze3X_1, maze3Y, maze3Y_1, maze3Col[3]);
	
	maze_right_collision U7(pacmanX, pacmanX_1, pacmanY, pacmanY_1, maze1X, maze1X_1, maze1Y, maze1Y_1, maze1Col[2]);
	maze_right_collision U8(pacmanX, pacmanX_1, pacmanY, pacmanY_1, maze2X, maze2X_1, maze2Y, maze2Y_1, maze2Col[2]);
	maze_right_collision U9(pacmanX, pacmanX_1, pacmanY, pacmanY_1, maze3X, maze3X_1, maze3Y, maze3Y_1, maze3Col[2]);
	
	maze_top_collision U10(pacmanX, pacmanX_1, pacmanY, pacmanY_1, maze1X, maze1X_1, maze1Y, maze1Y_1, maze1Col[1]);
	maze_top_collision U11(pacmanX, pacmanX_1, pacmanY, pacmanY_1, maze2X, maze2X_1, maze2Y, maze2Y_1, maze2Col[1]);
	maze_top_collision U12(pacmanX, pacmanX_1, pacmanY, pacmanY_1, maze3X, maze3X_1, maze3Y, maze3Y_1, maze3Col[1]);
	
	maze_bottom_collision U13(pacmanX, pacmanX_1, pacmanY, pacmanY_1, maze1X, maze1X_1, maze1Y, maze1Y_1, maze1Col[0]);
	maze_bottom_collision U14(pacmanX, pacmanX_1, pacmanY, pacmanY_1, maze2X, maze2X_1, maze2Y, maze2Y_1, maze2Col[0]);
	maze_bottom_collision U15(pacmanX, pacmanX_1, pacmanY, pacmanY_1, maze3X, maze3X_1, maze3Y, maze3Y_1, maze3Col[0]);
	
	//check collision with pacman and coins, maze walls
	reg colCoin1_d, colCoin2_d, colCoin3_d;

	//only set coinEnable to zero of the coin has been disabled for two clock cycles
	//increment score by one if a coin is collided with
	always@(posedge Clock)
	begin
		colCoin1_d <= colCoin1;
		colCoin2_d <= colCoin2;
		colCoin3_d <= colCoin3;
	end

	always@(posedge Clock)
	begin
		//reset
		if (!Resetn)
			begin
				//set default values
				coinEnable <= 3'b111;
				score <= 0;
				moveEnable <= 4'b0000;
			end
		else
		begin
		//coin 1
		if (colCoin1 & colCoin1_d)
			if (coinEnable[0])
			begin
				score <= score + 1;
				coinEnable[0] <= 0;
			end
			
		//coin 2
		if (colCoin2 & colCoin2_d)
			if (coinEnable[1])
			begin
				score <= score + 1;
				coinEnable[1] <= 0;
			end
			
		//coin 3
		if (colCoin3 & colCoin3_d)
			if (coinEnable[2])
			begin
				score <= score + 1;
				coinEnable[2] <= 0;
			end
			
			
		//assume Pacman moves at a speed of 1 px	
		//set enable for movement based on collision with maze walls
		//if moveEnable == 0, then pacman can't move in that direction
		
		//top
		moveEnable[0] <= ~(maze1Col[0] | maze2Col[0] | maze3Col[0]);
		//tottom
		moveEnable[1] <= ~(maze1Col[1] | maze2Col[1] | maze3Col[1]);
		//left side
		moveEnable[2] <= ~(maze1Col[2] | maze2Col[2] | maze3Col[2]);
		//right side
		moveEnable[3] <= ~(maze1Col[3] | maze2Col[3] | maze3Col[3]);
		end
	end
	
endmodule

//this module does the if statement for the collision with a coin, result = 1 when colliding and 0 otherwise
module coin_collision_checker(pacmanX, pacmanX_1, pacmanY, pacmanY_1, coinX, coinX_1, coinY, coinY_1, result);
	
	input [7:0] pacmanX, pacmanX_1, coinX, coinX_1;
	input [6:0]pacmanY, pacmanY_1, coinY, coinY_1; 
	output result;
	wire collidesLeft, collidesRight, collidesUp, collidesDown;

	assign collidesRight = (coinX_1 + 1'b1 == pacmanX) & (pacmanY_1 >= coinY) & (pacmanY <= coinY_1);
	assign collidesLeft = (coinX - 1'b1 == pacmanX_1) & (pacmanY_1 >= coinY) & (pacmanY <= coinY_1);
	assign collidesUp = (coinY_1 + 1'b1 == pacmanY) & (pacmanX <= coinX_1) & (pacmanX_1 >= coinX);
	assign collidesDown = (coinY - 1'b1 == pacmanY_1) & (pacmanX <= coinX_1) & (pacmanX_1 >= coinX);
	
	assign result = collidesLeft | collidesRight | collidesUp | collidesDown;
	
endmodule

//this module outputs 1 if pacman collides with the LEFT side of a maze wall
module maze_left_collision(pacmanX, pacmanX_1, pacmanY, pacmanY_1, mazeX, mazeX_1, mazeY, mazeY_1, result);
	input [7:0] pacmanX, pacmanX_1, mazeX, mazeX_1;
	input [6:0] pacmanY, pacmanY_1, mazeY, mazeY_1; 
	output result;
	
	assign result = (pacmanX_1 == mazeX - 1'b1) & (pacmanY_1 >= mazeY) & (pacmanY <= mazeY_1);
endmodule

//this module outputs 1 if pacman collides with the RIGHT side of a maze wall
module maze_right_collision(pacmanX, pacmanX_1, pacmanY, pacmanY_1, mazeX, mazeX_1, mazeY, mazeY_1, result);
	input [7:0] pacmanX, pacmanX_1, mazeX, mazeX_1;
	input [6:0] pacmanY, pacmanY_1, mazeY, mazeY_1; 
	output result;
	
	assign result = (pacmanX == mazeX_1 + 1'b1) & (pacmanY_1 >= mazeY) & (pacmanY <= mazeY_1);
endmodule

//this module outputs 1 if pacman collides with the TOP side of a maze wall
module maze_top_collision(pacmanX, pacmanX_1, pacmanY, pacmanY_1, mazeX, mazeX_1, mazeY, mazeY_1, result);
	input [7:0] pacmanX, pacmanX_1, mazeX, mazeX_1;
	input [6:0] pacmanY, pacmanY_1, mazeY, mazeY_1; 
	output result;
	
	assign result = (pacmanY_1 == mazeY - 1'b1) & (pacmanX_1 >= mazeX) & (pacmanX <= mazeX_1);
endmodule

//this module outputs 1 if pacman collides with the BOTTOm side of a maze wall
module maze_bottom_collision(pacmanX, pacmanX_1, pacmanY, pacmanY_1, mazeX, mazeX_1, mazeY, mazeY_1, result);
	input [7:0] pacmanX, pacmanX_1, mazeX, mazeX_1;
	input [6:0] pacmanY, pacmanY_1, mazeY, mazeY_1; 
	output result;
	
	assign result = (pacmanY == mazeY_1 + 1'b1) & (pacmanX_1 >= mazeX) & (pacmanX <= mazeX_1);
endmodule