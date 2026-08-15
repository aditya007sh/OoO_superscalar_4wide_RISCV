// ============================================================
// RAW / WAW / WAR HAZARD TESTBENCH
// ALU-only, self-checking, with PRF allocation display
// ============================================================
`timescale 1ns / 1ps

module tb_hazard_test;

    reg clk, rst;
    always #5 clk = ~clk;

    // ---- DUT output wires ----
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

    // ---- DUT ----
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

    // ================================================================
    // PER-CYCLE TRACE
    // ================================================================
    task print_cycle;
        input integer cycle;
    begin
        $display("========================================");
        $display("CYCLE %0d  (t=%0t)", cycle, $time);
        $display("========================================");
        $display("  PC=0x%08h  ROB: h=%0d t=%0d cnt=%0d",
            dbg_pc_current, dbg_rob_head, dbg_rob_tail, dbg_rob_count);

        // CDB writeback: shows PRF tag + result
        if (cdb_fu0_valid) $display("  CDB0: rob=%0d  rd_prf=p%-2d  result=%-5d (0x%08h)", cdb_fu0_rob_idx, cdb_fu0_phys_reg, cdb_fu0_result, cdb_fu0_result);
        if (cdb_fu1_valid) $display("  CDB1: rob=%0d  rd_prf=p%-2d  result=%-5d (0x%08h)", cdb_fu1_rob_idx, cdb_fu1_phys_reg, cdb_fu1_result, cdb_fu1_result);
        if (cdb_fu2_valid) $display("  CDB2: rob=%0d  rd_prf=p%-2d  result=%-5d (0x%08h)", cdb_fu2_rob_idx, cdb_fu2_phys_reg, cdb_fu2_result, cdb_fu2_result);
        if (cdb_fu3_valid) $display("  CDB3: rob=%0d  rd_prf=p%-2d  result=%-5d (0x%08h)", cdb_fu3_rob_idx, cdb_fu3_phys_reg, cdb_fu3_result, cdb_fu3_result);
        if (cdb_bpu_valid) $display("  BPU:  rob=%0d mispred=%b corr_pc=0x%08h", cdb_bpu_rob_idx, cdb_bpu_mispredict, cdb_bpu_correct_pc);

        if (!cdb_fu0_valid && !cdb_fu1_valid && !cdb_fu2_valid && !cdb_fu3_valid && !cdb_bpu_valid)
            $display("  (idle)");
        $display("");
    end
    endtask

    // ================================================================
    // CHECK HELPERS
    // ================================================================
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
            $display("  x%-2d = %-12d (0x%08h)  FAIL  (expected %0d / 0x%08h)  %0s",
                     rn, actual, actual, expected, expected, label);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    // ================================================================
    // MAIN
    // ================================================================
    integer i, cyc;

    initial begin
        clk = 0; rst = 1; cyc = 1;
        pass_cnt = 0; fail_cnt = 0;

        // Instructions loaded from instruction_memory.v

        #25 rst = 0;

        // ---- Per-cycle trace for 40 cycles ----
        repeat (40) begin
            @(posedge clk); #1;
            print_cycle(cyc);
            cyc = cyc + 1;
        end

        // ============================================================
        // PRF ALLOCATION (Committed RRAT)
        // ============================================================
        $display("############################################################");
        $display("# PRF ALLOCATION  (Committed RRAT: arch_reg -> phys_reg)");
        $display("############################################################");
        $write("  ");
        for (i = 0; i < 32; i = i + 1) begin
            $write("x%-2d->p%-2d  ", i, dbg_arf_rat[i*6 +: 6]);
            if (i % 8 == 7) begin
                $display("");
                if (i < 31) $write("  ");
            end
        end

        // ============================================================
        // SPECULATIVE RAT
        // ============================================================
        $display("");
        $display("############################################################");
        $display("# SPECULATIVE RAT  (current rename map)");
        $display("############################################################");
        $write("  ");
        for (i = 0; i < 32; i = i + 1) begin
            $write("x%-2d->p%-2d  ", i, dbg_rat[i*6 +: 6]);
            if (i % 8 == 7) begin
                $display("");
                if (i < 31) $write("  ");
            end
        end

        // ============================================================
        // ALL 32 ARF REGISTER VALUES
        // ============================================================
        $display("");
        $display("############################################################");
        $display("# ALL ARF REGISTER VALUES  (x0 - x31)");
        $display("############################################################");
        for (i = 0; i < 32; i = i + 1)
            $display("  x%-2d = %-12d (0x%08h)  [RRAT: p%0d]",
                     i, dbg_arf_regfile[i*32 +: 32],
                     dbg_arf_regfile[i*32 +: 32],
                     dbg_arf_rat[i*6 +: 6]);

        // ============================================================
        // SELF-CHECK VERIFICATION
        // ============================================================
        $display("");
        $display("############################################################");
        $display("# VERIFICATION CHECKS");
        $display("############################################################");

        $display("  --- RAW Chain (words 0-3) ---");
        check_reg(1,  32'd10,  "ADDI x1, x0, 10");
        check_reg(2,  32'd15,  "ADDI x2, x1, 5          (RAW x1: 10+5=15)");
        check_reg(3,  32'd25,  "ADD  x3, x1, x2         (RAW x1,x2: 10+15=25)");
        check_reg(4,  32'd40,  "ADD  x4, x2, x3         (RAW x2,x3: 15+25=40)");

        $display("  --- WAW Triple Write to x5 (words 4-7) ---");
        check_reg(5,  32'd30,  "ADDI x5 WAW: 10->20->30 (final=30)");
        check_reg(6,  32'd30,  "ADD  x6, x5, x0         (RAW after WAW: x5=30)");

        $display("  --- WAR: read x7 then overwrite (words 8-11) ---");
        check_reg(7,  32'd200, "ADDI x7=200              (WAR: overwrites after x8 read old)");
        check_reg(8,  32'd110, "ADD  x8, x7_old, x1     (WAR: reads x7=100, 100+10=110)");
        check_reg(9,  32'd200, "ADD  x9, x7_new, x0     (reads x7=200)");

        $display("  --- Combined RAW+WAW (words 12-15) ---");
        check_reg(10, 32'd2,   "ADDI x10 WAW: 1->2      (final=2)");
        check_reg(11, 32'd4,   "ADD  x11, x10, x10      (RAW after WAW: 2+2=4)");
        check_reg(12, 32'd6,   "ADD  x12, x11, x10      (RAW chain: 4+2=6)");

        $display("  --- Deep RAW Chain / Fibonacci (words 16-19) ---");
        check_reg(13, 32'd1,   "ADDI x13=1");
        check_reg(14, 32'd2,   "ADD  x14, x13, x13      (1+1=2)");
        check_reg(15, 32'd3,   "ADD  x15, x14, x13      (2+1=3)");
        check_reg(16, 32'd5,   "ADD  x16, x15, x14      (3+2=5)");

        $display("  --- x0 Hardwire ---");
        check_reg(0,  32'd0,   "x0 must always be 0");

        // ============================================================
        // RESULT
        // ============================================================
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