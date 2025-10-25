// uart_tx.v
module uart_tx #(parameter CLK_FREQ = 50000000, BAUD = 115200)(
    input clk, input reset_n,
    input [7:0] tx_data, input tx_start,
    output reg tx_busy, output reg tx
);
    localparam integer TICKS = CLK_FREQ / BAUD;
    reg [15:0] baud_cnt;
    reg [3:0] bit_cnt;
    reg [9:0] shift;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            tx <= 1; tx_busy <= 0; baud_cnt <= 0; bit_cnt <= 0; shift <= 10'b1111111111;
        end else begin
            if (!tx_busy) begin
                if (tx_start) begin
                    shift <= {1'b1, tx_data, 1'b0}; // stop, data[7:0], start (lsb first)
                    tx_busy <= 1;
                    bit_cnt <= 0;
                    baud_cnt <= TICKS - 1;
                    tx <= 0;
                end
            end else begin
                if (baud_cnt == 0) begin
                    baud_cnt <= TICKS - 1;
                    tx <= shift[bit_cnt];
                    bit_cnt <= bit_cnt + 1;
                    if (bit_cnt == 9) tx_busy <= 0;
                end else baud_cnt <= baud_cnt - 1;
            end
        end
    end
endmodule

