module one_hot_mux #(
    parameter type T = logic[7:0],
    parameter NUM_INPUTS = 4
) (
    input  T [NUM_INPUTS-1:0] data_in,
    input  logic [NUM_INPUTS-1:0] select,
    output T data_out
);

    always_comb begin
        data_out = T'('0);
        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (select[i]) data_out |= data_in[i];
        end
    end

endmodule
