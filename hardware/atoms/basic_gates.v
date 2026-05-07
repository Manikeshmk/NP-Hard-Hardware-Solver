`timescale 1ns / 1ps

module SR_Latch (
    input  wire set,
    input  wire reset,
    output wire Q,
    output wire Q_n
);
    wire q_temp, q_n_temp;
    
    assign q_n_temp = ~(set | q_temp);
    assign q_temp   = ~(reset | q_n_temp);
    
    assign Q   = q_temp;
    assign Q_n = q_n_temp;
endmodule

module D_FlipFlop (
    input  wire clk,
    input  wire reset,
    input  wire D,
    output reg  Q,
    output wire Q_n
);
    assign Q_n = ~Q;

    always @(posedge clk or posedge reset) begin
        if (reset)
            Q <= 1'b0;
        else
            Q <= D;
    end
endmodule

module Mux2to1 (
    input  wire in0,
    input  wire in1,
    input  wire sel,
    output wire out
);
    assign out = sel ? in1 : in0;
endmodule

module Mux4to1 (
    input  wire in0, in1, in2, in3,
    input  wire [1:0] sel,
    output wire out
);
    assign out = (sel == 2'b00) ? in0 :
                 (sel == 2'b01) ? in1 :
                 (sel == 2'b10) ? in2 :
                 in3;
endmodule

module Comparator_1bit (
    input  wire A,
    input  wire B,
    output wire LT,
    output wire EQ,
    output wire GT
);
    assign LT = (~A) & B;
    assign EQ = ~(A ^ B);
    assign GT = A & (~B);
endmodule

module Comparator_Nbit #(parameter WIDTH = 8) (
    input  wire [WIDTH-1:0] A,
    input  wire [WIDTH-1:0] B,
    input  wire lt_in,
    input  wire eq_in,
    input  wire gt_in,
    output wire LT,
    output wire EQ,
    output wire GT
);

    wire [WIDTH-1:0] a_lt_b, a_eq_b, a_gt_b;
    
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : bit_compare
            Comparator_1bit comp (
                .A(A[i]),
                .B(B[i]),
                .LT(a_lt_b[i]),
                .EQ(a_eq_b[i]),
                .GT(a_gt_b[i])
            );
        end
    endgenerate
    
    assign LT = (eq_in & a_lt_b[WIDTH-1]) | lt_in;
    assign EQ = eq_in & a_eq_b[WIDTH-1];
    assign GT = (eq_in & a_gt_b[WIDTH-1]) | gt_in;

endmodule

module FullAdder_1bit (
    input  wire A,
    input  wire B,
    input  wire Cin,
    output wire Sum,
    output wire Cout
);
    assign Sum  = A ^ B ^ Cin;
    assign Cout = (A & B) | (Cin & (A ^ B));
endmodule

module RippleCarryAdder #(parameter WIDTH = 8) (
    input  wire [WIDTH-1:0] A,
    input  wire [WIDTH-1:0] B,
    input  wire Cin,
    output wire [WIDTH-1:0] Sum,
    output wire Cout
);
    wire [WIDTH:0] carry;
    assign carry[0] = Cin;
    
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : add_bit
            FullAdder_1bit fa (
                .A(A[i]),
                .B(B[i]),
                .Cin(carry[i]),
                .Sum(Sum[i]),
                .Cout(carry[i+1])
            );
        end
    endgenerate
    
    assign Cout = carry[WIDTH];
endmodule

module BinaryCounter #(parameter WIDTH = 8) (
    input  wire clk,
    input  wire reset,
    input  wire enable,
    output reg  [WIDTH-1:0] count
);
    always @(posedge clk or posedge reset) begin
        if (reset)
            count <= {WIDTH{1'b0}};
        else if (enable)
            count <= count + 1;
    end
endmodule

module Parity_Checker #(parameter WIDTH = 8) (
    input  wire [WIDTH-1:0] data,
    output wire even_parity,
    output wire odd_parity
);

    wire [WIDTH-1:0] xor_chain;
    assign xor_chain[0] = data[0];
    
    genvar i;
    generate
        for (i = 1; i < WIDTH; i = i + 1) begin : parity_gen
            assign xor_chain[i] = xor_chain[i-1] ^ data[i];
        end
    endgenerate
    
    assign even_parity = ~xor_chain[WIDTH-1];
    assign odd_parity  = xor_chain[WIDTH-1];

endmodule
