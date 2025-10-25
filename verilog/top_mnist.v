// top_mnist.v
`timescale 1ns/1ps
module top_mnist(
    input clk50,           // 50 MHz
    input reset_n,
    input uart_rx_pin,
    output uart_tx_pin
    // optional: LEDs, segs
);

wire [7:0] rx_byte;
wire rx_ready;
wire [7:0] tx_byte;
wire tx_start;
wire tx_busy;

// UART
uart_rx #(.CLK_FREQ(50000000), .BAUD(115200)) uart_rx_inst (
    .clk(clk50), .reset_n(reset_n), .rx(uart_rx_pin),
    .data_out(rx_byte), .data_ready(rx_ready)
);
uart_tx #(.CLK_FREQ(50000000), .BAUD(115200)) uart_tx_inst (
    .clk(clk50), .reset_n(reset_n), .tx_data(tx_byte), .tx_start(tx_start),
    .tx_busy(tx_busy), .tx(uart_tx_pin)
);

// Instantiate MAC
wire mac_done;
wire [15:0] mac_out_q15;
reg mac_start;
reg [10:0] mac_Nterms;
reg signed [15:0] mac_bias;
reg signed [15:0] mac_wdata;
reg signed [15:0] mac_xdata;
reg mac_load_next;

mac_unit mac0 (
    .clk(clk50), .reset_n(reset_n),
    .start(mac_start),
    .Nterms(mac_Nterms),
    .bias(mac_bias),
    .in_w(mac_wdata),
    .in_x(mac_xdata),
    .load_next(mac_load_next),
    .done(mac_done),
    .out_q15(mac_out_q15)
);

//----------------------------------------------------------------
// Memory/ROM instances (create these in Quartus IP with exact names below)
//----------------------------------------------------------------
// fc0_W_rom (depth = 784*64 = 50176, width=16)
// ports: clock, address, q
wire [15:0] fc0_W_q;
reg [15:0] fc0_W_addr;
fc0_W_rom fc0_W_rom_inst (.clock(clk50), .address(fc0_W_addr), .q(fc0_W_q));

// fc0_b_rom (depth = 64)
wire [15:0] fc0_b_q;
reg [15:0] fc0_b_addr;
fc0_b_rom fc0_b_rom_inst (.clock(clk50), .address(fc0_b_addr), .q(fc0_b_q));

// fc1_W_rom (depth = 64*10 = 640)
wire [15:0] fc1_W_q;
reg [15:0] fc1_W_addr;
fc1_W_rom fc1_W_rom_inst (.clock(clk50), .address(fc1_W_addr), .q(fc1_W_q));

// fc1_b_rom (depth = 10)
wire [15:0] fc1_b_q;
reg [15:0] fc1_b_addr;
fc1_b_rom fc1_b_rom_inst (.clock(clk50), .address(fc1_b_addr), .q(fc1_b_q));

// input_ram (depth=784, width=16) - dual port recommended
// ports: clock, address, q, wren, writedata (assuming single clock, sync read)
wire [15:0] input_ram_q;
reg [15:0] input_ram_addr;
reg [15:0] input_ram_wdata;
reg input_ram_wren;
input_ram input_ram_inst (
    .clock(clk50),
    .address(input_ram_addr),
    .q(input_ram_q),
    .writedata(input_ram_wdata),
    .writeenable(input_ram_wren)
);

// hidden_ram (depth=64, width=16)
wire [15:0] hidden_ram_q;
reg [15:0] hidden_ram_addr;
reg [15:0] hidden_ram_wdata;
reg hidden_ram_wren;
hidden_ram hidden_ram_inst (
    .clock(clk50),
    .address(hidden_ram_addr),
    .q(hidden_ram_q),
    .writedata(hidden_ram_wdata),
    .writeenable(hidden_ram_wren)
);

//----------------------------------------------------------------
// Controller (inline FSM)
//----------------------------------------------------------------
localparam IDLE = 0, RX_IMAGE = 1, LAYER0 = 2, LAYER0_WAIT = 3, LAYER0_STORE = 4,
           LAYER1 = 5, LAYER1_WAIT = 6, ARGMAX = 7, SEND = 8;

reg [3:0] state;
reg [10:0] rx_count;
reg [9:0] i_idx; // up to 784
reg [6:0] j_idx; // up to 64
reg [3:0] k_idx; // up to 10
reg [15:0] logits [0:9]; // store fc1 outputs (as Q1.15)
reg signed [15:0] last_mac_out; // capture mac output when done

// UART write signals
reg [7:0] tx_byte_r;
reg tx_start_r;

// pipeline registers for ROM data (1-cycle read latency)
reg [15:0] fc0_W_q_r;
reg [15:0] input_q_r;
reg [15:0] fc1_W_q_r;
reg [15:0] hidden_q_r;

always @(posedge clk50 or negedge reset_n) begin
    if (!reset_n) begin
        state <= IDLE;
        rx_count <= 0;
        input_ram_wren <= 0;
        input_ram_wdata <= 0;
        input_ram_addr <= 0;
        fc0_W_addr <= 0;
        fc0_b_addr <= 0;
        fc1_W_addr <= 0;
        fc1_b_addr <= 0;
        hidden_ram_wren <= 0;
        hidden_ram_wdata <= 0;
        hidden_ram_addr <= 0;
        mac_start <= 0;
        mac_load_next <= 0;
        tx_start_r <= 0;
        tx_byte_r <= 0;
        i_idx <= 0; j_idx <= 0; k_idx <= 0;
    end else begin
        // default signals
        input_ram_wren <= 0;
        hidden_ram_wren <= 0;
        mac_start <= 0;
        mac_load_next <= 0;
        tx_start_r <= 0;

        // capture ROM outputs into local reg (1-cycle after addr set)
        fc0_W_q_r <= fc0_W_q;
        input_q_r <= input_ram_q;
        fc1_W_q_r <= fc1_W_q;
        hidden_q_r <= hidden_ram_q;

        case (state)
        IDLE: begin
            if (rx_ready && rx_byte == 8'hAA) begin
                rx_count <= 0;
                input_ram_addr <= 0;
                state <= RX_IMAGE;
            end
        end
        RX_IMAGE: begin
            if (rx_ready) begin
                // write byte to input_ram as Q1.15 scaling
                // We will scale on FPGA: input_q = pixel * 128 (approx 32767/255)
                input_ram_wdata <= {8'b0, rx_byte[7:0]}; // placeholder, convert below
                // convert pixel (0..255) -> Q1.15 roughly multiply by 128
                input_ram_wdata <= $signed({8'b0, rx_byte}) * 16'sd128;
                input_ram_wren <= 1;
                input_ram_addr <= input_ram_addr + 1;
                rx_count <= rx_count + 1;
                if (rx_count + 1 == 784) begin
                    state <= LAYER0;
                    // init indices
                    j_idx <= 0; // hidden neuron index
                    i_idx <= 0; // input index
                end
            end
        end
        // LAYER0: compute neuron j across i=0..783
        LAYER0: begin
            // set bias addr for current neuron j (fc0_b at addr j)
            fc0_b_addr <= j_idx;
            // start MAC when we prepare to stream inputs
            mac_Nterms <= 11'd784;
            mac_bias <= $signed(fc0_b_q); // fc0_b_q is available next cycle, but we use reg pipeline capture
            // begin streaming loop: for each i, set input_ram_addr and fc0_W_addr,
            // then on next cycle mac_load_next will use captured data
            input_ram_addr <= i_idx; // set address, data available next cycle in input_q_r
            fc0_W_addr <= i_idx * 64 + j_idx;
            // present w/x on the same cycle as mac_load_next (mac reads captured registers)
            mac_wdata <= $signed(fc0_W_q_r);
            mac_xdata <= $signed(input_q_r);
            mac_load_next <= 1;
            i_idx <= i_idx + 1;
            if (i_idx + 1 == 784) begin
                // last term submitted; wait for mac_done next cycles
                state <= LAYER0_WAIT;
            end
        end
        LAYER0_WAIT: begin
            // wait mac_done then store output to hidden_ram[j]
            if (mac_done) begin
                hidden_ram_addr <= j_idx;
                hidden_ram_wdata <= mac_out_q15; // already Q1.15
                hidden_ram_wren <= 1;
                // next neuron
                j_idx <= j_idx + 1;
                i_idx <= 0;
                if (j_idx + 1 == 64) begin
                    // finished layer0
                    k_idx <= 0;
                    state <= LAYER1;
                end else begin
                    state <= LAYER0; // process next neuron
                end
            end
        end
        // LAYER1 compute
        LAYER1: begin
            // k_idx := output neuron index 0..9
            fc1_b_addr <= k_idx;
            mac_Nterms <= 11'd64;
            mac_bias <= $signed(fc1_b_q);
            // stream hidden values j=0..63:
            hidden_ram_addr <= i_idx; // reusing i_idx as j index here
            fc1_W_addr <= i_idx * 10 + k_idx;
            mac_wdata <= $signed(fc1_W_q_r);
            mac_xdata <= $signed(hidden_q_r);
            mac_load_next <= 1;
            i_idx <= i_idx + 1;
            if (i_idx + 1 == 64) begin
                state <= LAYER1_WAIT;
            end
        end
        LAYER1_WAIT: begin
            if (mac_done) begin
                logits[k_idx] <= mac_out_q15;
                k_idx <= k_idx + 1;
                i_idx <= 0;
                if (k_idx + 1 == 10) begin
                    state <= ARGMAX;
                end else begin
                    state <= LAYER1;
                end
            end
        end
        ARGMAX: begin
            // compute argmax of logits[0..9] (simple combinational loop)
            integer idx; reg signed [15:0] bestv; integer besti;
            bestv = logits[0];
            besti = 0;
            for (idx = 1; idx < 10; idx = idx + 1) begin
                if ($signed(logits[idx]) > bestv) begin
                    bestv = logits[idx];
                    besti = idx;
                end
            end
            tx_byte_r <= besti[7:0];
            state <= SEND;
        end
        SEND: begin
            if (!tx_busy) begin
                tx_start_r <= 1;
                state <= IDLE;
            end
        end
        default: state <= IDLE;
        endcase
    end
end

// tie tx outputs
assign tx_byte = tx_byte_r;
assign tx_start = tx_start_r;

endmodule

