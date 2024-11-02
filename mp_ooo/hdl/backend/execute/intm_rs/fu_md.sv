module fu_md
import cpu_params::*;
import uop_types::*;
import intm_rs_types::*;
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

    input   intm_rs_reg_t       intm_rs_reg,

    cdb_itf.fu                  cdb
);

    //---------------------------------------------------------------------------------
    // Declare IP port signals:
    //---------------------------------------------------------------------------------

    localparam                  DATA_WIDTH = 32;
    localparam                  A_WIDTH = DATA_WIDTH+1; // msb for sign extension
    localparam                  B_WIDTH = DATA_WIDTH+1; // msb for sign extension

    logic                       mul_start, div_start;
    logic [A_WIDTH-1:0]         a; // Multiplier / Dividend
    logic [B_WIDTH-1:0]         b; // Multiplicand / Divisor

    logic                       mul_complete;
    logic [A_WIDTH+B_WIDTH-1:0] product;

    logic                       div_complete;
    logic [A_WIDTH-1:0]         quotient;
    logic [B_WIDTH-1:0]         remainder;
    logic                       divide_by_0;

    //---------------------------------------------------------------------------------
    // Wrap up as Pipelined Register:
    //---------------------------------------------------------------------------------

    logic                       complete;
    logic [DATA_WIDTH-1:0]      outcome;
    fu_md_reg_t                 fu_md_reg;
    logic [DATA_WIDTH:0]        au, bu, as, bs; // msb for sign extension

    logic                       reg_valid;
    logic                       reg_start;

    assign nxt_valid = reg_valid && complete;
    assign prv_ready = ~reg_valid || (nxt_valid && nxt_ready);

    // handshake control
    always_ff @( posedge clk ) begin
        if( rst || flush ) begin
            reg_valid <= '0;
        end else if (prv_ready) begin
            reg_valid <= prv_valid;
        end
    end

    // load meta data
    always_ff @( posedge clk ) begin
        if( rst ) begin
            fu_md_reg <= '0;
        end else begin
            if( prv_ready && prv_valid ) begin
                fu_md_reg.rob_id <= intm_rs_reg.rob_id;
                fu_md_reg.rd_arch <= intm_rs_reg.rd_arch;
                fu_md_reg.rd_phy <= intm_rs_reg.rd_phy;
                fu_md_reg.rs1_value <= intm_rs_reg.rs1_value;
                fu_md_reg.rs2_value <= intm_rs_reg.rs2_value;
                fu_md_reg.fu_opcode <= intm_rs_reg.fu_opcode;
                fu_md_reg.dividend <= intm_rs_reg.rs1_value;
            end
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

    // IP control
    logic                       is_multiply;
    assign  is_multiply = (fu_md_reg.fu_opcode inside {MD_MUL, MD_MULH, MD_MULHSU, MD_MULHU});
    assign  complete = (is_multiply) ? mul_complete : div_complete;
    assign  mul_start = (reg_start) && is_multiply;
    assign  div_start = (reg_start) && ~is_multiply;

    // mult: multiplier and multiplicand are interchanged
    assign  au = {1'b0, fu_md_reg.rs1_value};
    assign  bu = {1'b0, fu_md_reg.rs2_value}; 
    assign  as = {fu_md_reg.rs1_value[DATA_WIDTH-1], fu_md_reg.rs1_value};
    assign  bs = {fu_md_reg.rs2_value[DATA_WIDTH-1], fu_md_reg.rs2_value};

    always_comb begin
        a = '0;
        b = '0;
        outcome = 'x;
        unique case (intm_rs_reg.fu_opcode)
            MD_MUL: begin
                a = as;
                b = bs;
                outcome = product[DATA_WIDTH-1:0];
            end
            MD_MULH: begin      // signed x signed
                a = as;
                b = bs;
                outcome = product[2*DATA_WIDTH-1:DATA_WIDTH];
            end
            MD_MULHSU: begin    // signed x unsigned
                a = as;
                b = bu;
                outcome = product[2*DATA_WIDTH-1:DATA_WIDTH];
            end
            MD_MULHU: begin     // unsigned x unsigned
                a = au;
                b = bu;
                outcome = product[2*DATA_WIDTH-1:DATA_WIDTH];
            end
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
                if( divide_by_0 ) outcome = fu_md_reg.dividend;
            end
            MD_REMU: begin      // unsigned % unsigned
                a = au;
                b = bu;
                outcome = remainder[DATA_WIDTH-1:0];
                if( divide_by_0 ) outcome = fu_md_reg.dividend;
            end
            default: ;
        endcase
    end

    //---------------------------------------------------------------------------------
    // Instantiation:
    //---------------------------------------------------------------------------------

    localparam                  NUM_CYC = 3;        // minimal possible delay
    localparam                  TC_MODE = 1;        // signed
    localparam                  RST_MODE = 1;       // sync mode
    localparam                  INPUT_MODE = 0;     // registered input
    localparam                  OUTPUT_MODE = 0;    // registered output
    localparam                  EARLY_START = 0;    // start computation in cycle 0

    DW_mult_seq #(A_WIDTH, B_WIDTH, TC_MODE, NUM_CYC, 
                RST_MODE, INPUT_MODE, OUTPUT_MODE, EARLY_START)
    signed_mul (.clk(clk), .rst_n(~rst), .hold('0),
                .start(mul_start), .a(a), .b(b),
                .complete(mul_complete), .product(product) );

    DW_div_seq #(A_WIDTH, B_WIDTH, TC_MODE, NUM_CYC,
                RST_MODE, INPUT_MODE, OUTPUT_MODE, EARLY_START)
    divider (.clk(clk), .rst_n(~rst), .hold('0),
            .start(div_start), .a(a), .b(b),
            .complete(div_complete), .divide_by_0(divide_by_0),
            .quotient(quotient), .remainder(remainder) );

    //---------------------------------------------------------------------------------
    // Broadcast to CDB:
    //---------------------------------------------------------------------------------

    assign cdb.rob_id   = fu_md_reg.rob_id;
    assign cdb.rd_phy   = fu_md_reg.rd_phy;
    assign cdb.rd_arch  = fu_md_reg.rd_arch;
    assign cdb.rd_value = outcome;
    assign cdb.valid    = nxt_valid;

endmodule