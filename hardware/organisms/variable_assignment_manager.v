`timescale 1ns / 1ps

module VariableAssignmentManager #(
    parameter NUM_VARS = 256,
    parameter MAX_DECISIONS = 64
) (
    input wire clk,
    input wire reset,
    input wire assign_var,
    input wire [31:0] var_index,
    input wire var_value,
    input wire backtrack_enable,
    input wire [31:0] backtrack_level,
    output reg [NUM_VARS-1:0] var_assignments,
    output reg [NUM_VARS-1:0] var_assigned,
    output reg [31:0] assignment_stack [MAX_DECISIONS-1:0],
    output reg [31:0] stack_pointer
);

    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            var_assignments <= 0;
            var_assigned <= 0;
            stack_pointer <= 0;
            for (i = 0; i < MAX_DECISIONS; i = i + 1) begin
                assignment_stack[i] <= 0;
            end
        end else begin
            if (assign_var && stack_pointer < MAX_DECISIONS) begin
                var_assignments[var_index] <= var_value;
                var_assigned[var_index] <= 1'b1;
                assignment_stack[stack_pointer] <= {var_index, var_value};
                stack_pointer <= stack_pointer + 1;
            end else if (backtrack_enable && stack_pointer > backtrack_level) begin
                stack_pointer <= stack_pointer - 1;
                var_assigned[var_index] <= 1'b0;
            end
        end
    end

endmodule