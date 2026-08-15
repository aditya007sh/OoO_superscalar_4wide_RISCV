// ============================================================
// ALU + LUI + AUIPC + JAL TESTBENCH
// ============================================================
`timescale 1ns / 1ps

module tb_alu_jump_test;

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
        for (i = 0; i < 26; i = i + 1)
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
        check_reg(1,  32'd10,         "ADDI x1=10");
        check_reg(2,  32'd3,          "ADDI x2=3");
        check_reg(3,  32'hFFFFFFF6,   "ADDI x3=-10");

        $display("  --- R-type ALU ---");
        check_reg(4,  32'd7,          "SUB  x4=10-3=7");
        check_reg(5,  32'd2,          "AND  x5=10&3=2");
        check_reg(6,  32'd11,         "OR   x6=10|3=11");
        check_reg(7,  32'd9,          "XOR  x7=10^3=9");
        check_reg(8,  32'd80,         "SLL  x8=10<<3=80");
        check_reg(9,  32'd1,          "SRL  x9=10>>3=1");
        check_reg(10, 32'hFFFFFFFE,   "SRA  x10=-10>>>3=-2");
        check_reg(11, 32'd1,          "SLT  x11=(-10<10)=1");
        check_reg(12, 32'd1,          "SLTU x12=(10<0xFFFFFFF6)=1");

        $display("  --- I-type ALU ---");
        check_reg(13, 32'd2,          "ANDI x13=10&6=2");
        check_reg(14, 32'd15,         "ORI  x14=10|5=15");
        check_reg(15, 32'd5,          "XORI x15=10^15=5");
        check_reg(16, 32'd160,        "SLLI x16=10<<4=160");
        check_reg(17, 32'd5,          "SRLI x17=10>>1=5");
        check_reg(18, 32'hFFFFFFFD,   "SRAI x18=-10>>>2=-3");
        check_reg(19, 32'd1,          "SLTI x19=(-10<5)=1");
        check_reg(20, 32'd1,          "SLTIU x20=(10<20)=1");

        $display("  --- Upper Immediate ---");
        check_reg(21, 32'h12345000,   "LUI  x21=0x12345000");
        check_reg(22, 32'h00000054,   "AUIPC x22=PC=0x54");

        $display("  --- JAL ---");
        check_reg(23, 32'h0000005C,   "JAL  x23=PC+4=0x5C (link addr)");
        check_reg(24, 32'd0,          "x24=0 (SQUASHED by JAL)");
        check_reg(25, 32'd42,         "ADDI x25=42 (JAL landing)");

        $display("  --- x0 ---");
        check_reg(0,  32'd0,          "x0=0");

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
