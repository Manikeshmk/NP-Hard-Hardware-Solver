`timescale 1ns / 1ps

module BacktrackController #(
    parameter NUM_VARS = 256,
    parameter MAX_DECISIONS = 64
) (
    input wire clk,
    input wire reset,
    input wire trigger_backtrack,
    input wire [31:0] target_decision_level,
    input wire [31:0] current_decision_level,
    output reg [NUM_VARS-1:0] unassigned_vars,
    output reg backtrack_complete,
    output reg [31:0] backtracks_count,
    output reg [31:0] vars_unassigned_count
);

    reg [3:0] backtrack_state;
    reg [31:0] var_index;
    reg [31:0] unassign_counter;

    localparam BACKTRACK_IDLE = 4'b0000;
    localparam BACKTRACK_START = 4'b0001;
    localparam BACKTRACK_UNASSIGN = 4'b0010;
    localparam BACKTRACK_VERIFY = 4'b0011;
    localparam BACKTRACK_DONE = 4'b1111;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            backtrack_state <= BACKTRACK_IDLE;
            unassigned_vars <= 0;
            backtrack_complete <= 0;
            backtracks_count <= 0;
            vars_unassigned_count <= 0;
            var_index <= 0;
            unassign_counter <= 0;
        end else begin
            case (backtrack_state)
                BACKTRACK_IDLE: begin
                    if (trigger_backtrack) begin
                        backtrack_state <= BACKTRACK_START;
                        backtracks_count <= backtracks_count + 1;
                    end
                end

                BACKTRACK_START: begin
                    var_index <= current_decision_level - 1;
                    unassign_counter <= 0;
                    backtrack_state <= BACKTRACK_UNASSIGN;
                end

                BACKTRACK_UNASSIGN: begin
                    if (var_index >= target_decision_level) begin
                        unassigned_vars[var_index] <= 1'b1;
                        vars_unassigned_count <= vars_unassigned_count + 1;
                        unassign_counter <= unassign_counter + 1;
                        if (var_index > 0) begin
                            var_index <= var_index - 1;
                        end else begin
                            backtrack_state <= BACKTRACK_VERIFY;
                        end
                    end else begin
                        backtrack_state <= BACKTRACK_VERIFY;
                    end
                end

                BACKTRACK_VERIFY: begin
                    backtrack_state <= BACKTRACK_DONE;
                end

                BACKTRACK_DONE: begin
                    backtrack_complete <= 1'b1;
                    backtrack_state <= BACKTRACK_IDLE;
                end

                default: backtrack_state <= BACKTRACK_IDLE;
            endcase
        end
    end

endmodule