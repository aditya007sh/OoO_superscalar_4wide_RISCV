// ============================================================
// BRANCH + JALR TESTBENCH
// ============================================================
`timescale 1ns / 1ps

module tb_branch_jalr_test;

    reg clk, rst;
    always #1 clk = ~clk;  // 2ns clock

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
            $display("  x%-2d = %-12d (0x%08h)  PASS  %0s", rn, actual, actual, label);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  x%-2d = %-12d (0x%08h)  FAIL  (exp %0d/0x%08h)  %0s",
                     rn, actual, actual, expected, expected, label);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    integer i;

    initial begin
        clk = 0; rst = 1;
        pass_cnt = 0; fail_cnt = 0;
        #25 rst = 0;

        repeat (240) @(posedge clk);

        // ARF dump
        $display("############################################################");
        $display("# ALL ARF REGISTER VALUES");
        $display("############################################################");
        for (i = 0; i < 18; i = i + 1)
            $display("  x%-2d = %-12d (0x%08h)  [p%0d]",
                     i, dbg_arf_regfile[i*32 +: 32],
                     dbg_arf_regfile[i*32 +: 32],
                     dbg_arf_rat[i*6 +: 6]);

        // Checks
        $display("");
        $display("############################################################");
        $display("# VERIFICATION");
        $display("############################################################");

        $display("  --- Setup ---");
        check_reg(1,  32'd10,          "ADDI x1=10");
        check_reg(2,  32'd10,          "ADDI x2=10");
        check_reg(3,  32'd5,           "ADDI x3=5");
        check_reg(4,  32'hFFFFFFFD,    "ADDI x4=-3");

        $display("  --- Branches (all taken) ---");
        check_reg(10, 32'd1,           "BEQ  taken: x10=1 (not 99)");
        check_reg(11, 32'd1,           "BNE  taken: x11=1 (not 99)");
        check_reg(12, 32'd1,           "BLT  taken: x12=1 (not 99)");
        check_reg(13, 32'd1,           "BGE  taken: x13=1 (not 99)");
        check_reg(14, 32'd1,           "BLTU taken: x14=1 (not 99)");
        check_reg(15, 32'd1,           "BGEU taken: x15=1 (not 99)");

        $display("  --- JALR ---");
        check_reg(6,  32'h00000064,    "ADDI x6=0x64 (target addr)");
        check_reg(16, 32'h00000060,    "JALR x16=PC+4=0x60 (link)");
        check_reg(17, 32'd42,          "ADDI x17=42 (JALR landing)");

        $display("  --- x0 ---");
        check_reg(0,  32'd0,           "x0=0");

        // Result
        $display("");
        $display("############################################################");
        $display("# RESULT: %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
        $display("############################################################");
        if (fail_cnt == 0)
            $display("# >>> ALL TESTS PASSED <<<");
        else
            $display("# >>> SOME TESTS FAILED <<<");
        $display("############################################################");

        $finish;
    end
endmodule
