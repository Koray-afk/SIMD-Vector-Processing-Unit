// Eight 32-bit scalar registers. s0 is hard-wired to zero; the debug
// read port is combinational and independent of the two processor ports.
module scalar_regfile (
    input wire clk,
    input wire [2:0] read_addr_a,
    output wire [31:0] read_data_a,
    input wire [2:0] read_addr_b,
    output wire [31:0] read_data_b,
    input wire write_en,
    input wire [2:0] write_addr,
    input wire [31:0] write_data,
    input wire [2:0] debug_addr,
    output wire [31:0] debug_data
);
    reg [31:0] regs [0:7];
    integer i;

    initial begin
        for (i = 0; i < 8; i = i + 1)
            regs[i] = 32'b0;
    end

    assign read_data_a = (read_addr_a == 3'd0) ? 32'b0 : regs[read_addr_a];
    assign read_data_b = (read_addr_b == 3'd0) ? 32'b0 : regs[read_addr_b];
    assign debug_data = (debug_addr == 3'd0) ? 32'b0 : regs[debug_addr];

    always @(posedge clk)
        if (write_en && (write_addr != 3'd0))
            regs[write_addr] <= write_data;
endmodule
