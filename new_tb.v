`timescale 1ns / 1ps

module tb_mul_test;

    reg clk, rst;
    always #1 clk = ~clk;

    wire        cdb_fu0_valid, cdb_fu1_valid, cdb_fu2_valid, cdb_fu3_valid;
    wire [5:0]  cdb_fu0_rob_idx, cdb_fu1_rob_idx, cdb_fu2_rob_idx, cdb_fu3_rob_idx;
    wire [5:0]  cdb_fu0_phys_reg, cdb_fu1_phys_reg, cdb_fu2_phys_reg, cdb_fu3_phys_reg;
    wire [31:0] cdb_fu0_result, cdb_fu1_result, cdb_fu2_result, cdb_fu3_result;
    wire        cdb_bpu_valid, cdb_bpu_mispredict;
    wire [5:0]  cdb_bpu_rob_idx, cdb_bpu_phys_reg;
    wire [31:0] cdb_bpu_result, cdb_bpu_correct_pc;
    
    wire        cdb_mul_valid;
    wire [5:0]  cdb_mul_rob_idx, cdb_mul_phys_reg;
    wire [31:0] cdb_mul_result;
    
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
        .cdb_mul_valid(cdb_mul_valid), .cdb_mul_rob_idx(cdb_mul_rob_idx),
        .cdb_mul_phys_reg(cdb_mul_phys_reg), .cdb_mul_result(cdb_mul_result),
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

    initial begin
        clk = 0; rst = 1;
        pass_cnt = 0; fail_cnt = 0;
        #25 rst = 0;

        // Debug: watch first 50 cycles
        repeat (50) begin
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

        // Wait a few more cycles to let MUL finish
        repeat (50) @(posedge clk);

        $display("");
        $display("############################################################");
        $display("#  MULTIPLIER & ALU MIXED TEST");
        $display("############################################################");

        $display("");
        check_reg( 0, 32'h00000000, "x0");
        check_reg( 1, 32'h00000005, "ADDI x1, x0, 5");
        check_reg( 2, 32'h00000007, "ADDI x2, x0, 7");
        check_reg( 3, 32'h00000023, "MUL  x3, x1, x2 (5*7=35)");
        check_reg( 4, 32'h00000028, "ADD  x4, x3, x1 (35+5=40)");
        check_reg( 5, 32'h00000000, "MULH x5, x1, x2 (high(5*7)=0)");
        check_reg( 6, 32'hFFFFFFFE, "ADDI x6, x0, -2");
        check_reg( 7, 32'hFFFFFFF6, "MUL  x7, x6, x1 (-2*5=-10)");
        check_reg( 8, 32'hFFFFFFFF, "MULH x8, x6, x1 (high(-10)=-1)");

        $display("");
        $display("# RESULT: %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
        if (fail_cnt == 0) 
            $display(">>> ALL TESTS PASSED <<<");
        else               
            $display(">>> SOME TESTS FAILED <<<");
            
        $finish;
    end
    
    // Print CDB MUL activity to trace when completions arrive
    always @(posedge clk) begin
        if (!rst) begin
            if (cdb_mul_valid) $display("T=%0t [MULTI] CDB Write: rob=%0d preg=%0d RES=0x%08h", $time, cdb_mul_rob_idx, cdb_mul_phys_reg, cdb_mul_result);
            if (cdb_fu0_valid) $display("T=%0t [ALU0 ] CDB Write: rob=%0d preg=%0d RES=0x%08h", $time, cdb_fu0_rob_idx, cdb_fu0_phys_reg, cdb_fu0_result);
        end
    end

endmodule
