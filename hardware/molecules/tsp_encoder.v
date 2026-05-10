`timescale 1ns / 1ps

module TSPEncoder #(parameter N = 4) (
    input wire [N*N-1:0] distance_matrix,
    input wire [31:0] max_cost,
    output reg [N*N-1:0] visit_constraints,
    output reg [31:0] cost_constraints
);
    integer i, j;

    always @(*) begin
        // Encode visit constraints
        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                visit_constraints[i*N + j] = (i != j) ? 1'b1 : 1'b0;
            end
        end

        // Encode cost constraints (simplified example)
        cost_constraints = max_cost;
    end

endmodule