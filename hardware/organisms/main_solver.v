`timescale 1ns / 1ps

module MainSolver #(parameter NUM_VARS = 256, NUM_CLAUSES = 1024) (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [NUM_CLAUSES*12-1:0] clauses,
    input wire [NUM_CLAUSES-1:0] clause_valid,
    output reg solution_found,
    output reg unsatisfiable,
    output reg [NUM_VARS-1:0] solution
);

    wire [31:0] decisions;
    wire [31:0] conflicts;
    wire [31:0] elapsed_time;

    BenchmarkRunner #(
        .NUM_VARS(NUM_VARS),
        .NUM_CLAUSES(NUM_CLAUSES)
    ) benchmark (
        .clk(clk),
        .reset(reset),
        .start(start),
        .clauses(clauses),
        .clause_valid(clause_valid),
        .solution_found(solution_found),
        .unsatisfiable(unsatisfiable),
        .solution(solution),
        .decisions(decisions),
        .conflicts(conflicts),
        .elapsed_time(elapsed_time)
    );

endmodule