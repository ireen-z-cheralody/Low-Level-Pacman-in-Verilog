//this module takes the ghost's current position as input and outputs the direction it should move in

module ghost_mover(Clock, Resetn, currentX, currentY, moveUp, moveDown, moveLeft, moveRight, KEY);
	input Clock, Resetn, KEY;
	input [7:0] currentX;
	input [6:0] currentY;
	
	output reg moveUp, moveDown, moveLeft, moveRight;
	reg cycle; //controls which path ghost should take when reaching P1 (it can either move towards P2 or P7)
	
	//parameters hold turning points (the ghost should turn when it reaches this position)
	parameter P1_X = 8'd150, P1_Y = 7'd68, P2_X = 8'd43, P2_Y = 7'd68, P3_X = 8'd43, P3_Y = 7'd110, 
					P4_X = 8'd2, P4_Y = 7'd110,
					P5_X = 8'd2, P5_Y = 7'd68, P6_X = 8'd152, P6_Y = 7'd112, P7_X = 8'd152, P7_Y = 7'd4;
	
	wire [0:6] atP;
	
	//used for ModelSim testing to confirm that the code registers when the ghost hits a point where it needs to change direction
	//(same conditions as the if statements)
	assign atP = {currentX == P1_X & currentY == P1_Y, currentX == P2_X & currentY == P2_Y, currentX == P3_X & currentY == P3_Y,
			currentX == P4_X & currentY == P4_Y, currentX == P5_X & currentY == P5_Y, currentX == P6_X & currentY == P6_Y,
			currentX == P7_X & currentY == P7_Y};
	
	always@(posedge Clock)
		//reset to default values
		if (!Resetn)
			begin
				moveUp <= 0;
				moveDown <= 0;
				moveLeft <= 0;
				moveRight <= 0;
		
				cycle <= 1;
			end
		else
				
			//check if the ghost should change direction
			//use if statements over case statements to check against two values 
				if (KEY)
				begin
					moveLeft <= 1;
					moveRight <= 0;
				end
			else if (currentX == P2_X & currentY == P2_Y)
				begin
					moveLeft <= 0;
					moveUp <= 1;
					cycle <= 0;
				end
			else if (currentX == P3_X & currentY == P3_Y)
				begin
					moveUp <= 0;
					moveLeft <= 1;
				end
			else if (currentX == P4_X & currentY == P4_Y)
				begin
					moveUp <= 1;
					moveLeft <= 0;
				end
			else if (currentX == P5_X & currentY == P5_Y)
				begin
					moveLeft <= 1;
					moveUp <= 0;
				end
	
endmodule