module half_second_count(Clock, Resetn, z);
//labeled half second count but actually counts to 10 million which is faster
//this module will slow down the clock input for the ghost
	input Clock, Resetn;
	reg [24:0]Q;
	output reg z;
	
	always@(posedge Clock)
		if (!Resetn | Q == 25'd10000000) //Change from d2 to d25000000 for the board
		begin
			Q <= 25'd0;
			z = 1;
		end
		else
		begin
			Q <= Q + 1;
			z = 0;
		end
			
endmodule