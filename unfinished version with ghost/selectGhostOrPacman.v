//module for an arbtiter that would pick between ghost and pacman to be drawn but ended up not working/couldn't implement properly

module selectGhostOrPacman(CLOCK_50, Resetn, step, pacDone, ghostDone, selectGhost, selectPacman, state);
	input CLOCK_50, Resetn;
	input pacDone, ghostDone; //the done signals are 1 when the object has finished drawing
	input step; //step indicates a key is being pressed --> can be viewed as Pacman wanting to move
					//(as the ghost moves all the time, there is no need for an additional signal)
	output reg selectGhost, selectPacman;
	output [2:0] state;
	
	reg lastObject; //0 = ghost, 1 = pacman
	
	//If Pacman wants to draw, we need to switch between selecting ghost and pacman
	//Meaning: as soon as ghost is finished drawing, select Pacman. As soon as pacman is finished drawing, select ghost
	
	//Otherwise, ghost is always selected
	
	
	//States
	parameter A = 3'd0, B = 3'd1, C = 3'd2, D = 3'd3, E = 3'd4;
	
	reg [2:0] currentState, nextState;
	
	assign state = currentState;
	
	always@(*)
		case (currentState)
			A:begin 
				if (step) nextState <= B;
				else if (!step) nextState <= C;
				else nextState <= A;
				
				selectPacman <= 0;
				selectGhost <= 0;
			   end
			
			B: begin
				selectPacman <= 1;
				selectGhost <= 0;
				
				if (pacDone)
					nextState <= D;
				else
					nextState <= B;
				end
			
			C: begin
				selectPacman <= 0;
				selectGhost <= 1;
				
				if (ghostDone)
					nextState <= E;
				else
					nextState <= C;
				end
			
			D: begin
				selectPacman <= 0;
				selectGhost <= 0;
				nextState <= C;
				end
				
			E: begin
				selectPacman <= 0;
				selectGhost <= 0;
				
				if (step)
					nextState <= B;
				else
					nextState <= C;
				end
			endcase
					
	always@(posedge CLOCK_50)
		if (!Resetn)
		begin
			currentState <= A;
		end
		else
			currentState <= nextState;
endmodule
				
				