`timescale 1ns/1ps
module tb_regfiles;
    localparam LANES = 8;
    localparam W = 16;
    localparam NREGS = 8;
    localparam VW = LANES*W;

    reg clk;
    reg [2:0] va, vb, vwa, sa, sb, swa, da;
    reg ven, sen;
    reg [VW-1:0] vwd;
    reg [31:0] swd;
    wire [VW-1:0] vrd_a, vrd_b;
    wire [31:0] srd_a, srd_b, drd;
    reg [VW-1:0] vshadow [0:NREGS-1];
    reg [31:0] sshadow [0:7];
    integer errors, checks, seed, i, r, index;
    reg [VW-1:0] rv;
    reg [31:0] rs;

    vec_regfile #(.LANES(LANES), .W(W), .NREGS(NREGS)) vf (
        .clk(clk), .read_addr_a(va), .read_data_a(vrd_a),
        .read_addr_b(vb), .read_data_b(vrd_b), .write_en(ven),
        .write_addr(vwa), .write_data(vwd));
    scalar_regfile sf (
        .clk(clk), .read_addr_a(sa), .read_data_a(srd_a),
        .read_addr_b(sb), .read_data_b(srd_b), .write_en(sen),
        .write_addr(swa), .write_data(swd), .debug_addr(da), .debug_data(drd));

    task error;
        input [8*40-1:0] message;
        begin
            errors = errors + 1;
            if (errors <= 20) $display("ERROR: %0s", message);
        end
    endtask

    task check_v_all;
        integer n;
        begin
            for (n = 0; n < NREGS; n = n + 1) begin
                va = n; vb = NREGS-1-n; #1;
                checks = checks + 2;
                if (vrd_a !== vshadow[n]) error("vector port A mismatch");
                if (vrd_b !== vshadow[NREGS-1-n]) error("vector port B mismatch");
            end
        end
    endtask

    task check_s_all;
        integer n;
        begin
            for (n = 0; n < 8; n = n + 1) begin
                sa = n; sb = 7-n; da = n; #1;
                checks = checks + 3;
                if (srd_a !== ((n == 0) ? 32'b0 : sshadow[n])) error("scalar port A mismatch");
                if (srd_b !== ((n == 7) ? 32'b0 : sshadow[7-n])) error("scalar port B mismatch");
                if (drd !== ((n == 0) ? 32'b0 : sshadow[n])) error("scalar debug mismatch");
            end
        end
    endtask

    task vcycle;
        input [2:0] address;
        input enable;
        input [VW-1:0] data;
        begin
            vwa = address; ven = enable; vwd = data; va = address; vb = address; #1;
            checks = checks + 2;
            if (vrd_a !== vshadow[address] || vrd_b !== vshadow[address])
                error("vector read-during-write old value mismatch");
            clk = 1'b1;
            if (enable) vshadow[address] = data;
            #1; checks = checks + 2;
            if (vrd_a !== vshadow[address] || vrd_b !== vshadow[address])
                error("vector post-edge value mismatch");
            clk = 1'b0; #1;
        end
    endtask

    task scycle;
        input [2:0] address;
        input enable;
        input [31:0] data;
        reg [31:0] expected;
        begin
            swa = address; sen = enable; swd = data;
            sa = address; sb = address; da = address;
            expected = (address == 0) ? 32'b0 : sshadow[address];
            #1; checks = checks + 3;
            if (srd_a !== expected || srd_b !== expected || drd !== expected)
                error("scalar read-during-write old value mismatch");
            clk = 1'b1;
            if (enable && (address != 0)) sshadow[address] = data;
            expected = (address == 0) ? 32'b0 : sshadow[address];
            #1; checks = checks + 3;
            if (srd_a !== expected || srd_b !== expected || drd !== expected)
                error("scalar post-edge or s0 mismatch");
            clk = 1'b0; #1;
        end
    endtask

    initial begin
        clk = 0; va = 0; vb = 0; vwa = 0; ven = 0; vwd = 0;
        sa = 0; sb = 0; swa = 0; sen = 0; swd = 0; da = 0;
        errors = 0; checks = 0; seed = 32'h51D2026;
        for (i = 0; i < NREGS; i = i + 1) vshadow[i] = 0;
        for (i = 0; i < 8; i = i + 1) sshadow[i] = 0;
        #1;
        check_v_all; check_s_all;

        // Visit every register; disabled writes must leave shadow and DUT intact.
        for (i = 0; i < 8; i = i + 1) begin
            vcycle(i, 1'b1, {4{32'h10203040 ^ i}});
            vcycle(i, 1'b0, {4{32'hDEADBEEF}});
            scycle(i, 1'b1, 32'hA5000000 | i);
            scycle(i, 1'b0, 32'hDEADBEEF);
        end
        check_v_all; check_s_all;

        // 2,000 randomized cycles per file, checking old/new edge behavior and
        // sweeping every register over both read ports at regular intervals.
        for (r = 0; r < 2000; r = r + 1) begin
            index = $random(seed); index = index & 7;
            rv = {$random(seed), $random(seed), $random(seed), $random(seed)};
            vcycle(index[2:0], (r % 5 != 0), rv);
            va = $random(seed); vb = $random(seed); #1; checks = checks + 2;
            if (vrd_a !== vshadow[va] || vrd_b !== vshadow[vb]) error("random vector read mismatch");
            if (r % 8 == 7) check_v_all;
        end
        for (r = 0; r < 2000; r = r + 1) begin
            index = $random(seed); index = index & 7;
            rs = {$random(seed), $random(seed)};
            scycle(index[2:0], (r % 5 != 0), rs);
            sa = $random(seed); sb = $random(seed); da = $random(seed); #1; checks = checks + 3;
            if (srd_a !== ((sa == 0) ? 32'b0 : sshadow[sa]) ||
                srd_b !== ((sb == 0) ? 32'b0 : sshadow[sb]) ||
                drd !== ((da == 0) ? 32'b0 : sshadow[da])) error("random scalar read mismatch");
            if (r % 8 == 7) check_s_all;
        end
        check_v_all; check_s_all;
        $display("tb_regfiles: %0d checks, %0d errors", checks, errors);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED");
        $finish;
    end
endmodule
