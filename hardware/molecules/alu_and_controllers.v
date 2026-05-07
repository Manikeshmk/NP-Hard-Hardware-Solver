`timescale 1ns / 1ps

module ArithmeticLogicUnit #(parameter WIDTH = 32) (
    input  wire [WIDTH-1:0] A,
    input  wire [WIDTH-1:0] B,
    input  wire [3:0] opcode,
    output reg  [WIDTH-1:0] result,
    output wire zero_flag,
    output wire carry_flag,
    output wire overflow_flag
);

    wire [WIDTH:0] add_result, sub_result;
    wire [WIDTH-1:0] and_result, or_result, xor_result;
    
    assign add_result = A + B;
    assign sub_result = A - B;
    
    assign and_result = A & B;
    assign or_result  = A | B;
    assign xor_result = A ^ B;
    
    always @(*) begin
        case (opcode)
            4'b0000: result = add_result[WIDTH-1:0];
            4'b0001: result = sub_result[WIDTH-1:0];
            4'b0010: result = and_result;
            4'b0011: result = or_result;
            4'b0100: result = xor_result;
            4'b0101: result = A << B[4:0];
            4'b0110: result = A >> B[4:0];
            4'b0111: result = (A < B) ? 1 : 0;
            4'b1000: result = ~A;
            4'b1001: result = A + 1;
            4'b1010: result = A - 1;
            default: result = {WIDTH{1'b0}};
        endcase
    end
    
    assign zero_flag     = (result == {WIDTH{1'b0}});
    assign carry_flag    = add_result[WIDTH];
    assign overflow_flag = (A[WIDTH-1] == B[WIDTH-1]) & (result[WIDTH-1] != A[WIDTH-1]);

endmodule

module ConstraintEvaluator #(parameter WIDTH = 8) (
    input  wire [WIDTH-1:0] var_state,
    input  wire [2:0] lit1_idx,
    input  wire [2:0] lit2_idx,
    input  wire [2:0] lit3_idx,
    input  wire lit1_polarity,
    input  wire lit2_polarity,
    input  wire lit3_polarity,
    output wire clause_satisfied
);

    wire lit1_val, lit2_val, lit3_val;
    
    assign lit1_val = var_state[lit1_idx] ^ lit1_polarity;
    assign lit2_val = var_state[lit2_idx] ^ lit2_polarity;
    assign lit3_val = var_state[lit3_idx] ^ lit3_polarity;
    
    assign clause_satisfied = lit1_val | lit2_val | lit3_val;

endmodule

module ParallelConstraintChecker #(
    parameter NUM_CLAUSES = 16,
    parameter VAR_WIDTH = 64
) (
    input  wire [VAR_WIDTH-1:0] variables,
    input  wire [NUM_CLAUSES-1:0] clause_enables,
    input  wire [9*NUM_CLAUSES-1:0] clause_config,
    output wire [NUM_CLAUSES-1:0] clause_results,
    output wire all_satisfied
);

    genvar i;
    generate
        for (i = 0; i < NUM_CLAUSES; i = i + 1) begin : clause_check
            wire [8:0] config = clause_config[9*i +: 9];
            
            ConstraintEvaluator #(.WIDTH(VAR_WIDTH)) eval (
                .var_state(variables),
                .lit1_idx(config[2:0]),
                .lit2_idx(config[5:3]),
                .lit3_idx(config[8:6]),
                .lit1_polarity(1'b0),
                .lit2_polarity(1'b0),
                .lit3_polarity(1'b0),
                .clause_satisfied(clause_results[i])
            );
        end
    endgenerate
    
    assign all_satisfied = &clause_results;

endmodule

module BusInterface #(
    parameter NUM_MASTERS = 8,
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32
) (
    input  wire clk,
    input  wire reset,
    input  wire [NUM_MASTERS-1:0] req,
    output wire [NUM_MASTERS-1:0] grant,
    input  wire [NUM_MASTERS*ADDR_WIDTH-1:0] addr,
    input  wire [NUM_MASTERS*DATA_WIDTH-1:0] data_in,
    input  wire [NUM_MASTERS-1:0] we,
    output wire [ADDR_WIDTH-1:0] slave_addr,
    output wire [DATA_WIDTH-1:0] slave_data,
    output wire slave_we,
    input  wire [DATA_WIDTH-1:0] slave_data_out,
    output wire [NUM_MASTERS-1:0] data_valid
);

    wire [clogb2(NUM_MASTERS)-1:0] grant_encoded;
    wire grant_valid;
    
    PriorityEncoder #(.WIDTH(NUM_MASTERS)) arbiter (
        .request(req),
        .grant(grant_encoded),
        .valid(grant_valid)
    );
    
    genvar i;
    generate
        for (i = 0; i < NUM_MASTERS; i = i + 1) begin : grant_gen
            assign grant[i] = (grant_encoded == i) ? grant_valid : 1'b0;
        end
    endgenerate
    
    assign slave_addr = addr[grant_encoded*ADDR_WIDTH +: ADDR_WIDTH];
    assign slave_data = data_in[grant_encoded*DATA_WIDTH +: DATA_WIDTH];
    assign slave_we   = we[grant_encoded];
    
    generate
        for (i = 0; i < NUM_MASTERS; i = i + 1) begin : data_return
            assign data_valid[i] = grant[i];
        end
    endgenerate

    function integer clogb2(input integer n);
        begin
            clogb2 = 0;
            while ((1 << clogb2) < n) clogb2 = clogb2 + 1;
        end
    endfunction

endmodule

module StateController (
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  wire all_clauses_satisfied,
    input  wire conflict_detected,
    input  wire backtrack_possible,
    output reg  [2:0] state,
    output wire load_enable,
    output wire propagate_enable,
    output wire decide_enable,
    output wire backtrack_enable,
    output wire verify_enable,
    output wire done
);

    parameter IDLE      = 3'b000;
    parameter LOAD      = 3'b001;
    parameter PROPAGATE = 3'b010;
    parameter DECIDE    = 3'b011;
    parameter BACKTRACK = 3'b100;
    parameter VERIFY    = 3'b101;
    parameter DONE      = 3'b110;
    
    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else case (state)
            IDLE:
                if (start)
                    state <= LOAD;
            
            LOAD:
                state <= PROPAGATE;
            
            PROPAGATE:
                if (conflict_detected)
                    state <= BACKTRACK;
                else if (all_clauses_satisfied)
                    state <= VERIFY;
                else
                    state <= DECIDE;
            
            DECIDE:
                state <= PROPAGATE;
            
            BACKTRACK:
                if (backtrack_possible)
                    state <= PROPAGATE;
                else
                    state <= DONE;
            
            VERIFY:
                state <= DONE;
            
            DONE:
                if (start)
                    state <= LOAD;
                else
                    state <= IDLE;
            
            default:
                state <= IDLE;
        endcase
    end
    
    assign load_enable      = (state == LOAD);
    assign propagate_enable = (state == PROPAGATE);
    assign decide_enable    = (state == DECIDE);
    assign backtrack_enable = (state == BACKTRACK);
    assign verify_enable    = (state == VERIFY);
    assign done             = (state == DONE);

endmodule
