`timescale 1ns / 1ps

module SystemTestbench ();

    parameter NUM_VARS = 256;
    parameter NUM_CLAUSES = 1024;
    parameter MAX_DECISIONS = 64;

    reg clk;
    reg reset;
    reg start_solve;
    reg [NUM_CLAUSES*12-1:0] problem_clauses;
    reg [NUM_CLAUSES-1:0] clause_valid;
    reg [2:0] problem_type;

    wire solution_found;
    wire unsatisfiable;
    wire [NUM_VARS-1:0] solution;
    wire [31:0] total_decisions;
    wire [31:0] total_conflicts;
    wire [31:0] total_propagations;
    wire [31:0] total_backtracks;
    wire solving_active;

    SystemIntegration #(
        .NUM_VARS(NUM_VARS),
        .NUM_CLAUSES(NUM_CLAUSES),
        .MAX_DECISIONS(MAX_DECISIONS)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start_solve(start_solve),
        .problem_clauses(problem_clauses),
        .clause_valid(clause_valid),
        .problem_type(problem_type),
        .solution_found(solution_found),
        .unsatisfiable(unsatisfiable),
        .solution(solution),
        .total_decisions(total_decisions),
        .total_conflicts(total_conflicts),
        .total_propagations(total_propagations),
        .total_backtracks(total_backtracks),
        .solving_active(solving_active)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test stimulus
    initial begin
        reset = 1;
        start_solve = 0;
        problem_clauses = 0;
        clause_valid = 0;
        problem_type = 3'b100; // 3-SAT

        #20 reset = 0;
        #10 start_solve = 1;

        // Initialize some clauses
        clause_valid = {NUM_CLAUSES{1'b1}};

        #100 start_solve = 0;

        // Wait for solver to complete
        wait(~solving_active);

        $display("========== SAT Solver Results ==========");
        $display("Solution Found: %d", solution_found);
        $display("Unsatisfiable: %d", unsatisfiable);
        $display("Total Decisions: %d", total_decisions);
        $display("Total Conflicts: %d", total_conflicts);
        $display("Total Propagations: %d", total_propagations);
        $display("Total Backtracks: %d", total_backtracks);
        $display("Solution: %h", solution);
        $display("=========================================");

        #100 $finish;
    end

    // Monitor signals
    always @(posedge clk) begin
        if (solving_active) begin
            $display("Time: %t | Solving | Decisions: %d | Conflicts: %d | Propagations: %d",
                $time, total_decisions, total_conflicts, total_propagations);
        end
    end

endmodule