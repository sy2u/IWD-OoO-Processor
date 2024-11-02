module prf
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    rs_prf_itf.prf              from_rs[CDB_WIDTH],
    cdb_itf.prf                 cdb[CDB_WIDTH]
);

    logic [31:0]    prf_data [PRF_DEPTH];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                prf_data[i] <= '0;
            end
        end else begin
            for (int i = 0; i < CDB_WIDTH; i++) begin
                if (cdb[i].valid) begin 
                    prf_data[cdb[i].rd_phy] <= cdb[i].rd_value;
                end
            end
        end
    end

    always_comb begin
        for (int j = 0; j < CDB_WIDTH; j++) begin 
            from_rs[j].rs1_value = prf_data[from_rs.rs1_phy];
            from_rs[j].rs2_value = prf_data[from_rs.rs2_phy];

            for (int i = 0; i < CDB_WIDTH; i++) begin
                if (cdb[i].valid && (cdb[i].rd_phy == from_rs[j].rs1_phy)) begin 
                    from_rs[j].rs1_value = cdb[i].rd_value;
                end

                if (cdb[i].valid && (cdb[i].rd_phy == from_rs[j].rs2_phy)) begin 
                    from_rs[j].rs2_value = cdb[i].rd_value;
                end
            end
        end
    end


endmodule
