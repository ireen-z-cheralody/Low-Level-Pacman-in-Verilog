module flipper_7cycle(Clock, Resetn, out);
//named 7 cycle but actually flips every two cycles
//goes 0 then 1 then 0 then 1 again

	input Clock, Resetn;
	output reg out;
	
	reg count;
	
	always@(posedge Clock)
		if (!Resetn)
			begin
			count <= 1'd0;
			out <= 1'b1;
			end
		else
			begin
			if (count == 1'b1)
				out <= ~out;
			
			count <= count + 1'd1;
			end
	
endmodule