`timescale 1ns / 1ps

module mnist_mlp(
    // DE2-115 Board Inputs
    input CLOCK_50,
    input [0:0] KEY,       // KEY[0] for reset
    input [0:0] SW,        // SW[0] for start

    // DE2-115 Board Outputs
    output [17:0] LEDR     // LEDR[3:0] for digit, LEDR[17] for done
);

// --- Internal Signals ---
reg [3:0] predicted_digit;
reg done;

// Assign outputs to LEDs
assign LEDR[3:0] = predicted_digit;
assign LEDR[17] = done;

// Use the push-button for reset (active low)
wire reset = ~KEY[0];
// Use the switch for start
wire start = SW[0];


// --- FSM ---
localparam S_IDLE    = 2'b00;
localparam S_COMPUTE = 2'b01;
localparam S_ARGMAX  = 2'b10;
localparam S_DONE    = 2'b11;

reg [1:0] state;

// --- Memories ---
reg [7:0] image [0:783];
reg signed [15:0] weights [0:7839];
reg signed [15:0] biases [0:9];
reg signed [33:0] outputs [0:9];

// --- Counters ---
reg [9:0] pixel_idx;
reg [3:0] neuron_idx;
reg [3:0] argmax_idx;
reg signed [33:0] max_val;

// --- Initialization ---
initial begin
    $readmemh("weights.hex", weights);
    $readmemh("biases.hex", biases);
    // You would create an image.hex file for simulation/testing
    // For synthesis, you might initialize the image RAM differently
    // or load it from another source like a UART.
    $readmemh("image.hex", image);
end


// --- Main Logic ---
always @(posedge CLOCK_50 or posedge reset) begin
    if (reset) begin
        state <= S_IDLE;
        pixel_idx <= 0;
        neuron_idx <= 0;
        argmax_idx <= 0;
        predicted_digit <= 4'b0;
        done <= 1'b0;
        max_val <= -8589934592; // Smallest 34-bit signed number
        for (integer i = 0; i < 10; i = i + 1) begin
            outputs[i] <= 32'b0;
        end
    end else begin
        case(state)
            S_IDLE:
                if (start) begin
                    state <= S_COMPUTE;
                    pixel_idx <= 0;
                    neuron_idx <= 0;
                    // Pre-load all bias values
                    for (integer i = 0; i < 10; i = i + 1) begin
                        outputs[i] <= biases[i];
                    end
                end

            S_COMPUTE:
                begin
                    // Perform one MAC operation per cycle
                    outputs[neuron_idx] <= outputs[neuron_idx] + (weights[pixel_idx*10 + neuron_idx] * $signed({8'b0, image[pixel_idx]}));

                    if (pixel_idx == 783) begin
                        pixel_idx <= 0;
                        if (neuron_idx == 9) begin
                            state <= S_ARGMAX;
                            argmax_idx <= 0;
                            max_val <= -8589934592;
                        end else begin
                            neuron_idx <= neuron_idx + 1;
                        end
                    end else begin
                        pixel_idx <= pixel_idx + 1;
                    end
                end

            S_ARGMAX:
                begin
                    if(outputs[argmax_idx] > max_val) begin
                        max_val <= outputs[argmax_idx];
                        predicted_digit <= argmax_idx;
                    end

                    if (argmax_idx == 9) begin
                        state <= S_DONE;
                    end else begin
                        argmax_idx <= argmax_idx + 1;
                    end
                end

            S_DONE:
                begin
                    done <= 1'b1;
                    // Stay in DONE state until start is lowered
                    if (!start) begin
                        state <= S_IDLE;
                        done <= 1'b0;
                    end
                end

        endcase
    end
end

endmodule