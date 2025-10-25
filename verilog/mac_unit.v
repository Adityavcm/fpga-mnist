// mac_unit.v
module mac_unit(
    input clk, input reset_n,
    input start,
    input [10:0] Nterms,
    input signed [15:0] bias,      // Q1.15
    input signed [15:0] in_w,      // weight (presented when load_next asserted)
    input signed [15:0] in_x,
    input load_next,               // pulse per term (core receives w/x on same cycle)
    output reg done,
    output reg signed [15:0] out_q15
);
    reg signed [63:0] acc;
    reg [10:0] count;
    reg running;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            acc <= 0; count <= 0; running <= 0; done <= 0; out_q15 <= 0;
        end else begin
            done <= 0;
            if (start && !running) begin
                running <= 1;
                acc <= 0;
                count <= 0;
            end else if (running && load_next) begin
                acc <= acc + (in_w * in_x); // signed 16x16 -> 32, accumulate into 64
                count <= count + 1;
                if (count + 1 == Nterms) begin
                    // finish
                    running <= 0;
                    // shift right by 15 to convert from Q2.30 -> Q2.15 then add bias (Q1.15)
                    // acc is signed 64, shift preserving sign
                    reg signed [63:0] shifted;
                    reg signed [31:0] res32;
                    shifted = acc >>> 15;
                    res32 = shifted[31:0] + bias;
                    // saturation to int16
                    if (res32 > 32767) out_q15 <= 16'sh7FFF;
                    else if (res32 < -32768) out_q15 <= 16'sh8000;
                    else out_q15 <= res32[15:0];
                    done <= 1;
                end
            end
        end
    end
endmodule
