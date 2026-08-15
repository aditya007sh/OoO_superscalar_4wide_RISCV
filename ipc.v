// ============================================================
// IPC MEASUREMENT - stops when HALT reached (no wasted cycles)
// Updated for 4-wide commit
// ============================================================
`timescale 1ns / 1ps

module tb_ipc;

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

    // 4-wide commit: read commit_valid[3:0] from ROB
    wire [3:0] cv = dut.u_issue.u_rob.commit_valid;
    wire [2:0] commits_this_cycle = {2'b0, cv[0]} + {2'b0, cv[1]}
                                  + {2'b0, cv[2]} + {2'b0, cv[3]};
    wire [6:0] rob_cnt = dut.u_issue.u_rob.count;

    integer cycles, commits, first_cycle, last_cycle;
    integer idle_cnt;

    initial begin
        clk = 0; rst = 1;
        cycles = 0; commits = 0;
        first_cycle = 0; last_cycle = 0;
        idle_cnt = 0;
        #25 rst = 0;

        forever begin
            @(posedge clk);
            cycles = cycles + 1;

            if (|cv) begin
                commits = commits + commits_this_cycle;
                if (first_cycle == 0) first_cycle = cycles;
                last_cycle = cycles;
                idle_cnt = 0;
            end else begin
                idle_cnt = idle_cnt + 1;
            end

            // Stop: ROB drained after enough commits, or 15 idle cycles
            if (commits >= 30 || rob_cnt == 0) begin
                // Wait 2 more cycles for final commits to register
                repeat(2) @(posedge clk);
                if (|cv) begin commits = commits + commits_this_cycle; last_cycle = cycles + 2; end

                $display("");
                $display("############################################################");
                $display("#  IPC MEASUREMENT (4-wide commit)");
                $display("############################################################");
                $display("#  Instructions committed : %0d", commits);
                $display("#  Total cycles (reset)   : %0d", cycles);
                $display("#  First commit cycle     : %0d", first_cycle);
                $display("#  Last  commit cycle     : %0d", last_cycle);
                $display("#  Active cycles          : %0d", last_cycle - first_cycle + 1);
                $display("#");
                $display("#  CPI (total)            : %0d.%02d",
                         cycles / commits,
                         (cycles * 100 / commits) % 100);
                $display("#  IPC (total)            : %0d.%02d",
                         commits / cycles,
                         (commits * 100 / cycles) % 100);
                $display("#  IPC (steady-state)     : %0d.%02d",
                         commits / (last_cycle - first_cycle + 1),
                         (commits * 100 / (last_cycle - first_cycle + 1)) % 100);
                $display("############################################################");
                $finish;
            end

            if (cycles > 2000) begin
                $display("TIMEOUT at %0d commits, rob_cnt=%0d", commits, rob_cnt);
                $finish;
            end
        end
    end
endmodule
