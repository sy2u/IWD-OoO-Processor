module fu_md
import cpu_params::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,

    input   logic               flush,

    // Prev stage handshake
    input   logic               prv_valid,
    output  logic               prv_ready,

    // Next stage handshake
    output  logic               nxt_valid,
    input   logic               nxt_ready,

    input   int_rs_reg_t        int_rs_reg,

    cdb_itf.fu                  cdb
);

    //---------------------------------------------------------------------------------
    // Declare IP port signals:
    //---------------------------------------------------------------------------------

    localparam                  A_WIDTH = 32;
    localparam                  B_WIDTH = 32;
    localparam                  NUM_CYC = 3;        // minimal possible delay
    localparam                  RST_MODE = 1;       // sync mode
    localparam                  INPUT_MODE = 1;     // registered input
    localparam                  OUTPUT_MODE = 1;    // registered output
    localparam                  EARLY_START = 1;    // start computation in cycle 0

    logic                       mul_start, div_start;
    logic [A_WIDTH-1:0]         a; // Multiplier / Dividend
    logic [B_WIDTH-1:0]         b; // Multiplicand / Divisor

    logic                       mul_complete;
    logic [A_WIDTH+B_WIDTH-1:0] mul_product;

    logic                       div_complete;
    logic [A_WIDTH-1 : 0]       quotient;
    logic [B_WIDTH-1 : 0]       remainder;
    logic                       divide_by_0;

    //---------------------------------------------------------------------------------
    // Wrap up as Pipelined Register:
    //---------------------------------------------------------------------------------

    logic                       tc_mode;
    logic                       reg_valid;

    assign nxt_valid = reg_valid;
    assign prv_ready = ~reg_valid || (nxt_valid && nxt_ready);

    always_ff @( posedge clk ) begin
        if( rst || flush ) begin
            reg_valid <= '0;
        end else begin
            
        end
    end

    always_ff @( posedge clk ) begin
        if( rst ) begin
            
        end else begin
            
        end
    end

    //---------------------------------------------------------------------------------
    // Instantiation:
    //---------------------------------------------------------------------------------

    DW_mult_seq #(A_WIDTH, B_WIDTH, tc_mode, NUM_CYC, 
                RST_MODE, INPUT_MODE, OUTPUT_MODE, EARLY_START)
    multiplier (.clk(clk), .rst_n(~rst), .hold('0),
                .start(mul_start), .a(a), .b(b),
                .complete(mul_complete), .product(product) );
    
    DW_div_seq #(A_WIDTH, B_WIDTH, tc_mode, NUM_CYC,
                RST_MODE, INPUT_MODE, OUTPUT_MODE, EARLY_START)
    divider (.clk(clk), .rst_n(~rst), .hold('0),
            .start(div_start), .a(a), .b(b),
            .complete(div_complete), .divide_by_0(divide_by_0),
            .quotient(quotient), .remainder(remainde) );

endmodule