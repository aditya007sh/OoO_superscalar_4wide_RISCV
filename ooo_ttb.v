// ============================================================
// COMPREHENSIVE STRESS TEST TESTBENCH
// Tests ALL RV32I instruction types + memory verification
// ============================================================
`timescale 1ns / 1ps

module tb_stress_test;

    reg clk, rst;
    always #1 clk = ~clk;

    wire        cdb_fu0_valid, cdb_fu1_valid, cdb_fu2_valid, cdb_fu3_valid;
    wire [5:0]  cdb_fu0_rob_idx, cdb_fu1_rob_idx, cdb_fu2_rob_idx, cdb_fu3_rob_idx;
    wire [5:0]  cdb_fu0_phys_reg, cdb_fu1_phys_reg, cdb_fu2_phys_reg, cdb_fu3_phys_reg;
    wire [31:0] cdb_fu0_result, cdb_fu1_result, cdb_fu2_result, cdb_fu3_result;
    wire        cdb_bpu_valid, cdb_bpu_mispredict;
    wire [5:0]  cdb_bpu_rob_idx, cdb_bpu_phys_reg;
    wire [31:0] cdb_bpu_result, cdb_bpu_correct_pc;
    wire        agu_wb_valid, agu_wb_data_valid;
    wire [4:0]  agu_wb_lsq_idx;
    wire [31:0] agu_wb_addr, agu_wb_store_data;
    wire [31:0]   dbg_pc_current;
    wire [63:0]   dbg_freelist_bitmap;
    wire [191:0]  dbg_rat;
    wire [5:0]    dbg_rob_head, dbg_rob_tail;
    wire [6:0]    dbg_rob_count;
    wire [4:0]    dbg_lsq_head, dbg_lsq_tail;
    wire [5:0]    dbg_lsq_count;
    wire [1023:0] dbg_arf_regfile;
    wire [191:0]  dbg_arf_rat;
    wire [4:0]    dbg_rd_addr0, dbg_rd_addr1;
    wire [31:0]   dbg_rd_data0, dbg_rd_data1;
    wire [191:0]  dbg_arch_to_phys_flush;

    fetch_decode_issue_execute_top #(
        .ROB_DEPTH(64), .ROB_PTR_W(6),
        .LSQ_DEPTH(32), .LSQ_PTR_W(5),
        .AQ_DEPTH(16),  .AQ_PTR_W(4),
        .MEM_DEPTH(256), .INIT_FILE("")
    ) dut (
        .clk(clk), .rst(rst),
        .cdb_fu0_valid(cdb_fu0_valid), .cdb_fu0_rob_idx(cdb_fu0_rob_idx),
        .cdb_fu0_phys_reg(cdb_fu0_phys_reg), .cdb_fu0_result(cdb_fu0_result),
        .cdb_fu1_valid(cdb_fu1_valid), .cdb_fu1_rob_idx(cdb_fu1_rob_idx),
        .cdb_fu1_phys_reg(cdb_fu1_phys_reg), .cdb_fu1_result(cdb_fu1_result),
        .cdb_fu2_valid(cdb_fu2_valid), .cdb_fu2_rob_idx(cdb_fu2_rob_idx),
        .cdb_fu2_phys_reg(cdb_fu2_phys_reg), .cdb_fu2_result(cdb_fu2_result),
        .cdb_fu3_valid(cdb_fu3_valid), .cdb_fu3_rob_idx(cdb_fu3_rob_idx),
        .cdb_fu3_phys_reg(cdb_fu3_phys_reg), .cdb_fu3_result(cdb_fu3_result),
        .cdb_bpu_valid(cdb_bpu_valid), .cdb_bpu_rob_idx(cdb_bpu_rob_idx),
        .cdb_bpu_phys_reg(cdb_bpu_phys_reg), .cdb_bpu_result(cdb_bpu_result),
        .cdb_bpu_mispredict(cdb_bpu_mispredict), .cdb_bpu_correct_pc(cdb_bpu_correct_pc),
        .agu_wb_valid(agu_wb_valid), .agu_wb_lsq_idx(agu_wb_lsq_idx),
        .agu_wb_addr(agu_wb_addr), .agu_wb_store_data(agu_wb_store_data),
        .agu_wb_data_valid(agu_wb_data_valid),
        .dbg_pc_current(dbg_pc_current), .dbg_freelist_bitmap(dbg_freelist_bitmap),
        .dbg_rat(dbg_rat),
        .dbg_rob_head(dbg_rob_head), .dbg_rob_tail(dbg_rob_tail), .dbg_rob_count(dbg_rob_count),
        .dbg_lsq_head(dbg_lsq_head), .dbg_lsq_tail(dbg_lsq_tail), .dbg_lsq_count(dbg_lsq_count),
        .dbg_arf_regfile(dbg_arf_regfile), .dbg_arf_rat(dbg_arf_rat),
        .dbg_rd_addr0(dbg_rd_addr0), .dbg_rd_data0(dbg_rd_data0),
        .dbg_rd_addr1(dbg_rd_addr1), .dbg_rd_data1(dbg_rd_data1),
        .dbg_arch_to_phys_flush(dbg_arch_to_phys_flush)
    );

    integer pass_cnt, fail_cnt;

    task check_reg;
        input [4:0]  rn;
        input [31:0] expected;
        input [255:0] label;
        reg [31:0] actual;
    begin
        actual = dbg_arf_regfile[rn*32 +: 32];
        if (actual === expected) begin
            $display("  PASS  x%-2d = 0x%08h  %0s", rn, actual, label);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  x%-2d = 0x%08h (exp 0x%08h)  %0s", rn, actual, expected, label);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    task check_mem;
        input [31:0] addr;
        input [31:0] expected;
        input [255:0] label;
        reg [31:0] actual;
    begin
        actual = dut.u_issue.u_mem.mem[addr];
        if (actual === expected) begin
            $display("  PASS  mem[%0d] = 0x%08h  %0s", addr, actual, label);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  mem[%0d] = 0x%08h (exp 0x%08h)  %0s", addr, actual, expected, label);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    initial begin
        clk = 0; rst = 1;
        pass_cnt = 0; fail_cnt = 0;
        #25 rst = 0;

        // Debug: watch first 100 cycles
        repeat (100) begin
            @(posedge clk);
            if (|dut.u_issue.u_rob.commit_valid)
                $display("T=%0t  COMMIT cv=%b head=%0d tail=%0d count=%0d ccomb=%0d",
                    $time,
                    dut.u_issue.u_rob.commit_valid,
                    dut.u_issue.u_rob.head,
                    dut.u_issue.u_rob.tail,
                    dut.u_issue.u_rob.count,
                    dut.u_issue.u_rob.commit_count_comb);
        end

        // Run remaining cycles
        repeat (200) @(posedge clk);

        $display("");
        $display("############################################################");
        $display("#  COMPREHENSIVE STRESS TEST - RV32I OOO SUPERSCALAR");
        $display("############################################################");

        $display("");
        $display("  [x0 hardwired]");
        check_reg( 0, 32'h00000000, "x0 = 0");

        $display("");
        $display("  [Setup: ADDI from x0]");
        check_reg( 1, 32'h0000000A, "ADDI x1, x0, 10");
        check_reg( 2, 32'h00000003, "ADDI x2, x0, 3");
        check_reg( 3, 32'hFFFFFFFB, "ADDI x3, x0, -5");

        $display("");
        $display("  [R-type ALU]");
        check_reg( 4, 32'h0000000D, "ADD  x4 = x1+x2 = 13");
        check_reg( 5, 32'h00000007, "SUB  x5 = x1-x2 = 7");
        check_reg( 6, 32'h00000002, "AND  x6 = x1&x2 = 2");
        check_reg( 7, 32'h0000000B, "OR   x7 = x1|x2 = 11");
        check_reg( 8, 32'h00000009, "XOR  x8 = x1^x2 = 9");
        check_reg( 9, 32'h00000050, "SLL  x9 = x1<<x2 = 80");
        check_reg(10, 32'h00000001, "SRL  x10= x1>>x2 = 1");
        check_reg(11, 32'hFFFFFFFF, "SRA  x11= x3>>>x2 = -1");
        check_reg(12, 32'h00000001, "SLT  x12= (x3<x1) = 1");
        check_reg(13, 32'h00000001, "SLTU x13= (x1<x3 unsigned) = 1");

        $display("");
        $display("  [I-type ALU]");
        check_reg(14, 32'h00000002, "ANDI x14= x1&6 = 2");
        check_reg(15, 32'h0000000F, "ORI  x15= x1|5 = 15");
        check_reg(16, 32'h00000005, "XORI x16= x1^15 = 5");
        check_reg(17, 32'h000000A0, "SLLI x17= x1<<4 = 160");
        check_reg(18, 32'h00000005, "SRLI x18= x1>>1 = 5");
        check_reg(19, 32'hFFFFFFFE, "SRAI x19= x3>>>2 = -2");

        $display("");
        $display("  [Upper Immediate]");
        check_reg(20, 32'h12345000, "LUI  x20= 0x12345000");

        $display("");
        $display("  [Load/Store]");
        check_reg(21, 32'h0000000A, "LW   x21= mem[0] = 10");
        check_reg(22, 32'h0000000D, "LW   x22= mem[1] = 13");

        $display("");
        $display("  [Branch: BEQ taken]");
        check_reg(23, 32'h00000001, "BEQ  taken: x23=1 (not 99)");

        $display("");
        $display("  [Jump: JAL]");
        check_reg(24, 32'h00000070, "JAL  x24= PC+4 = 0x70 (link)");
        check_reg(25, 32'h0000002A, "ADDI x25= 42 (JAL landing)");

        $display("");
        $display("  [Memory Contents]");
        check_mem(0, 32'h0000000A, "SW x1=10 to mem[0]");
        check_mem(1, 32'h0000000D, "SW x4=13 to mem[1]");

        $display("");
        $display("  [Unused registers = 0]");
        check_reg(26, 32'h00000000, "x26 unused");
        check_reg(27, 32'h00000000, "x27 unused");
        check_reg(28, 32'h00000000, "x28 unused");
        check_reg(29, 32'h00000000, "x29 unused");
        check_reg(30, 32'h00000000, "x30 unused");
        check_reg(31, 32'h00000000, "x31 unused");

        $display("");
        $display("############################################################");
        $display("#  RESULT: %0d PASS, %0d FAIL (out of %0d tests)",
                 pass_cnt, fail_cnt, pass_cnt + fail_cnt);
        $display("############################################################");
        if (fail_cnt == 0)
            $display("#  >>> ALL %0d TESTS PASSED <<<", pass_cnt);
        else
            $display("#  >>> %0d TESTS FAILED <<<", fail_cnt);
        $display("############################################################");

        $finish;
    end
    // Add to tb_stress_test after reset
integer commit4_cnt, commit3_cnt, commit2_cnt, commit1_cnt;
initial begin commit4_cnt=0; commit3_cnt=0; commit2_cnt=0; commit1_cnt=0; end

always @(posedge clk) begin
    case(dut.u_issue.u_rob.commit_valid)
        4'b1111: commit4_cnt = commit4_cnt + 1;
        4'b0111: commit3_cnt = commit3_cnt + 1;
        4'b0011: commit2_cnt = commit2_cnt + 1;
        4'b0001: commit1_cnt = commit1_cnt + 1;
    endcase
end

endmodule
