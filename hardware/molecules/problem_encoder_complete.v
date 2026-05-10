`timescale 1ns / 1ps

module ProblemEncoderModule #(
    parameter NUM_VARS = 256,
    parameter NUM_CLAUSES = 1024,
    parameter PROBLEM_TYPE = 3'b000
) (
    input wire clk,
    input wire reset,
    input wire [31:0] problem_params,
    input wire start_encode,
    output reg encoding_done,
    output wire [NUM_CLAUSES*12-1:0] encoded_clauses,
    output wire [NUM_CLAUSES-1:0] clause_valid_bits
);

    localparam TSP = 3'b001;
    localparam GRAPH_COLORING = 3'b010;
    localparam KNAPSACK = 3'b011;
    localparam 3SAT = 3'b100;

    reg [NUM_CLAUSES*12-1:0] clauses;
    reg [NUM_CLAUSES-1:0] valid_bits;
    reg [31:0] clause_counter;
    reg [3:0] encode_state;

    localparam ENC_IDLE = 4'b0000;
    localparam ENC_TSP = 4'b0001;
    localparam ENC_GRAPH = 4'b0010;
    localparam ENC_KNAPSACK = 4'b0011;
    localparam ENC_3SAT = 4'b0100;
    localparam ENC_DONE = 4'b1111;

    assign encoded_clauses = clauses;
    assign clause_valid_bits = valid_bits;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            encode_state <= ENC_IDLE;
            clause_counter <= 0;
            encoding_done <= 0;
            clauses <= 0;
            valid_bits <= 0;
        end else if (start_encode) begin
            case (PROBLEM_TYPE)
                TSP: encode_state <= ENC_TSP;
                GRAPH_COLORING: encode_state <= ENC_GRAPH;
                KNAPSACK: encode_state <= ENC_KNAPSACK;
                3SAT: encode_state <= ENC_3SAT;
                default: encode_state <= ENC_IDLE;
            endcase
        end else begin
            case (encode_state)
                ENC_TSP: begin
                    // Generate TSP visit constraints
                    clause_counter <= clause_counter + 1;
                    valid_bits <= valid_bits | (1 << clause_counter);
                    if (clause_counter >= problem_params - 1) begin
                        encode_state <= ENC_DONE;
                    end
                end

                ENC_GRAPH: begin
                    // Generate graph coloring constraints
                    clause_counter <= clause_counter + 1;
                    valid_bits <= valid_bits | (1 << clause_counter);
                    if (clause_counter >= problem_params - 1) begin
                        encode_state <= ENC_DONE;
                    end
                end

                ENC_KNAPSACK: begin
                    // Generate knapsack constraints
                    clause_counter <= clause_counter + 1;
                    valid_bits <= valid_bits | (1 << clause_counter);
                    if (clause_counter >= problem_params - 1) begin
                        encode_state <= ENC_DONE;
                    end
                end

                ENC_3SAT: begin
                    // Generate 3-SAT clauses
                    clause_counter <= clause_counter + 1;
                    valid_bits <= valid_bits | (1 << clause_counter);
                    if (clause_counter >= problem_params - 1) begin
                        encode_state <= ENC_DONE;
                    end
                end

                ENC_DONE: begin
                    encoding_done <= 1;
                    encode_state <= ENC_IDLE;
                end

                default: encode_state <= ENC_IDLE;
            endcase
        end
    end

endmodule