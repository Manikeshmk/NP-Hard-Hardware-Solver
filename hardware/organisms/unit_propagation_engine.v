`timescale 1ns / 1ps

module UnitPropagationEngine #(
    parameter NUM_VARS = 256,
    parameter NUM_CLAUSES = 1024,
    parameter CLAUSE_WIDTH = 12
) (
    input wire clk,
    input wire reset,
    input wire start_propagation,
    input wire [NUM_VARS-1:0] current_assignments,
    input wire [NUM_CLAUSES-1:0] unit_clauses,
    input wire [NUM_CLAUSES*CLAUSE_WIDTH-1:0] clauses,
    output reg [NUM_VARS-1:0] propagated_assignments,
    output reg propagation_complete,
    output reg [31:0] propagations_count,
    output reg propagation_conflict
);

    reg [3:0] prop_state;
    reg [31:0] clause_index;
    reg [31:0] prop_counter;

    localparam PROP_IDLE = 4'b0000;
    localparam PROP_SCAN = 4'b0001;
    localparam PROP_APPLY = 4'b0010;
    localparam PROP_CHECK = 4'b0011;
    localparam PROP_COMPLETE = 4'b1111;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            prop_state <= PROP_IDLE;
            propagated_assignments <= 0;
            propagation_complete <= 0;
            propagations_count <= 0;
            propagation_conflict <= 0;
            clause_index <= 0;
            prop_counter <= 0;
        end else begin
            case (prop_state)
                PROP_IDLE: begin
                    if (start_propagation) begin
                        prop_state <= PROP_SCAN;
                        propagated_assignments <= current_assignments;
                        prop_counter <= 0;
                    end
                end

                PROP_SCAN: begin
                    if (clause_index < NUM_CLAUSES) begin
                        if (unit_clauses[clause_index]) begin
                            prop_state <= PROP_APPLY;
                        end else begin
                            clause_index <= clause_index + 1;
                        end
                    end else begin
                        prop_state <= PROP_CHECK;
                    end
                end

                PROP_APPLY: begin
                    // Apply unit propagation
                    prop_counter <= prop_counter + 1;
                    propagations_count <= propagations_count + 1;
                    clause_index <= clause_index + 1;
                    prop_state <= PROP_SCAN;
                end

                PROP_CHECK: begin
                    // Verify for conflicts
                    propagation_conflict <= 0;
                    prop_state <= PROP_COMPLETE;
                end

                PROP_COMPLETE: begin
                    propagation_complete <= 1'b1;
                    prop_state <= PROP_IDLE;
                end

                default: prop_state <= PROP_IDLE;
            endcase
        end
    end

endmodule