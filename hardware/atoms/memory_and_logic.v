`timescale 1ns / 1ps

module SynchronousRAM #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 1024
) (
    input  wire clk,
    input  wire we,
    input  wire [ADDR_WIDTH-1:0] addr,
    input  wire [DATA_WIDTH-1:0] data_in,
    output reg  [DATA_WIDTH-1:0] data_out
);

    reg [DATA_WIDTH-1:0] memory [0:DEPTH-1];
    
    initial begin
    end
    
    always @(posedge clk) begin
        if (we)
            memory[addr] <= data_in;
        data_out <= memory[addr];
    end

endmodule

module DualPortRAM #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 1024
) (
    input  wire clk,
    input  wire we_a,
    input  wire [ADDR_WIDTH-1:0] addr_a,
    input  wire [DATA_WIDTH-1:0] data_in_a,
    output reg  [DATA_WIDTH-1:0] data_out_a,
    input  wire [ADDR_WIDTH-1:0] addr_b,
    output reg  [DATA_WIDTH-1:0] data_out_b
);

    reg [DATA_WIDTH-1:0] memory [0:DEPTH-1];
    
    always @(posedge clk) begin
        if (we_a)
            memory[addr_a] <= data_in_a;
        data_out_a <= memory[addr_a];
        
        data_out_b <= memory[addr_b];
    end

endmodule

module PriorityEncoder #(parameter WIDTH = 8) (
    input  wire [WIDTH-1:0] request,
    output reg  [clogb2(WIDTH)-1:0] grant,
    output wire valid
);

    function integer clogb2(input integer n);
        begin
            clogb2 = 0;
            while ((1 << clogb2) < n) clogb2 = clogb2 + 1;
        end
    endfunction
    
    integer i;
    
    assign valid = |request;
    
    always @(*) begin
        grant = 0;
        for (i = WIDTH - 1; i >= 0; i = i - 1) begin
            if (request[i])
                grant = i;
        end
    end

endmodule

module BinaryDecoder #(parameter WIDTH = 3) (
    input  wire [WIDTH-1:0] sel,
    output wire [(2**WIDTH)-1:0] out
);

    genvar i;
    generate
        for (i = 0; i < (2**WIDTH); i = i + 1) begin : decoder
            assign out[i] = (sel == i) ? 1'b1 : 1'b0;
        end
    endgenerate

endmodule

module ShiftRegister #(parameter WIDTH = 8) (
    input  wire clk,
    input  wire reset,
    input  wire [1:0] mode,
    input  wire [WIDTH-1:0] data_in,
    input  wire serial_in,
    output reg  [WIDTH-1:0] data_out,
    output wire serial_out
);

    always @(posedge clk or posedge reset) begin
        if (reset)
            data_out <= {WIDTH{1'b0}};
        else case (mode)
            2'b00: data_out <= data_out;
            2'b01: data_out <= {serial_in, data_out[WIDTH-1:1]};
            2'b10: data_out <= {data_out[WIDTH-2:0], serial_in};
            2'b11: data_out <= data_in;
        endcase
    end
    
    assign serial_out = data_out[WIDTH-1];

endmodule

module RotateRegister #(parameter WIDTH = 32) (
    input  wire [WIDTH-1:0] data_in,
    input  wire [clogb2(WIDTH)-1:0] rotate_amount,
    input  wire direction,
    output wire [WIDTH-1:0] data_out
);

    function integer clogb2(input integer n);
        begin
            clogb2 = 0;
            while ((1 << clogb2) < n) clogb2 = clogb2 + 1;
        end
    endfunction
    
    wire [WIDTH*2-1:0] temp = {data_in, data_in};
    
    generate
        if (direction == 0)
            assign data_out = temp[WIDTH + rotate_amount -1 : rotate_amount];
        else
            assign data_out = temp[WIDTH - 1 - rotate_amount : -rotate_amount];
    endgenerate

endmodule

module PopulationCounter #(parameter WIDTH = 32) (
    input  wire [WIDTH-1:0] data_in,
    output wire [clogb2(WIDTH+1)-1:0] count
);

    function integer clogb2(input integer n);
        begin
            clogb2 = 0;
            while ((1 << clogb2) < n) clogb2 = clogb2 + 1;
        end
    endfunction
    
    integer i;
    reg [clogb2(WIDTH+1)-1:0] pop_count;
    
    always @(*) begin
        pop_count = 0;
        for (i = 0; i < WIDTH; i = i + 1) begin
            pop_count = pop_count + data_in[i];
        end
    end
    
    assign count = pop_count;

endmodule

module LeadingZeroCounter #(parameter WIDTH = 32) (
    input  wire [WIDTH-1:0] data_in,
    output reg  [clogb2(WIDTH+1)-1:0] zeros
);

    function integer clogb2(input integer n);
        begin
            clogb2 = 0;
            while ((1 << clogb2) < n) clogb2 = clogb2 + 1;
        end
    endfunction
    
    integer i;
    
    always @(*) begin
        zeros = WIDTH;
        for (i = WIDTH - 1; i >= 0; i = i - 1) begin
            if (data_in[i] == 1'b1)
                zeros = WIDTH - 1 - i;
        end
    end

endmodule
