// skid_buffer
// A simple implementation of a skid buffer with valid/ready handshaking.

module skid_buffer #(
            parameter   type        DATA_T = logic[1:0]
)
(
    input   logic                   clk,
    input   logic                   rst,

    // Prev stage handshake
    input   logic                   prv_valid,
    output  logic                   prv_ready,

    // Next stage handshake
    output  logic                   nxt_valid,
    input   logic                   nxt_ready,

    // Datapath input
    input   DATA_T                  prv_data,

    // Datapath output
    output  DATA_T                  nxt_data
);

    typedef enum logic [2:0] {
        EMPTY = 3'b001,
        BUSY  = 3'b010,
        FULL  = 3'b100
    } skid_buf_state_t;

    DATA_T                          buffer;
    skid_buf_state_t                state, state_nxt;
    logic                           accept, transmit;

    always_comb begin
        accept     = prv_valid && prv_ready;
        transmit   = nxt_valid && nxt_ready;
        state_nxt = EMPTY;
        unique case (state)
            EMPTY: begin
                state_nxt = EMPTY;
                if (accept) state_nxt = BUSY;
            end
            BUSY: begin
                state_nxt = BUSY;
                if (accept && !transmit) state_nxt = FULL;
                else if (!accept && transmit) state_nxt = EMPTY;
            end
            FULL: begin
                state_nxt = FULL;
                if (transmit) state_nxt = BUSY;
            end
            default: state_nxt = EMPTY;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state       <= EMPTY;
            prv_ready   <= 1'b0;
            nxt_valid   <= 1'b0;
        end else begin
            state       <= state_nxt;
            prv_ready   <= state_nxt != FULL;
            nxt_valid   <= state_nxt != EMPTY;
        end
    end

    logic buf_we, data_we;
    always_comb begin
        buf_we = state == BUSY && accept && !transmit;
        data_we = (state == EMPTY && accept && !transmit)
                || (state == BUSY && accept && transmit)
                || (state == FULL && !accept && transmit);
    end

    always_ff @(posedge clk) begin
        if (data_we) begin
            if (state == FULL) nxt_data <= buffer;
            else nxt_data <= prv_data;
        end
        if (buf_we) begin
            buffer <= prv_data;
        end
    end

endmodule
