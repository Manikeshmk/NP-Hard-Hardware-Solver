`timescale 1ns / 1ps

module DecisionEngine #(
    parameter NUM_VARS = 256,
    parameter MAX_DECISIONS = 64
) (
    input wire clk,
    input wire reset,
    input wire [NUM_VARS-1:0] var_assigned,
    input wire [NUM_VARS-1:0] var_assignments,
    input wire start_decision,
    output reg [31:0] selected_var,
    output reg selected_polarity,
    output reg decision_valid,
    output reg [31:0] decisions_count
);

    reg [NUM_VARS-1:0] unassigned_vars;
    reg [31:0] decision_state;
    integer i, j;
    reg [31:0] var_occurrence_count [NUM_VARS-1:0];

    localparam DEC_IDLE = 4'b0000;
    localparam DEC_SCAN = 4'b0001;
    localparam DEC_SELECT = 4'b0010;
    localparam DEC_DONE = 4'b1111;

    always @(*) begin
        for (i = 0; i < NUM_VARS; i = i + 1) begin
            unassigned_vars[i] = ~var_assigned[i];
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            decision_state <= DEC_IDLE;
            selected_var <= 0;
            selected_polarity <= 0;
            decision_valid <= 0;
            decisions_count <= 0;

            for (i = 0; i < NUM_VARS; i = i + 1) begin
                var_occurrence_count[i] <= 0;
            end
        end else begin
            case (decision_state)
                DEC_IDLE: begin
                    if (start_decision) begin
                        decision_state <= DEC_SCAN;
                    end
                end

                DEC_SCAN: begin
                    for (i = 0; i < NUM_VARS; i = i + 1) begin
                        if (unassigned_vars[i]) begin
                            var_occurrence_count[i] <= var_occurrence_count[i] + 1;
                        end
                    end
                    decision_state <= DEC_SELECT;
                end

                DEC_SELECT: begin
                    // Use Maximum Occurrence in unsatisfied clauses (MOUC) heuristic
                    for (j = 1; j < NUM_VARS; j = j + 1) begin
                        if (var_occurrence_count[j] > var_occurrence_count[selected_var]) begin
                            selected_var <= j;
                        end
                    end
                    selected_polarity <= 1'b0; // Default polarity
                    decision_valid <= 1'b1;
                    decisions_count <= decisions_count + 1;
                    decision_state <= DEC_DONE;
                end

                DEC_DONE: begin
                    decision_state <= DEC_IDLE;
                end

                default: decision_state <= DEC_IDLE;
            endcase
        end
    end

endmodule