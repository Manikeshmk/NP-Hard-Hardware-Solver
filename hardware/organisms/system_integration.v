`timescale 1ns / 1ps

module SystemIntegration #(
    parameter NUM_VARS = 256,
    parameter NUM_CLAUSES = 1024,
    parameter MAX_DECISIONS = 64
) (
    input wire clk,
    input wire reset,
    input wire start_solve,
    input wire [NUM_CLAUSES*12-1:0] problem_clauses,
    input wire [NUM_CLAUSES-1:0] clause_valid,
    input wire [2:0] problem_type,
    output wire solution_found,
    output wire unsatisfiable,
    output wire [NUM_VARS-1:0] solution,
    output wire [31:0] total_decisions,
    output wire [31:0] total_conflicts,
    output wire [31:0] total_propagations,
    output wire [31:0] total_backtracks,
    output wire solving_active
);

    wire [NUM_VARS-1:0] var_assignments;
    wire [NUM_VARS-1:0] var_assigned;
    wire [NUM_CLAUSES-1:0] clause_results;
    wire [NUM_CLAUSES-1:0] unit_clauses;
    wire all_satisfied;
    wire conflict_detected;

    wire [NUM_CLAUSES*12-1:0] encoded_clauses;
    wire [NUM_CLAUSES-1:0] encoded_valid;
    wire encoding_done;

    wire propagation_complete;
    wire [31:0] propagation_count;
    wire propagation_conflict;

    wire [NUM_CLAUSES-1:0] learned_clause;
    wire [31:0] new_decision_level;
    wire analysis_complete;
    wire [31:0] conflicts_count;

    wire backtrack_complete;
    wire [31:0] backtracks_count;

    reg [3:0] system_state;
    reg [31:0] decision_level;
    reg [31:0] total_dec, total_conf, total_prop, total_bt;

    localparam SYS_IDLE = 4'b0000;
    localparam SYS_ENCODE = 4'b0001;
    localparam SYS_PROPAGATE = 4'b0010;
    localparam SYS_DECIDE = 4'b0011;
    localparam SYS_EVALUATE = 4'b0100;
    localparam SYS_CONFLICT = 4'b0101;
    localparam SYS_BACKTRACK = 4'b0110;
    localparam SYS_SOLUTION = 4'b0111;

    assign solution = var_assignments;
    assign total_decisions = total_dec;
    assign total_conflicts = total_conf;
    assign total_propagations = total_prop;
    assign total_backtracks = total_bt;
    assign solving_active = (system_state != SYS_IDLE);

    // Instantiate main SAT solver
    SATSolverEngine #(.NUM_VARS(NUM_VARS), .NUM_CLAUSES(NUM_CLAUSES), .MAX_DECISIONS(MAX_DECISIONS)) 
    sat_engine (
        .clk(clk),
        .reset(reset),
        .start_solve(start_solve),
        .clauses_data(problem_clauses),
        .clause_valid(clause_valid),
        .initial_assignments(0),
        .solution_found(solution_found),
        .unsatisfiable(unsatisfiable),
        .solving(solving_active),
        .solution_vars(var_assignments),
        .decisions_made(total_dec),
        .conflicts_detected(total_conf),
        .propagations_done(total_prop),
        .learned_clauses_count()
    );

    // Instantiate problem encoder
    ProblemEncoderModule #(.NUM_VARS(NUM_VARS), .NUM_CLAUSES(NUM_CLAUSES), .PROBLEM_TYPE(3'b100))
    encoder (
        .clk(clk),
        .reset(reset),
        .problem_params(NUM_CLAUSES),
        .start_encode(system_state == SYS_ENCODE),
        .encoding_done(encoding_done),
        .encoded_clauses(encoded_clauses),
        .clause_valid_bits(encoded_valid)
    );

    // Instantiate clause evaluator
    ClauseEvaluator #(.NUM_CLAUSES(NUM_CLAUSES), .NUM_VARS(NUM_VARS))
    evaluator (
        .clk(clk),
        .reset(reset),
        .var_assignments(var_assignments),
        .clauses(problem_clauses),
        .clause_valid(clause_valid),
        .clause_results(clause_results),
        .unit_clauses(unit_clauses),
        .all_satisfied(all_satisfied),
        .conflict_found(conflict_detected),
        .satisfied_count(),
        .unsatisfied_count()
    );

    // Instantiate unit propagation engine
    UnitPropagationEngine #(.NUM_VARS(NUM_VARS), .NUM_CLAUSES(NUM_CLAUSES))
    propagator (
        .clk(clk),
        .reset(reset),
        .start_propagation(system_state == SYS_PROPAGATE),
        .current_assignments(var_assignments),
        .unit_clauses(unit_clauses),
        .clauses(problem_clauses),
        .propagated_assignments(),
        .propagation_complete(propagation_complete),
        .propagations_count(propagation_count),
        .propagation_conflict(propagation_conflict)
    );

    // Instantiate conflict analysis engine
    ConflictAnalysisEngine #(.NUM_VARS(NUM_VARS), .NUM_CLAUSES(NUM_CLAUSES), .MAX_DECISIONS(MAX_DECISIONS))
    conflict_analyzer (
        .clk(clk),
        .reset(reset),
        .start_analysis(system_state == SYS_CONFLICT),
        .var_assignments(var_assignments),
        .current_decision_level(decision_level),
        .clause_results(clause_results),
        .learned_clause(learned_clause),
        .new_decision_level(new_decision_level),
        .analysis_complete(analysis_complete),
        .conflicts_analyzed(conflicts_count)
    );

    // Instantiate backtrack controller
    BacktrackController #(.NUM_VARS(NUM_VARS), .MAX_DECISIONS(MAX_DECISIONS))
    backtracker (
        .clk(clk),
        .reset(reset),
        .trigger_backtrack(system_state == SYS_BACKTRACK),
        .target_decision_level(new_decision_level),
        .current_decision_level(decision_level),
        .unassigned_vars(),
        .backtrack_complete(backtrack_complete),
        .backtracks_count(total_bt),
        .vars_unassigned_count()
    );

    // System state machine
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            system_state <= SYS_IDLE;
            decision_level <= 0;
            total_dec <= 0;
            total_conf <= 0;
            total_prop <= 0;
            total_bt <= 0;
        end else begin
            case (system_state)
                SYS_IDLE: begin
                    if (start_solve) begin
                        system_state <= SYS_ENCODE;
                    end
                end

                SYS_ENCODE: begin
                    if (encoding_done) begin
                        system_state <= SYS_PROPAGATE;
                    end
                end

                SYS_PROPAGATE: begin
                    if (propagation_complete) begin
                        if (all_satisfied) begin
                            system_state <= SYS_SOLUTION;
                        end else if (conflict_detected) begin
                            system_state <= SYS_CONFLICT;
                        end else begin
                            system_state <= SYS_DECIDE;
                        end
                    end
                end

                SYS_DECIDE: begin
                    decision_level <= decision_level + 1;
                    system_state <= SYS_PROPAGATE;
                end

                SYS_EVALUATE: begin
                    if (conflict_detected) begin
                        system_state <= SYS_CONFLICT;
                    end else if (all_satisfied) begin
                        system_state <= SYS_SOLUTION;
                    end else begin
                        system_state <= SYS_DECIDE;
                    end
                end

                SYS_CONFLICT: begin
                    if (analysis_complete) begin
                        if (decision_level == 0) begin
                            system_state <= SYS_IDLE;
                        end else begin
                            system_state <= SYS_BACKTRACK;
                        end
                    end
                end

                SYS_BACKTRACK: begin
                    if (backtrack_complete) begin
                        decision_level <= new_decision_level;
                        system_state <= SYS_PROPAGATE;
                    end
                end

                SYS_SOLUTION: begin
                    system_state <= SYS_IDLE;
                end

                default: system_state <= SYS_IDLE;
            endcase
        end
    end

endmodule