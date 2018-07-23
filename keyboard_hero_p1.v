module keyboard_hero_p1(CLOCK_50, KEY, LEDR, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6);
	input CLOCK_50;
	input [3:0] KEY;
	input [9:0] LEDR;
	output [6:0] HEX0;
	output [6:0] HEX1;
	output [6:0] HEX2;
	output [6:0] HEX3;
	output [6:0] HEX4;
	output [6:0] HEX5;
	output [6:0] HEX6;
	
	wire go;
	assign go = ~KEY[0];
	
	wire [4:0] timer;
	wire resetn;
	wire rate_divide_enable;
	wire LED_gen_enable;
	wire [3:0] timer_10s_digit;
	wire [3:0] timer_1s_digit;
	wire [3:0] led_wires;
	
	control c0(
		.clk(CLOCK_50),
		.go(go),
		.timer(timer),
		.resetn(resetn),
		.rate_divide_enable(rate_divide_enable),
		.LED_gen_enable(LED_gen_enable)
	);
	
	datapath d0(
		.clk(CLOCK_50),
		.resetn(resetn),
		.rate_divide_enable(rate_divide_enable),
		.LED_gen_enable(LED_gen_enable),
		.timer(timer),
		.timer_10s_digit(timer_10s_digit),
		.timer_1s_digit(timer_1s_digit),
		.led_wires(led_wires)
	);
	
	// Light up the LED(s) that are supposed to be lit up
	display_LED led_3_0(
		.display(led_wires),
		.LEDs(LEDR[3:0])
	);
	
	// Display the 1's digit of the countdown timer on HEX2
	// u is the LSB and x is the MSB
	display_HEX hex_2(
		.u(timer_1s_digit[0]),
		.v(timer_1s_digit[1]),
		.w(timer_1s_digit[2]),
		.x(timer_1s_digit[3]),
		.m(HEX2)
	);
	
	// Display the 10's digit of the countdown timer on HEX3
	display_HEX hex_3(
		.u(timer_10s_digit[0]),
		.v(timer_10s_digit[1]),
		.w(timer_10s_digit[2]),
		.x(timer_10s_digit[3]),
		.m(HEX3)
	);
endmodule

module control(clk, go, timer, resetn, rate_divide_enable, LED_gen_enable);
	input clk;
	input go;
	input [4:0] timer;
	output resetn;
	output rate_divide_enable;
	output LED_gen_enable;
	
	reg resetn;
	reg rate_divide_enable;
	reg LED_gen_enable;
	reg [2:0] current_state; 
	reg [2:0] next_state; 
	
	localparam  S_RESET_GAME		  = 4'd0,
                S_RESET_GAME_WAIT	= 4'd1,
                S_BEGIN_GAME			= 4'd2,
                S_BEGIN_GAME_WAIT	= 4'd3,
                S_PLAY_GAME			= 4'd4,
                S_END_GAME				= 4'd5,
					 S_END_GAME_WAIT		= 4'd6;
					 
    // Next state logic aka our state table
    always @(*)
    begin: state_table 
            case (current_state)
                S_RESET_GAME: next_state = go ? S_RESET_GAME_WAIT : S_RESET_GAME; // Loop in current state until go signal goes high
                S_RESET_GAME_WAIT: next_state = go ? S_RESET_GAME_WAIT : S_BEGIN_GAME; // Loop in current state until go signal goes low
                S_BEGIN_GAME: next_state = go ? S_BEGIN_GAME_WAIT : S_BEGIN_GAME; // Loop in current state until go signal goes high
                S_BEGIN_GAME_WAIT: next_state = go ? S_BEGIN_GAME_WAIT : S_PLAY_GAME; // Loop in current state until go signal goes low
                S_PLAY_GAME: next_state = (timer == 5'd0) ? S_END_GAME : S_PLAY_GAME; // Loop in current state until timer is 0
                S_END_GAME: next_state = go ? S_END_GAME_WAIT : S_END_GAME; // Loop in current state until go signal goes high
					 S_END_GAME_WAIT: next_state = go ? S_END_GAME_WAIT : S_RESET_GAME; // Loop in current state until go signal goes low
            default: next_state = S_RESET_GAME; // S_RESET_GAME is initial state
        endcase
    end // state_table
	 
	 // Output logic aka all of our datapath control signals
    always @(*)
    begin: enable_signals
        // By default make all our signals 0
        resetn = 1'b0; // reset signal
        rate_divide_enable = 1'b0; // signal to allow rate divider to begin
        LED_gen_enable = 1'b0; // signal to allow LEDs to light up

        case (current_state)
            S_RESET_GAME: begin
                resetn = 1'b1;
            end
            S_PLAY_GAME: begin
                rate_divide_enable = 1'b1;
					 LED_gen_enable = 1'b1;
            end
        endcase
    end // enable_signals
	 
	 // current_state registers
    always @(posedge clk)
    begin: state_FFs
	     current_state <= next_state;
    end // state_FFS
endmodule

module datapath(clk, resetn, rate_divide_enable, LED_gen_enable, timer, timer_10s_digit, timer_1s_digit, led_wires);
	input clk;
	input resetn;
	input rate_divide_enable;
	input LED_gen_enable;
	output [4:0] timer;
	output [3:0] timer_10s_digit;
	output [3:0] timer_1s_digit;
	output [3:0] led_wires;
	
	wire timer_enable_out;
	wire [6:0] random_num;
	
	rate_divider rd0(
		.clk(clk),
		.rate_divide_enable(rate_divide_enable),
		.resetn(resetn),
		.timer_enable(timer_enable_out)
	);
	
	countdown_timer ct0(
		.timer_enable(timer_enable_out),
		.resetn(resetn),
		.timer(timer),
		.timer_10s_digit(timer_10s_digit),
		.timer_1s_digit(timer_1s_digit)
	);
	
	random_num_generator rng0(
		.rng_enable(timer_enable_out),
		.resetn(resetn),
		.random_num(random_num)
	);
	
	LED_generator lg0(
		.LED_gen_enable(LED_gen_enable),
		.resetn(resetn),
		.random_num(random_num),
		.led_wires(led_wires)
	);
endmodule

module rate_divider(clk, rate_divide_enable, resetn, timer_enable);
	input clk;
	input rate_divide_enable;
	input resetn;
	output timer_enable;
	
	reg [27:0] q;
	
	always @(posedge clk, posedge resetn)
	begin
		if (resetn)
			q <= (28'd50000000 - 28'd1);
		else if (rate_divide_enable)
		begin
			if (q == 28'd0)
				q <= (28'd50000000 - 28'd1);
			else
				q <= q - 28'd1;
		end
	end
	
	assign timer_enable = (q == 28'd0) ? 1 : 0;
endmodule

module countdown_timer(timer_enable, resetn, timer, timer_10s_digit, timer_1s_digit);
	input timer_enable;
	input resetn;
	output [4:0] timer;
	output [3:0] timer_10s_digit;
	output [3:0] timer_1s_digit;
	
	reg [4:0] timer;
	reg [3:0] timer_10s_digit;
	reg [3:0] timer_1s_digit;
	
	always @(*)
	begin
		if (resetn)
		begin
			timer = 5'd30;
			timer_10s_digit = 5'd3;
			timer_1s_digit = 5'd0;
		end
		else if (timer_enable && timer != 5'd0)
		begin 
			timer = timer - 5'd1;
				
			if (timer_1s_digit == 5'd0)
			begin
				timer_1s_digit = 5'd9;
				timer_10s_digit = timer_10s_digit - 5'd1;
			end
			else
			begin
				timer_1s_digit = timer_1s_digit - 5'd1;
			end
		end
	end
endmodule

module random_num_generator(rng_enable, resetn, random_num);
	input rng_enable;
	input resetn;
	output [6:0] random_num;
	
	reg [6:0] random_num;
	wire feedback;
	
	assign feedback = random_num[6] ^ random_num[3];
	
	always @(*)
	begin
		if (resetn)
		begin
			random_num = 7'b1111111;
		end
		else if (rng_enable)
		begin
			random_num = {random_num[5:0], feedback};
		end
	end
endmodule

module LED_generator(LED_gen_enable, resetn, random_num, led_wires);
	input LED_gen_enable;
	input resetn;
	input [6:0] random_num;
	output [3:0] led_wires;
	
	reg [3:0] led_wires;
	wire [3:0] random_num_mod_10;
	
	assign random_num_mod_10 = random_num % 10;
	
	// Decide which LED(s) to light up depending on the value of the random number
	always @(*)
	begin
		if (resetn)
		begin
			led_wires <= 4'b0000;
		end
		else if (LED_gen_enable)
		begin
			led_wires <= 4'b0000;
			
			if (4'd0 <= random_num_mod_10 <= 4'd2)
			begin
				led_wires[0] = 1'b1;
			end
			if (4'd2 <= random_num_mod_10 <= 4'd4)
			begin
				led_wires[1] = 1'b1;
			end
			if (4'd4 <= random_num_mod_10 <= 4'd6)
			begin
				led_wires[2] = 1'b1;
			end
			if (4'd6 <= random_num_mod_10 <= 4'd8)
			begin
				led_wires[3] = 1'b1;
			end
			if (random_num_mod_10 == 4'd9)
			begin
				led_wires = 4'b1111;
			end
		end
	end
endmodule

module display_LED(display, LEDs);
	input [3:0] display;
	output [3:0] LEDs;
	
	assign LEDs[0] = display[0];
	assign LEDs[1] = display[1];
	assign LEDs[2] = display[2];
	assign LEDs[3] = display[3];
endmodule

module display_HEX(u, v, w, x, m);
	input u, v, w, x;
	output [6:0] m;
	
	assign m[0] = (~x & ~w & ~v & u) | (~x & w & ~v & ~u) | (x & w & ~v & u) | (x & ~w & v & u);
	assign m[1] = (~x & w & ~v & u) | (x & w & ~u) | (w & v & ~u) | (x & v & u);
	assign m[2] = (~x & ~w & v & ~u) | (x & w & v) | (x & w & ~u);
	assign m[3] = (~x & ~w & ~v & u) | (~x & w & ~v & ~u) | (w & v & u) | (x & ~w & v & ~u);
	assign m[4] = (~x & u) | (~x & w & ~v) | (~w & ~v & u);
	assign m[5] = (~x & ~w & u) | (~x & ~w & v) | (~x & v & u) | (x & w & ~v & u);
	assign m[6] = (~x & ~w & ~v) | (~x & w & v & u) | (x & w & ~v & ~u);
endmodule

module points_counter(clock, resetn, keys, LEDsig, score1s, score10s);
// Input: user's 4 input key signals and the 4 LED signals
// Output:  user's score in decimal form. score1 and score2 represent a 2 digit decimal.
// If while one of the 4 LED signals is high, the corresponding key input is high, increment the score.

	input clock;
	input resetn;
	input [3:0] keys;
	input [3:0] LEDsig;
	output [3:0] score1s;
	output [3:0] score10s;
	
	reg [3:0]score_10s_digit;
	reg [3:0]score_1s_digit;
	
	always @(posedge resetn, negedge key[0], negedge key[1], negedge key[2], negedge key[3]) begin
		
		if (resetn == 1) begin
			score_10s_digit = 4'd0
			score_1s_digit = 4'd0
		end
		if (score_1s_digit == 4'd9) begin
			score_1s_digit = 4'd0;
			score_10s_digit = score_10s_digit + 4'd1;
		end
		if (LEDsig == 4'hb0001 && keys == 4'b0001)
			score_1s_digit = score_1s_digit + 4'd1;
		if (LEDsig == 4'b0010 && keys == 4'b0010)
			score_1s_digit = score_1s_digit + 4'd1;
		if (LEDsig == 4'b0100 && keys == 4'b0100)
			score_1s_digit = score_1s_digit + 4'd1;
		if (LEDsig == 4'b1000 && keys == 4'b1000)
			score_1s_digit = score_1s_digit + 4'd1;
	end
	
	assign score1s = score_1s_digit;
	assign score10s = score_10s_digit;
	

endmodule 
