// Two asynchronous read ports and one rising-edge write port.
// Lane 0 occupies the least significant W bits. ADDR_W is explicit because
// Verilog-2005 does not define $clog2.
module vec_regfile #(
    parameter LANES = 8,
    parameter W = 16,
    parameter NREGS = 8,
    parameter ADDR_W = 3
) (
    input wire clk,
    input wire [ADDR_W-1:0] read_addr_a,
    output wire [LANES*W-1:0] read_data_a,
    input wire [ADDR_W-1:0] read_addr_b,
    output wire [LANES*W-1:0] read_data_b,
    input wire write_en,
    input wire [ADDR_W-1:0] write_addr,
    input wire [LANES*W-1:0] write_data
);
    reg [LANES*W-1:0] regs [0:NREGS-1];
    localparam [ADDR_W:0] REG_COUNT = NREGS;
    integer i;

    initial begin
        for (i = 0; i < NREGS; i = i + 1)
            regs[i] = {LANES*W{1'b0}};
    end

    assign read_data_a = regs[read_addr_a];
    assign read_data_b = regs[read_addr_b];

    always @(posedge clk)
        if (write_en && ({1'b0, write_addr} < REG_COUNT))
            regs[write_addr] <= write_data;
endmodule
