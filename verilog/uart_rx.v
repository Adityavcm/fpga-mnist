// uart_rx.v
module uart_rx #(parameter CLK_FREQ = 50000000, BAUD = 115200)(
    input clk, input reset_n, input rx,
    output reg [7:0] data_out,
    output reg data_ready
);
    localparam integer TICKS = CLK_FREQ / BAUD;
    reg [15:0] baud_cnt;
    reg [3:0] bit_cnt;
    reg [9:0] shift;
    reg busy;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            baud_cnt <= 0; bit_cnt <= 0; shift <= 10'b1111111111; busy <= 0; data_ready <= 0;
        end else begin
            data_ready <= 0;
            if (!busy) begin
                if (rx == 0) begin // start bit detected
                    busy <= 1;
                    baud_cnt <= (TICKS >> 1); // sample at mid
                    bit_cnt <= 0;
                end
            end else begin
                if (baud_cnt == 0) begin
                    baud_cnt <= TICKS - 1;
                    bit_cnt <= bit_cnt + 1;
                    shift <= {rx, shift[9:1]};
                    if (bit_cnt == 9) begin
                        busy <= 0;
                        data_out <= shift[8:1];
                        data_ready <= 1;
                    end
                end else baud_cnt <= baud_cnt - 1;
            end
        end
    end
endmodule

