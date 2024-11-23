module ds_stage
import cpu_params::*;
import uop_types::*;
(
    input   logic               clk,
    input   logic               rst,

    // handshake with rename stage
    input   logic               prv_valid,
    output  logic               prv_ready,
    input   logic               uops_valid[ID_WIDTH],
    input   rs_type_t           rs_type[ID_WIDTH],
    input   uop_t               uops[ID_WIDTH],

    // INT Reservation Stations
    ds_rs_itf.ds                to_int_rs,

    // INTM Reservation Stations
    ds_rs_itf.ds                to_intm_rs,

    // BR Reservation Stations
    ds_rs_mono_itf.ds           to_br_rs,

    // MEM Reservation Stations
    ds_rs_mono_itf.ds           to_mem_rs
);

    //////////////////////////
    //    Dispatch Stage    //
    //////////////////////////

    logic               dispatch_valid  [ID_WIDTH];
    logic               dispatch_ready  [ID_WIDTH];

    // Upstream signals to determine if we can dispatch
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin : dispatch_valids
        assign dispatch_valid[i] = prv_valid && uops_valid[i];
    end endgenerate

    // Encoder to select the reservation station
    always_comb begin
        for (int i = 0; i < ID_WIDTH; i++) begin
            to_int_rs.valid[i] = '0;
            to_int_rs.uop[i] = '{rs_type: RS_X, fu_type: FU_X, op1_sel: OP1_X, op2_sel: OP2_X, default: 'x};
            to_intm_rs.valid[i] = '0;
            to_intm_rs.uop[i] = '{rs_type: RS_X, fu_type: FU_X, op1_sel: OP1_X, op2_sel: OP2_X, default: 'x};
        end
        to_br_rs.valid = '0;
        to_br_rs.uop = '{rs_type: RS_X, fu_type: FU_X, op1_sel: OP1_X, op2_sel: OP2_X, default: 'x};
        to_mem_rs.valid = '0;
        to_mem_rs.uop = '{rs_type: RS_X, fu_type: FU_X, op1_sel: OP1_X, op2_sel: OP2_X, default: 'x};

        for (int i = 0; i < ID_WIDTH; i++) begin
            unique case (rs_type[i])
                RS_INT: begin
                    to_int_rs.valid[i] = dispatch_valid[i] && prv_ready; // Dispatch to INT Reservation Stations
                    to_int_rs.uop[i] = uops[i];
                end
                RS_INTM: begin
                    to_intm_rs.valid[i] = dispatch_valid[i] && prv_ready; // Dispatch to INTM Reservation Stations
                    to_intm_rs.uop[i] = uops[i];
                end
                RS_BR: begin
                    to_br_rs.valid = dispatch_valid[i] && prv_ready; // Dispatch to BR Reservation Stations
                    to_br_rs.uop = uops[i];
                end
                RS_MEM: begin
                    to_mem_rs.valid = dispatch_valid[i] && prv_ready; // Dispatch to MEM Reservation Stations
                    to_mem_rs.uop = uops[i];
                end
                default: begin
                end
            endcase
        end
    end

    // Mux for selecting the ready signal
    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        always_comb begin
            unique case (rs_type[i])
                RS_INT: begin
                    dispatch_ready[i] = to_int_rs.ready; // Collect ready signal from INT Reservation Stations
                end
                RS_INTM: begin
                    dispatch_ready[i] = to_intm_rs.ready; // Collect ready signal from INTM Reservation Stations
                end
                RS_BR: begin
                    dispatch_ready[i] = to_br_rs.ready; // Collect ready signal from BR Reservation Stations
                end
                RS_MEM: begin
                    dispatch_ready[i] = to_mem_rs.ready; // Collect ready signal from MEM Reservation Stations
                end
                default: begin
                    dispatch_ready[i] = '0;
                end
            endcase
        end
    end endgenerate

    always_comb begin
        prv_ready = 1'b1;
        for (int i = 0; i < ID_WIDTH; i++) begin
            prv_ready = prv_ready && dispatch_ready[i];
        end
    end

    //////////////////////////
    // Performance Counters //
    //////////////////////////

    logic   [31:0]  perf_int_rs_block;
    logic   [31:0]  perf_intm_rs_block;
    logic   [31:0]  perf_br_rs_block;
    logic   [31:0]  perf_mem_rs_block;

    always_ff @(posedge clk) begin
        if (rst) begin
            perf_int_rs_block <= '0;
            perf_intm_rs_block <= '0;
            perf_br_rs_block <= '0;
            perf_mem_rs_block <= '0;
        end else if (!dispatch_ready[0]) begin
            unique case (uops[0].rs_type)
                RS_INT: begin
                    perf_int_rs_block <= perf_int_rs_block + 1;
                end
                RS_INTM: begin
                    perf_intm_rs_block <= perf_intm_rs_block + 1;
                end
                RS_BR: begin
                    perf_br_rs_block <= perf_br_rs_block + 1;
                end
                RS_MEM: begin
                    perf_mem_rs_block <= perf_mem_rs_block + 1;
                end
                default: begin
                end
            endcase
        end
    end

endmodule
