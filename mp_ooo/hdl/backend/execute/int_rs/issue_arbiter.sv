module issue_arbiter
import cpu_params::*;
(
    input   logic   [INTRS_DEPTH-1:0]           rs_request,
    output  logic   [INTRS_DEPTH-1:0]           rs_grant,
    output  logic                               fu_issue_en     [INT_ISSUE_WIDTH],
    output  logic   [INTRS_IDX-1:0]             fu_issue_idx    [INT_ISSUE_WIDTH]
);

    logic   [INT_ISSUE_IDX:0]   next_issue_idx;

    always_comb begin
        // init
        rs_grant = '0;
        next_issue_idx = '0;
        for ( int i = 0; i < INT_ISSUE_WIDTH; i++ ) begin
            fu_issue_en[i] = '0;
            fu_issue_idx[i] = 'x;
        end
        // issue
        for (int i = 0; i < INTRS_DEPTH; i++) begin
            if (rs_request[i]) begin
                rs_grant[i] = 1'b1;
                fu_issue_en[next_issue_idx] = '1;
                fu_issue_idx[next_issue_idx] = (INTRS_IDX)'(unsigned'(i));
                next_issue_idx = (INT_ISSUE_IDX+1)'(next_issue_idx + 1);
                if ( (INT_ISSUE_IDX+1)'(next_issue_idx) >= (INT_ISSUE_IDX+1)'(INT_ISSUE_WIDTH) ) break;
            end
        end
    end

endmodule