module issue_arbiter
import cpu_params::*;
(
    input   logic   [INTRS_DEPTH-1:0]           rs_request,
    output  logic   [INTRS_DEPTH-1:0]           rs_grant,
    output  logic   [INT_ISSUE_WIDTH-1:0]       rs_compress     [INTRS_DEPTH],
    output  logic   [INTRS_DEPTH-1:0]           fu_issue        [INT_ISSUE_WIDTH]
);

    // try structral style
    // still behavior code, but more intuitive

    logic   [INT_ISSUE_WIDTH-1:0]   prev_assigned [INTRS_DEPTH];

    always_comb begin
        rs_grant = '0;
        fu_issue[0] = '0;
        fu_issue[1] = '0;
        for (int i = 0; i < INTRS_DEPTH; i++) begin 
            prev_assigned[i][0] = '0;
            prev_assigned[i][1] = '0;
            for ( int j = 0; j < i; j++ ) begin
                if(rs_request[j])                          prev_assigned[i][0] = '1;
                if(rs_request[j] & prev_assigned[j][0])    prev_assigned[i][1] = '1;
            end
            if( ~prev_assigned[i][0] & rs_request[i] ) begin
                rs_grant[i] = '1;
                fu_issue[0][i] = '1;
            end else if ( ~prev_assigned[i][1] & rs_request[i] ) begin
                rs_grant[i] = '1;
                fu_issue[1][i] = '1;
            end
        end
    end

    always_comb begin
        // hardcoded for simplicity
        for ( int i = 0; i < INTRS_DEPTH; i++ ) begin
            unique case (prev_assigned[i])
                2'b00:      rs_compress[i] = (rs_grant[i]) ? 2'b01: 2'b00;
                2'b01:      rs_compress[i] = (rs_grant[i]) ? 2'b10: 2'b01;
                2'b11:      rs_compress[i] = 2'b10;
                default:    rs_compress[i] = 'x;
            endcase
        end       
        // for consecutive pop corner case
        for ( int i = 0; i < INTRS_DEPTH-1; i++ ) begin
            if( rs_compress[i]!=2'b00 && rs_grant[i+1] )   rs_compress[i] = 2'b10;
        end   
    end

endmodule
