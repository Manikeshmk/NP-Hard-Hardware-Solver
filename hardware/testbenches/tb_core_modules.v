`timescale 1ns / 1ps

module tb_sat_solver_core;

    parameter NUM_VARS = 8;
    parameter NUM_CLAUSES = 4;
    parameter MAX_DECISIONS = 8;
    
    reg clk;
    reg reset;
    reg start_solve;
    
    SATSolverCore #(
        .NUM_VARS(NUM_VARS),
        .NUM_CLAUSES(NUM_CLAUSES),
        .MAX_DECISIONS(MAX_DECISIONS)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start_solve(start_solve),
        .clauses_config(0),
        .clause_valid(0),
        .solution_found(),
        .unsatisfiable(),
        .solving(),
        .solution_vars(),
        .decisions_made(),
        .conflicts_detected(),
        .propagations_done()
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        reset = 1;
        start_solve = 0;
        #20 reset = 0;
        
        #10 start_solve = 1;
        #10 start_solve = 0;
        
        #1000;
        
        if (dut.solution_found)
            $display("TEST 1 PASSED: Solution found");
        else if (dut.unsatisfiable)
            $display("TEST 1 INFO: Problem unsatisfiable");
        else
            $display("TEST 1 FAILED: No result");
        
        $stop;
    end
    
    always @(posedge clk) begin
        if (dut.solving)
            $display("Time: %t | State: %b | Decisions: %d | Conflicts: %d",
                     $time, dut.state, dut.decisions_made, dut.conflicts_detected);
    end

endmodule

module tb_constraint_evaluator;

    parameter WIDTH = 8;
    
    reg [WIDTH-1:0] var_state;
    reg [2:0] lit1_idx, lit2_idx, lit3_idx;
    reg lit1_pol, lit2_pol, lit3_pol;
    wire result;
    
    ConstraintEvaluator #(.WIDTH(WIDTH)) dut (
        .var_state(var_state),
        .lit1_idx(lit1_idx),
        .lit2_idx(lit2_idx),
        .lit3_idx(lit3_idx),
        .lit1_polarity(lit1_pol),
        .lit2_polarity(lit2_pol),
        .lit3_polarity(lit3_pol),
        .clause_satisfied(result)
    );
    
    initial begin
        var_state = 8'b00000001;
        lit1_idx = 3'd0;
        lit2_idx = 3'd1;
        lit3_idx = 3'd2;
        lit1_pol = 1'b0;
        lit2_pol = 1'b0;
        lit3_pol = 1'b0;
        
        #10;
        if (result == 1'b1)
            $display("TEST 1 PASSED: Clause correctly satisfied");
        else
            $display("TEST 1 FAILED: Expected 1, got %b", result);
        
        var_state = 8'b00000001;
        lit1_pol = 1'b1;
        lit2_pol = 1'b1;
        lit3_pol = 1'b0;
        
        #10;
        if (result == 1'b1)
            $display("TEST 2 PASSED: Clause correctly satisfied");
        else
            $display("TEST 2 FAILED: Expected 1, got %b", result);
        
        $stop;
    end

endmodule

module tb_parallel_constraint_checker;

    parameter NUM_CLAUSES = 4;
    parameter VAR_WIDTH = 8;
    
    reg [VAR_WIDTH-1:0] variables;
    reg [NUM_CLAUSES-1:0] enables;
    reg [9*NUM_CLAUSES-1:0] config;
    wire [NUM_CLAUSES-1:0] results;
    wire all_sat;
    
    ParallelConstraintChecker #(
        .NUM_CLAUSES(NUM_CLAUSES),
        .VAR_WIDTH(VAR_WIDTH)
    ) dut (
        .variables(variables),
        .clause_enables(enables),
        .clause_config(config),
        .clause_results(results),
        .all_satisfied(all_sat)
    );
    
    initial begin
        variables = 8'b00001111;
        enables = 4'b1111;
        
        config = {
            9'b000_001_000,
            9'b001_010_000,
            9'b110_101_100,
            9'b010_001_000
        };
        
        #10;
        $display("Results: %b | All Satisfied: %b", results, all_sat);
        
        if (all_sat == 1'b1)
            $display("TEST PASSED: All clauses satisfied");
        else
            $display("TEST FAILED: Expected all satisfied");
        
        $stop;
    end

endmodule

module tb_alu;

    parameter WIDTH = 32;
    
    reg [WIDTH-1:0] A, B;
    reg [3:0] opcode;
    wire [WIDTH-1:0] result;
    wire zero_flag, carry_flag, overflow_flag;
    
    ArithmeticLogicUnit #(.WIDTH(WIDTH)) dut (
        .A(A),
        .B(B),
        .opcode(opcode),
        .result(result),
        .zero_flag(zero_flag),
        .carry_flag(carry_flag),
        .overflow_flag(overflow_flag)
    );
    
    initial begin
        A = 32'h00000005;
        B = 32'h00000003;
        opcode = 4'b0000;
        #10;
        if (result == 32'h00000008)
            $display("TEST ADD PASSED");
        else
            $display("TEST ADD FAILED: Expected 0x00000008, got 0x%08x", result);
        
        A = 32'hFFFF0000;
        B = 32'h0000FFFF;
        opcode = 4'b0010;
        #10;
        if (result == 32'h00000000)
            $display("TEST AND PASSED");
        else
            $display("TEST AND FAILED: Expected 0x00000000, got 0x%08x", result);
        
        opcode = 4'b0011;
        #10;
        if (result == 32'hFFFFFFFF)
            $display("TEST OR PASSED");
        else
            $display("TEST OR FAILED: Expected 0xFFFFFFFF, got 0x%08x", result);
        
        $stop;
    end

endmodule
