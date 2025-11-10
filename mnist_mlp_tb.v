`timescale 1ns / 1ps

module mnist_mlp_tb;

// Inputs to the DUT (Device Under Test)
reg CLOCK_50;
reg [0:0] KEY;
reg [0:0] SW;

// Outputs from the DUT
wire [17:0] LEDR;

// Instantiate the Unit Under Test (UUT)
mnist_mlp uut (
    .CLOCK_50(CLOCK_50),
    .KEY(KEY),
    .SW(SW),
    .LEDR(LEDR)
);

// Clock Generation
initial begin
    CLOCK_50 = 0;
    forever #10 CLOCK_50 = ~CLOCK_50; // 50MHz clock
end

// Test Sequence
initial begin
    $display("Starting Testbench...");

    // 1. Assert Reset
    KEY[0] = 1'b0; // Press KEY0
    SW[0] = 1'b0;
    #20;
    KEY[0] = 1'b1; // Release KEY0
    $display("Reset released.");

    #20;

    // 2. Start the computation
    $display("Flipping start switch ON.");
    SW[0] = 1'b1;

    // 3. Wait for the done signal (LEDR[17])
    $display("Waiting for completion (LEDR[17] to go high)...");
    wait (LEDR[17] == 1'b1);
    $display("Computation complete!");

    // 4. Display the result
    $display("Predicted digit on LEDR[3:0] is: %d", LEDR[3:0]);

    #20;

    // 5. Lower the start switch to return to IDLE
    $display("Flipping start switch OFF.");
    SW[0] = 1'b0;

    #50;

    $display("Testbench finished.");
    $finish;
end

// Timeout to prevent infinite simulation
initial begin
    #200000; // ~10000 cycles for compute + some margin
    $display("ERROR: Simulation timed out!");
    $finish;
end

endmodule
