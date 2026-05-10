`timescale 1ns / 1ps

module BitOperations;

    function integer popcount;
        input integer n;
        integer count;
        begin
            count = 0;
            while (n != 0) begin
                count = count + (n & 1);
                n = n >> 1;
            end
            popcount = count;
        end
    endfunction

    function integer leading_zeros;
        input integer n;
        input integer width;
        integer lz, i;
        begin
            if (n == 0) begin
                leading_zeros = width;
            end else begin
                lz = 0;
                for (i = width - 1; i >= 0; i = i - 1) begin
                    if ((n & (1 << i)) != 0) begin
                        lz = width - 1 - i;
                        break;
                    end
                end
                leading_zeros = lz;
            end
        end
    endfunction

    function integer hamming_distance;
        input integer x, y;
        begin
            hamming_distance = popcount(x ^ y);
        end
    endfunction

    function integer bit_reverse;
        input integer n;
        input integer width;
        integer result, i;
        begin
            result = 0;
            for (i = 0; i < width; i = i + 1) begin
                result = (result << 1) | (n & 1);
                n = n >> 1;
            end
            bit_reverse = result;
        end
    endfunction

endmodule