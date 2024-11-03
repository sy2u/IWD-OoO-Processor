module fu_mul
import cpu_params::*;
import uop_types::*;
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

    input   intm_rs_reg_t       intm_rs_in,

    cdb_itf.fu                  cdb
);

    //---------------------------------------------------------------------------------
    // Declare IP port signals:
    //---------------------------------------------------------------------------------

    localparam                  DATA_WIDTH = 32;
    localparam                  A_WIDTH = DATA_WIDTH+1; // msb for sign extension
    localparam                  B_WIDTH = DATA_WIDTH+1; // msb for sign extension

    logic                       start;
    logic [A_WIDTH-1:0]         a; // Multiplier / Dividend
    logic [B_WIDTH-1:0]         b; // Multiplicand / Divisor

    logic                       complete;
    logic [A_WIDTH+B_WIDTH-1:0] product;

    //---------------------------------------------------------------------------------
    // Wrap up as Pipelined Register: From Prev
    //---------------------------------------------------------------------------------

    logic                       reg_valid;
    intm_rs_reg_t               intm_rs_reg;

    // handshake control
    assign prv_ready = ~reg_valid || (nxt_valid && nxt_ready);

    always_ff @( posedge clk ) begin
        if( rst || flush ) begin
            reg_valid <= '0;
        end else if (prv_ready) begin
            reg_valid <= prv_valid;
        end
    end

    // start signal generation
    always_ff @( posedge clk ) begin
        if( rst ) begin
            start <= '0;
        end else begin
            if ( start ) begin
                start <= '0;
            end else if( prv_ready && prv_valid ) begin
                start <= '1;
            end
        end
    end

    // load meta data
    always_ff @( posedge clk ) begin
        if( rst ) begin
            intm_rs_reg <= '0;
        end else if( prv_ready && prv_valid )begin
            intm_rs_reg <= intm_rs_in;
        end
    end

    //---------------------------------------------------------------------------------
    // IP Control:
    //---------------------------------------------------------------------------------

    logic [DATA_WIDTH-1:0]      outcome;
    logic [DATA_WIDTH:0]        au, bu, as, bs; // msb for sign extension

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
            default: ;
        endcase
    end

    //---------------------------------------------------------------------------------
    // Instantiation:
    //---------------------------------------------------------------------------------

    localparam                  NUM_CYC = 3;        // minimal possible delay
    localparam                  TC_MODE = 1;        // signed
    localparam                  RST_MODE = 1;       // sync mode
    localparam                  INPUT_MODE = 0;     // input must be stable during the computation
    localparam                  OUTPUT_MODE = 0;    // output must be stable during the computation
    localparam                  EARLY_START = 0;    // start computation in cycle 0

    DW_mult_seq #(A_WIDTH, B_WIDTH, TC_MODE, NUM_CYC, 
                RST_MODE, INPUT_MODE, OUTPUT_MODE, EARLY_START)
    signed_mul (.clk(clk), .rst_n(~rst), .hold('0),
                .start(start), .a(a), .b(b),
                .complete(complete), .product(product) );

    //---------------------------------------------------------------------------------
    // Wrap up as Pipelined Register: To Next
    //---------------------------------------------------------------------------------

    fu_reg_t                    fu_mul_reg;
    logic                       cdb_valid, cdb_ready;
    
    assign cdb_ready = 1'b1;
    assign nxt_valid = reg_valid && complete;

    always_ff @(posedge clk) begin 
        if (rst) begin 
            cdb_valid <= 1'b0;
            fu_mul_reg <= '0;
        end else begin 
            cdb_valid <= nxt_valid && cdb_ready;
            if (nxt_valid && cdb_ready) begin 
                fu_mul_reg.rob_id       <= intm_rs_reg.rob_id;
                fu_mul_reg.rd_arch      <= intm_rs_reg.rd_arch;
                fu_mul_reg.rd_phy       <= intm_rs_reg.rd_phy;
                fu_mul_reg.rd_value     <= outcome;
                fu_mul_reg.rs1_value_dbg<= intm_rs_reg.rs1_value;
                fu_mul_reg.rs2_value_dbg<= intm_rs_reg.rs2_value;
            end
        end
    end

    //---------------------------------------------------------------------------------
    // Boardcast to CDB:
    //---------------------------------------------------------------------------------

    assign cdb.valid            = cdb_valid;
    assign cdb.rob_id           = fu_mul_reg.rob_id;
    assign cdb.rd_phy           = fu_mul_reg.rd_phy;
    assign cdb.rd_arch          = fu_mul_reg.rd_arch;
    assign cdb.rd_value         = fu_mul_reg.rd_value;
    assign cdb.rs1_value_dbg    = fu_mul_reg.rs1_value_dbg;
    assign cdb.rs2_value_dbg    = fu_mul_reg.rs2_value_dbg;

endmodule