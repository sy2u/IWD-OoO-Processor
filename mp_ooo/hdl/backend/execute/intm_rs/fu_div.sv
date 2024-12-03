module fu_div
import cpu_params::*;
import uop_types::*;
import int_rs_types::*;
(
    input   logic               clk,
    input   logic               rst,

    // Prev stage handshake
    input   logic               prv_valid,
    output  logic               prv_ready,

    // Next stage handshake
    output  logic               nxt_valid,
    input   logic               nxt_ready,

    input   intm_rs_reg_t       iss_in,

    output  fu_cdb_reg_t        cdb_out
);

    //---------------------------------------------------------------------------------
    // Declare IP port signals:
    //---------------------------------------------------------------------------------

    localparam                  DATA_WIDTH = 32;
    localparam                  A_WIDTH = DATA_WIDTH+1; // msb for sign extension
    localparam                  B_WIDTH = DATA_WIDTH+1; // msb for sign extension

    logic                       div_start;
    logic [A_WIDTH-1:0]         a; // Multiplier / Dividend
    logic [B_WIDTH-1:0]         b; // Multiplicand / Divisor

    logic [A_WIDTH+B_WIDTH-1:0] product;

    logic                       div_complete, org_complete;
    logic [A_WIDTH-1:0]         quotient;
    logic [B_WIDTH-1:0]         remainder;
    logic                       divide_by_0;

    logic                       complete;
    logic [DATA_WIDTH-1:0]      outcome;
    intm_rs_reg_t               intm_rs_reg;
    logic [DATA_WIDTH:0]        au, bu, as, bs; // msb for sign extension

    //---------------------------------------------------------------------------------
    // Wrap up as Pipelined Register: From Prev
    //---------------------------------------------------------------------------------

    logic                       reg_valid;
    logic                       reg_start;

    // handshake control
    assign prv_ready = ~reg_valid || (nxt_valid && nxt_ready);

    always_ff @( posedge clk ) begin
        if( rst ) begin
            reg_valid <= '0;
        end else if (prv_ready) begin
            reg_valid <= prv_valid;
        end
    end

    // load meta data
    always_ff @( posedge clk ) begin
        if( rst ) begin
            intm_rs_reg <= '0;
        end else if( prv_ready && prv_valid )begin
            intm_rs_reg <= iss_in;
        end
    end

    // start signal generation
    always_ff @( posedge clk ) begin
        if( rst ) begin
            reg_start <= '0;
        end else begin
            if ( reg_start ) begin
                reg_start <= '0;
            end else if( prv_ready && prv_valid ) begin
                reg_start <= '1;
            end
        end
    end

    //---------------------------------------------------------------------------------
    // IP Control:
    //---------------------------------------------------------------------------------

    assign  complete = div_complete;
    assign  div_complete = org_complete && (~div_start);
    assign  div_start = reg_start;

    // mult: multiplier and multiplicand are interchanged
    assign  au = {1'b0, intm_rs_reg.rs1_value};
    assign  bu = {1'b0, intm_rs_reg.rs2_value}; 
    assign  as = {intm_rs_reg.rs1_value[DATA_WIDTH-1], intm_rs_reg.rs1_value};
    assign  bs = {intm_rs_reg.rs2_value[DATA_WIDTH-1], intm_rs_reg.rs2_value};

    always_comb begin
        a = '0;
        b = '0;
        outcome = 'x;
        unique case (intm_rs_reg.fu_opcode)
            MD_DIV: begin       // signed / signed
                a = as;
                b = bs;
                outcome = quotient[DATA_WIDTH-1:0];
                if( divide_by_0 ) outcome = '1;
            end
            MD_DIVU: begin      // unsigned / unsigned
                a = au;
                b = bu;
                outcome = quotient[DATA_WIDTH-1:0];
                if( divide_by_0 ) outcome = '1;
            end
            MD_REM: begin       // signed % signed
                a = as;
                b = bs;
                outcome = remainder[DATA_WIDTH-1:0];
                if( divide_by_0 ) outcome = intm_rs_reg.rs1_value;
            end
            MD_REMU: begin      // unsigned % unsigned
                a = au;
                b = bu;
                outcome = remainder[DATA_WIDTH-1:0];
                if( divide_by_0 ) outcome = intm_rs_reg.rs1_value;
            end
            default: ;
        endcase
    end

    //---------------------------------------------------------------------------------
    // Instantiation:
    //---------------------------------------------------------------------------------

    localparam                  NUM_CYC_DIV = 12;        // minimal possible delay
    localparam                  TC_MODE = 1;        // signed
    localparam                  RST_MODE = 1;       // sync mode
    localparam                  INPUT_MODE = 0;     // input must be stable during the computation
    localparam                  OUTPUT_MODE = 0;    // output must be stable during the computation
    localparam                  EARLY_START = 0;    // start computation in cycle 0

    DW_div_seq #(A_WIDTH, B_WIDTH, TC_MODE, NUM_CYC_DIV,
                RST_MODE, INPUT_MODE, OUTPUT_MODE, EARLY_START)
    divider (.clk(clk), .rst_n(~rst), .hold('0),
            .start(div_start), .a(a), .b(b),
            .complete(org_complete), .divide_by_0(divide_by_0),
            .quotient(quotient), .remainder(remainder) );

    assign nxt_valid                = reg_valid && complete;
    assign cdb_out.rob_id           = intm_rs_reg.rob_id;
    assign cdb_out.rd_arch          = intm_rs_reg.rd_arch;
    assign cdb_out.rd_phy           = intm_rs_reg.rd_phy;
    assign cdb_out.rd_value         = outcome;
    assign cdb_out.rs1_value_dbg    = intm_rs_reg.rs1_value;
    assign cdb_out.rs2_value_dbg    = intm_rs_reg.rs2_value;

endmodule
